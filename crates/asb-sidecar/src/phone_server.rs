use std::collections::HashMap;
use std::sync::{Arc, Mutex};

use asb_protocol::emacs::EmacsOut;
use asb_protocol::model::{SessionId, SessionState, Seq};
use asb_protocol::net::{recv_frame, send_frame, ASB_ALPN};
use asb_protocol::roster::Roster;
use asb_protocol::wire::WireMsg;
use iroh::endpoint::Connection;
use iroh::Endpoint;
use tokio::sync::{broadcast, mpsc};
use tokio::task::JoinHandle;

use crate::presence::Presence;
use crate::push::PushSender;
use crate::registry::Registry;

/// Accept rostered phones on the steady-state ALPN and serve each one.
pub fn spawn_phone_server(
    ep: Endpoint,
    reg: Arc<Registry>,
    roster: Arc<Mutex<Roster>>,
    out_tx: mpsc::Sender<EmacsOut>,
    presence: Presence,
) -> JoinHandle<()> {
    tokio::spawn(async move {
        loop {
            let incoming = match ep.accept().await {
                Some(i) => i,
                None => break,
            };
            let conn = match incoming.accept() {
                Ok(c) => match c.await {
                    Ok(c) => c,
                    Err(_) => continue,
                },
                Err(_) => continue,
            };
            if conn.alpn() != ASB_ALPN {
                conn.close(0u32.into(), b"not asb");
                continue;
            }
            let remote = *conn.remote_id().as_bytes();
            if !roster.lock().unwrap().contains(&remote) {
                conn.close(0u32.into(), b"not rostered");
                continue;
            }
            let reg = reg.clone();
            let out_tx = out_tx.clone();
            let presence = presence.clone();
            tokio::spawn(async move {
                let _guard = presence.enter();
                if let Err(e) = handle_phone_conn(conn, reg, out_tx).await {
                    tracing::warn!("phone conn ended: {e:#}");
                }
            });
        }
    })
}

async fn send_wire(send: &mut iroh::endpoint::SendStream, m: &WireMsg) -> anyhow::Result<()> {
    let mut buf = Vec::new();
    ciborium::into_writer(m, &mut buf)?;
    send_frame(send, &buf).await
}

async fn handle_phone_conn(
    conn: Connection,
    reg: Arc<Registry>,
    out_tx: mpsc::Sender<EmacsOut>,
) -> anyhow::Result<()> {
    let (mut send, mut recv) = conn.accept_bi().await?;
    // Subscribe before reading hello so nothing that lands during replay is lost.
    let mut rx = reg.subscribe();

    let hello: HashMap<SessionId, Seq> = match ciborium::from_reader(&recv_frame(&mut recv).await?[..])?
    {
        WireMsg::Hello { last_seq, .. } => last_seq,
        _ => anyhow::bail!("expected hello"),
    };

    send_wire(
        &mut send,
        &WireMsg::SessionList {
            sessions: reg.session_list(),
        },
    )
    .await?;

    // Replay each session's backlog, tracking a per-session high-water seq so the
    // live stream below never re-sends an update already replayed.
    let mut hw: HashMap<SessionId, Seq> = HashMap::new();
    for meta in reg.session_list() {
        let since = hello.get(&meta.id).copied().unwrap_or(0);
        for u in reg.read_since(&meta.id, since)? {
            hw.insert(meta.id.clone(), u.seq);
            send_wire(&mut send, &WireMsg::Update(u)).await?;
        }
    }

    loop {
        tokio::select! {
            r = rx.recv() => match r {
                Ok(WireMsg::Update(u)) => {
                    if u.seq > hw.get(&u.session).copied().unwrap_or(0) {
                        hw.insert(u.session.clone(), u.seq);
                        send_wire(&mut send, &WireMsg::Update(u)).await?;
                    }
                }
                Ok(other) => {
                    if let Err(e) = send_wire(&mut send, &other).await {
                        tracing::warn!("send_wire failed for {other:?}: {e:#}");
                        return Err(e);
                    }
                }
                Err(broadcast::error::RecvError::Lagged(n)) => {
                    tracing::warn!("phone broadcast lagged by {n}");
                    continue;
                }
                Err(e) => {
                    tracing::warn!("phone broadcast closed: {e}");
                    break;
                }
            },
            r = recv_frame(&mut recv) => match r {
                Ok(body) => {
                    if let Ok(m) = ciborium::from_reader::<WireMsg, _>(&body[..]) {
                        handle_inbound(m, &reg, &out_tx).await;
                    }
                }
                Err(e) => {
                    tracing::warn!("phone recv_frame ended: {e}");
                    break;
                }
            },
        }
    }
    Ok(())
}

async fn handle_inbound(m: WireMsg, reg: &Arc<Registry>, out_tx: &mpsc::Sender<EmacsOut>) {
    // A phone answered. Resolution is idempotent: only the first device to
    // answer a given (session,id) is honored -- a second device that raced the
    // resolve broadcast is dropped, so Emacs never gets two responses. On the
    // winning answer, clear the prompt on every other connected phone.
    if let WireMsg::PermissionRes { session, id, .. } = &m {
        if !reg.resolve_permission(session, id) {
            tracing::info!("dropping duplicate permission answer for {session}/{id}");
            return;
        }
        reg.broadcast(WireMsg::PermissionResolved {
            session: session.clone(),
            id: id.clone(),
        });
    }
    let ev = match m {
        // A prompt is only accepted when the agent's input is available (session
        // idle) and no other prompt has claimed the slot this instant. If the
        // LLM is mid-turn -- or another device just won the sub-RTT race -- we
        // reject it, so only one prompt lands per idle window. (Interrupt is NOT
        // gated -- stopping a running turn must always get through.)
        WireMsg::Input { session, text } => {
            if reg.try_claim_input(&session) {
                Some(EmacsOut::Inject { session, text })
            } else {
                tracing::info!("rejecting input for busy/claimed/unknown session {session}");
                None
            }
        }
        WireMsg::PermissionRes {
            session,
            id,
            option,
        } => Some(EmacsOut::PermissionResponse {
            session,
            id,
            option,
        }),
        WireMsg::Command {
            session,
            name,
            arg,
        } => Some(EmacsOut::Command { session, name, arg }),
        WireMsg::Interrupt { session } => Some(EmacsOut::Interrupt { session }),
        _ => None,
    };
    if let Some(ev) = ev {
        let _ = out_tx.send(ev).await;
    }
}

/// Fire a wake-only push on turn-complete / permission when no client is live.
pub fn spawn_push_watcher(
    reg: Arc<Registry>,
    roster: Arc<Mutex<Roster>>,
    presence: Presence,
    push: Arc<dyn PushSender>,
    host_id: String,
) -> JoinHandle<()> {
    let mut rx = reg.subscribe();
    tokio::spawn(async move {
        loop {
            let (session, kind) = match rx.recv().await {
                Ok(WireMsg::Status {
                    session,
                    state: SessionState::Idle,
                }) => (session, "turn_done"),
                Ok(WireMsg::PermissionReq { session, .. }) => (session, "permission"),
                Ok(_) => continue,
                Err(broadcast::error::RecvError::Lagged(_)) => continue,
                Err(_) => break,
            };
            if presence.connected() == 0 {
                let tokens = roster.lock().unwrap().client_tokens();
                for tok in tokens {
                    push.wake(&tok, &host_id, &session, kind).await;
                }
            }
        }
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    use async_trait::async_trait;
    use asb_protocol::client::PhoneClient;
    use asb_protocol::emacs::EmacsIn;
    use asb_protocol::identity::Identity;
    use asb_protocol::model::Payload;
    use asb_protocol::net::{build_endpoint_minimal, ready_addr};
    use asb_protocol::pairing::{pair_host, pair_join};
    use asb_protocol::roster::RosterEntry;
    use roam_pake::PairingCode;
    use std::time::Duration;

    #[derive(Default, Clone)]
    struct SpyPush {
        calls: Arc<Mutex<Vec<(String, String, String, String)>>>,
    }
    #[async_trait]
    impl PushSender for SpyPush {
        async fn wake(&self, token: &str, host_id: &str, session: &str, kind: &str) {
            self.calls.lock().unwrap().push((
                token.into(),
                host_id.into(),
                session.into(),
                kind.into(),
            ));
        }
    }

    struct Paired {
        reg: Arc<Registry>,
        roster: Arc<Mutex<Roster>>,
        host_ep: Endpoint,
        host_addr: iroh::EndpointAddr,
        phone_ep: Endpoint,
        presence: Presence,
    }

    /// Pair a phone with a host and return the wired-up pieces.
    async fn setup(dir: &std::path::Path, fcm: Option<&str>) -> Paired {
        let host_id = Identity::load_or_create(&dir.join("host.json")).unwrap();
        let phone_id = Identity::load_or_create(&dir.join("phone.json")).unwrap();
        let reg = Arc::new(Registry::new(dir.join("logs")));
        let roster = Arc::new(Mutex::new(Roster::load(&dir.join("roster.json")).unwrap()));
        let host_ep = build_endpoint_minimal(host_id.secret_bytes()).await.unwrap();
        let phone_ep = build_endpoint_minimal(phone_id.secret_bytes()).await.unwrap();
        let host_addr = ready_addr(&host_ep).await;
        let host_node = host_ep.id();

        let code = PairingCode::generate();
        let code_str = code.as_str().to_string();
        let host_ep2 = host_ep.clone();
        let ht = tokio::spawn(async move { pair_host(&host_ep2, &code, &host_id).await });
        let _ = pair_join(
            &phone_ep,
            host_node,
            host_addr.clone(),
            PairingCode::parse(&code_str).unwrap(),
            &phone_id,
            fcm.map(|s| s.to_string()),
        )
        .await
        .unwrap();
        let client_entry: RosterEntry = ht.await.unwrap().unwrap();
        roster.lock().unwrap().add(client_entry).unwrap();

        Paired {
            reg,
            roster,
            host_ep,
            host_addr,
            phone_ep,
            presence: Presence::new(),
        }
    }

    #[tokio::test]
    async fn phone_mirrors_and_injects() {
        let dir = tempfile::tempdir().unwrap();
        let p = setup(dir.path(), Some("fcmtok")).await;
        let (out_tx, mut out_rx) = mpsc::channel(16);
        let _srv = spawn_phone_server(
            p.host_ep.clone(),
            p.reg.clone(),
            p.roster.clone(),
            out_tx,
            p.presence.clone(),
        );

        // scripted turn
        p.reg
            .handle_emacs(0, EmacsIn::SessionOpen {
                session: "s".into(),
                title: "demo".into(),
            })
            .await
            .unwrap();
        p.reg
            .handle_emacs(0, EmacsIn::Status {
                session: "s".into(),
                state: SessionState::Running,
            })
            .await
            .unwrap();
        p.reg
            .handle_emacs(0, EmacsIn::Msg {
                session: "s".into(),
                seq: 0,
                turn: 0,
                payload: Payload::AgentMessage {
                    text: "the answer is 42".into(),
                },
                ord: None,
            })
            .await
            .unwrap();
        // Turn complete -> idle, so the phone's follow-up prompt is accepted.
        p.reg
            .handle_emacs(0, EmacsIn::Status {
                session: "s".into(),
                state: SessionState::Idle,
            })
            .await
            .unwrap();

        let mut client = PhoneClient::connect(&p.phone_ep, p.host_addr.clone())
            .await
            .unwrap();
        client.hello(None, HashMap::new()).await.unwrap();
        let u = client
            .next_update_timeout(Duration::from_secs(5))
            .await
            .unwrap();
        match u.payload {
            Payload::AgentMessage { text } => assert!(text.contains("42"), "got {text}"),
            other => panic!("expected AgentMessage, got {other:?}"),
        }

        client.input("s", "run it again").await.unwrap();
        let ev = tokio::time::timeout(Duration::from_secs(5), out_rx.recv())
            .await
            .unwrap()
            .unwrap();
        match ev {
            EmacsOut::Inject { text, .. } => assert_eq!(text, "run it again"),
            other => panic!("expected Inject, got {other:?}"),
        }

        p.host_ep.close().await;
        p.phone_ep.close().await;
    }

    #[tokio::test]
    async fn duplicate_permission_answer_is_dropped() {
        let dir = tempfile::tempdir().unwrap();
        let p = setup(dir.path(), None).await;
        let (out_tx, mut out_rx) = mpsc::channel(16);
        let _srv = spawn_phone_server(
            p.host_ep.clone(),
            p.reg.clone(),
            p.roster.clone(),
            out_tx,
            p.presence.clone(),
        );

        p.reg
            .handle_emacs(0, EmacsIn::SessionOpen {
                session: "s".into(),
                title: "demo".into(),
            })
            .await
            .unwrap();
        p.reg
            .handle_emacs(0, EmacsIn::Permission {
                session: "s".into(),
                id: "p1".into(),
                command: "rm -rf".into(),
                options: vec![],
            })
            .await
            .unwrap();

        let mut client = PhoneClient::connect(&p.phone_ep, p.host_addr.clone())
            .await
            .unwrap();
        client.hello(None, HashMap::new()).await.unwrap();

        // Two devices race to answer the same (session,id) before the resolve
        // broadcast reaches the loser -- both answers reach the sidecar.
        client.permission("s", "p1", "approve").await.unwrap();
        client.permission("s", "p1", "approve").await.unwrap();

        // Emacs sees exactly one response...
        let ev = tokio::time::timeout(Duration::from_secs(5), out_rx.recv())
            .await
            .unwrap()
            .unwrap();
        match ev {
            EmacsOut::PermissionResponse { id, option, .. } => {
                assert_eq!(id, "p1");
                assert_eq!(option, "approve");
            }
            other => panic!("expected PermissionResponse, got {other:?}"),
        }
        // ...the duplicate is dropped.
        assert!(
            tokio::time::timeout(Duration::from_millis(500), out_rx.recv())
                .await
                .is_err(),
            "duplicate permission answer should have been dropped"
        );

        p.host_ep.close().await;
        p.phone_ep.close().await;
    }

    #[tokio::test]
    async fn input_rejected_while_running() {
        let dir = tempfile::tempdir().unwrap();
        let p = setup(dir.path(), None).await;
        let (out_tx, mut out_rx) = mpsc::channel(16);
        let _srv = spawn_phone_server(
            p.host_ep.clone(),
            p.reg.clone(),
            p.roster.clone(),
            out_tx,
            p.presence.clone(),
        );

        p.reg
            .handle_emacs(0, EmacsIn::SessionOpen {
                session: "s".into(),
                title: "demo".into(),
            })
            .await
            .unwrap();
        p.reg
            .handle_emacs(0, EmacsIn::Status {
                session: "s".into(),
                state: SessionState::Running,
            })
            .await
            .unwrap();

        let mut client = PhoneClient::connect(&p.phone_ep, p.host_addr.clone())
            .await
            .unwrap();
        client.hello(None, HashMap::new()).await.unwrap();

        // LLM is running -> the prompt is rejected (no EmacsOut).
        client.input("s", "while busy").await.unwrap();
        assert!(
            tokio::time::timeout(Duration::from_millis(500), out_rx.recv())
                .await
                .is_err(),
            "input while running should be rejected"
        );

        // Once idle, the same phone's prompt is accepted.
        p.reg
            .handle_emacs(0, EmacsIn::Status {
                session: "s".into(),
                state: SessionState::Idle,
            })
            .await
            .unwrap();
        client.input("s", "now idle").await.unwrap();
        let ev = tokio::time::timeout(Duration::from_secs(5), out_rx.recv())
            .await
            .unwrap()
            .unwrap();
        match ev {
            EmacsOut::Inject { text, .. } => assert_eq!(text, "now idle"),
            other => panic!("expected Inject, got {other:?}"),
        }

        p.host_ep.close().await;
        p.phone_ep.close().await;
    }

    #[tokio::test]
    async fn idle_race_only_first_input_wins() {
        let dir = tempfile::tempdir().unwrap();
        let p = setup(dir.path(), None).await;
        let (out_tx, mut out_rx) = mpsc::channel(16);
        let _srv = spawn_phone_server(
            p.host_ep.clone(),
            p.reg.clone(),
            p.roster.clone(),
            out_tx,
            p.presence.clone(),
        );

        // Session opens idle; Emacs has NOT reported Running yet.
        p.reg
            .handle_emacs(0, EmacsIn::SessionOpen {
                session: "s".into(),
                title: "demo".into(),
            })
            .await
            .unwrap();

        let mut client = PhoneClient::connect(&p.phone_ep, p.host_addr.clone())
            .await
            .unwrap();
        client.hello(None, HashMap::new()).await.unwrap();

        // Two prompts race within the same RTT, both while the session still
        // reads idle -- only the first claims the slot.
        client.input("s", "first").await.unwrap();
        client.input("s", "second").await.unwrap();

        let ev = tokio::time::timeout(Duration::from_secs(5), out_rx.recv())
            .await
            .unwrap()
            .unwrap();
        match ev {
            EmacsOut::Inject { text, .. } => assert_eq!(text, "first"),
            other => panic!("expected Inject, got {other:?}"),
        }
        assert!(
            tokio::time::timeout(Duration::from_millis(500), out_rx.recv())
                .await
                .is_err(),
            "second racing prompt should have been dropped"
        );

        // Emacs runs the turn and returns to idle -> the claim is released.
        p.reg
            .handle_emacs(0, EmacsIn::Status {
                session: "s".into(),
                state: SessionState::Running,
            })
            .await
            .unwrap();
        p.reg
            .handle_emacs(0, EmacsIn::Status {
                session: "s".into(),
                state: SessionState::Idle,
            })
            .await
            .unwrap();
        client.input("s", "third").await.unwrap();
        let ev = tokio::time::timeout(Duration::from_secs(5), out_rx.recv())
            .await
            .unwrap()
            .unwrap();
        match ev {
            EmacsOut::Inject { text, .. } => assert_eq!(text, "third"),
            other => panic!("expected Inject, got {other:?}"),
        }

        p.host_ep.close().await;
        p.phone_ep.close().await;
    }

    #[tokio::test]
    async fn push_on_turn_complete_when_no_client() {
        let dir = tempfile::tempdir().unwrap();
        let p = setup(dir.path(), Some("fcmtok")).await;
        let push = Arc::new(SpyPush::default());
        let _w = spawn_push_watcher(
            p.reg.clone(),
            p.roster.clone(),
            p.presence.clone(),
            push.clone(),
            "host".into(),
        );

        // no phone connected -> presence 0
        p.reg
            .handle_emacs(0, EmacsIn::SessionOpen {
                session: "s".into(),
                title: "demo".into(),
            })
            .await
            .unwrap();
        p.reg
            .handle_emacs(0, EmacsIn::Status {
                session: "s".into(),
                state: SessionState::Running,
            })
            .await
            .unwrap();
        p.reg
            .handle_emacs(0, EmacsIn::Status {
                session: "s".into(),
                state: SessionState::Idle,
            })
            .await
            .unwrap();

        let mut fired = None;
        for _ in 0..100 {
            if let Some(c) = push.calls.lock().unwrap().first().cloned() {
                fired = Some(c);
                break;
            }
            tokio::time::sleep(Duration::from_millis(10)).await;
        }
        let (tok, host, sess, kind) = fired.expect("push should fire");
        assert_eq!((tok.as_str(), host.as_str(), sess.as_str(), kind.as_str()),
                   ("fcmtok", "host", "s", "turn_done"));

        p.host_ep.close().await;
        p.phone_ep.close().await;
    }
}
