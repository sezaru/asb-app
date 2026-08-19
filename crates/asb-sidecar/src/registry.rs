use std::collections::{HashMap, HashSet};
use std::path::PathBuf;
use std::sync::Mutex;

use asb_protocol::emacs::EmacsIn;
use asb_protocol::model::{SessionId, SessionState, Seq, TurnId, Update};
use asb_protocol::replay::ReplayLog;
use asb_protocol::wire::{SessionMeta, WireMsg};
use tokio::sync::{broadcast, watch};

/// Aggregates sessions from all connected Emacs instances. The sidecar — not the
/// provider — assigns `seq` (from the replay log) and `turn` (bumped on
/// idle→running), so ordering is monotonic across provider reconnects.
pub struct Registry {
    dir: PathBuf,
    sessions: Mutex<HashMap<SessionId, SessionEntry>>,
    /// Permission requests still awaiting an answer, keyed `(session, id)`. The
    /// first device to answer removes the entry; later duplicates are ignored.
    pending_perms: Mutex<HashSet<(SessionId, String)>>,
    tx: broadcast::Sender<WireMsg>,
    /// Count of active (open) sessions, published on every change. The daemon
    /// watches this to self-terminate once the last agent-shell buffer closes.
    active_tx: watch::Sender<usize>,
    /// Kept alive so `active_tx.send` always has a receiver and therefore always
    /// updates the stored count -- otherwise a send with no live subscriber is a
    /// silent no-op and the count desyncs.
    _active_keepalive: watch::Receiver<usize>,
}

struct SessionEntry {
    log: ReplayLog,
    title: String,
    state: SessionState,
    turn: TurnId,
    /// Emacs-server connection id that currently owns this session. Reconnect
    /// re-adopts it (SessionOpen updates the owner); a dropped connection frees
    /// the sessions it owned (`close_connection`), which drives the ref-count.
    owner: u64,
    /// Optimistically set the instant a phone prompt is accepted, before Emacs
    /// reports Running, so a second prompt racing within the same RTT loses.
    /// Cleared by the next Status from Emacs (which is then authoritative).
    input_claimed: bool,
}

impl Registry {
    pub fn new(dir: PathBuf) -> Self {
        let (tx, _) = broadcast::channel(1024);
        let (active_tx, active_keepalive) = watch::channel(0);
        Self {
            dir,
            sessions: Mutex::new(HashMap::new()),
            pending_perms: Mutex::new(HashSet::new()),
            tx,
            active_tx,
            _active_keepalive: active_keepalive,
        }
    }

    /// Watch the active-session count (for ref-counted daemon shutdown).
    pub fn active_rx(&self) -> watch::Receiver<usize> {
        self.active_tx.subscribe()
    }

    /// Free every session owned by a dropped connection (its Emacs closed or
    /// crashed), decrementing the active count so the daemon can wind down.
    pub fn close_connection(&self, conn: u64) {
        let mut sessions = self.sessions.lock().unwrap();
        let before = sessions.len();
        sessions.retain(|_, e| e.owner != conn);
        if sessions.len() != before {
            let _ = self.active_tx.send(sessions.len());
        }
    }

    /// Mark a permission answered. Returns true only for the FIRST caller of a
    /// given `(session, id)`; later duplicates (a second device that raced the
    /// resolve broadcast) return false and should be dropped.
    pub fn resolve_permission(&self, session: &str, id: &str) -> bool {
        self.pending_perms
            .lock()
            .unwrap()
            .remove(&(session.to_string(), id.to_string()))
    }

    /// Reserve a session's input slot for one prompt. Returns true only when the
    /// session is idle AND unclaimed, so the loser of a sub-RTT race (both
    /// devices send while idle, before Emacs reports Running) gets false. The
    /// claim is released by the next Status from Emacs.
    pub fn try_claim_input(&self, session: &str) -> bool {
        let mut sessions = self.sessions.lock().unwrap();
        match sessions.get_mut(session) {
            Some(e) if e.state == SessionState::Idle && !e.input_claimed => {
                e.input_claimed = true;
                true
            }
            _ => false,
        }
    }

    pub fn subscribe(&self) -> broadcast::Receiver<WireMsg> {
        self.tx.subscribe()
    }

    /// Publish a host->phone message to every connected phone.
    pub fn broadcast(&self, m: WireMsg) {
        let _ = self.tx.send(m);
    }

    pub async fn handle_emacs(&self, conn: u64, msg: EmacsIn) -> anyhow::Result<()> {
        let mut sessions = self.sessions.lock().unwrap();
        match msg {
            EmacsIn::SessionOpen { session, title } => {
                if let Some(e) = sessions.get_mut(&session) {
                    // Reconnect / re-announce: re-adopt under the current conn so
                    // a socket blip doesn't orphan the session.
                    e.owner = conn;
                } else {
                    let log = ReplayLog::open(&self.dir, &session)?;
                    sessions.insert(
                        session,
                        SessionEntry {
                            log,
                            title,
                            state: SessionState::Idle,
                            turn: 0,
                            owner: conn,
                            input_claimed: false,
                        },
                    );
                    // Announce the new session to phones already connected, so it
                    // shows its title right away (a fresh connect learns it via the
                    // hello SessionList instead).
                    let metas = sessions
                        .iter()
                        .map(|(id, e)| SessionMeta {
                            id: id.clone(),
                            title: e.title.clone(),
                            state: e.state,
                            last_seq: e.log.last_seq(),
                        })
                        .collect();
                    let _ = self.tx.send(WireMsg::SessionList { sessions: metas });
                }
                let _ = self.active_tx.send(sessions.len());
            }
            EmacsIn::Msg {
                session,
                payload,
                cid,
                epoch,
                ..
            } => {
                let entry = sessions
                    .get_mut(&session)
                    .ok_or_else(|| anyhow::anyhow!("msg for unknown session {session}"))?;
                let dedup = match (epoch, cid) {
                    (Some(e), Some(c)) => Some((e, c)),
                    _ => None,
                };
                // A resent, already-applied message: the log's high-water (rebuilt
                // from disk on open) recognizes it across restarts, so we skip the
                // append AND the re-broadcast — no duplicate on any phone.
                if let Some((e, c)) = &dedup {
                    if entry.log.is_applied(e, *c) {
                        return Ok(());
                    }
                }
                let seq = entry.log.append(payload.clone(), entry.turn, dedup)?;
                let _ = self.tx.send(WireMsg::Update(Update {
                    session,
                    seq,
                    turn: entry.turn,
                    payload,
                }));
            }
            EmacsIn::Status { session, state } => {
                let entry = sessions
                    .get_mut(&session)
                    .ok_or_else(|| anyhow::anyhow!("status for unknown session {session}"))?;
                if state == SessionState::Running && entry.state != SessionState::Running {
                    entry.turn += 1;
                }
                entry.state = state;
                entry.input_claimed = false;
                let _ = self.tx.send(WireMsg::Status { session, state });
            }
            EmacsIn::Permission {
                session,
                id,
                command,
                options,
            } => {
                self.pending_perms
                    .lock()
                    .unwrap()
                    .insert((session.clone(), id.clone()));
                let _ = self.tx.send(WireMsg::PermissionReq {
                    session,
                    id,
                    command,
                    options,
                });
            }
            EmacsIn::SessionClose { session } => {
                sessions.remove(&session);
                self.pending_perms.lock().unwrap().retain(|(s, _)| s != &session);
                let _ = self.active_tx.send(sessions.len());
            }
        }
        Ok(())
    }

    pub fn last_seq(&self, session: &str) -> Seq {
        self.sessions
            .lock()
            .unwrap()
            .get(session)
            .map(|e| e.log.last_seq())
            .unwrap_or(0)
    }

    pub fn state(&self, session: &str) -> Option<SessionState> {
        self.sessions.lock().unwrap().get(session).map(|e| e.state)
    }

    pub fn session_list(&self) -> Vec<SessionMeta> {
        self.sessions
            .lock()
            .unwrap()
            .iter()
            .map(|(id, e)| SessionMeta {
                id: id.clone(),
                title: e.title.clone(),
                state: e.state,
                last_seq: e.log.last_seq(),
            })
            .collect()
    }

    pub fn read_since(&self, session: &str, since: Seq) -> anyhow::Result<Vec<Update>> {
        let sessions = self.sessions.lock().unwrap();
        match sessions.get(session) {
            Some(e) => Ok(e.log.read_since(since)?),
            None => Ok(vec![]),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use asb_protocol::model::Payload;

    #[tokio::test]
    async fn registry_records_and_broadcasts() {
        let dir = tempfile::tempdir().unwrap();
        let reg = Registry::new(dir.path().to_path_buf());
        let mut rx = reg.subscribe();

        reg.handle_emacs(0, EmacsIn::SessionOpen {
            session: "s".into(),
            title: "t".into(),
        })
        .await
        .unwrap();
        reg.handle_emacs(0, EmacsIn::Msg {
            session: "s".into(),
            seq: 0,
            turn: 99, // provider's turn is advisory; the registry owns it
            payload: Payload::AgentMessage { text: "hi".into() },
            cid: None,
            epoch: None,
        })
        .await
        .unwrap();

        // SessionOpen announces the session list before the Msg's Update.
        assert!(matches!(
            rx.recv().await.unwrap(),
            WireMsg::SessionList { .. }
        ));
        match rx.recv().await.unwrap() {
            WireMsg::Update(u) => {
                assert_eq!(u.seq, 1);
                assert_eq!(u.turn, 0); // no Status Running yet
            }
            other => panic!("expected Update, got {other:?}"),
        }
        assert_eq!(reg.last_seq("s"), 1);
    }

    #[tokio::test]
    async fn msg_resend_deduped_across_reopen() {
        let dir = tempfile::tempdir().unwrap();
        let mk_msg = |c: u64, text: &str| EmacsIn::Msg {
            session: "s".into(),
            seq: 0,
            turn: 0,
            payload: Payload::AgentMessage { text: text.into() },
            cid: Some(c),
            epoch: Some("e".into()),
        };
        {
            let reg = Registry::new(dir.path().to_path_buf());
            reg.handle_emacs(0, EmacsIn::SessionOpen {
                session: "s".into(),
                title: "t".into(),
            })
            .await
            .unwrap();
            reg.handle_emacs(0, mk_msg(5, "hi")).await.unwrap();
            assert_eq!(reg.last_seq("s"), 1);
        }
        // A fresh Registry over the same dir simulates a daemon restart: the
        // per-session log rebuilds its dedup high-water from disk.
        let reg = Registry::new(dir.path().to_path_buf());
        reg.handle_emacs(0, EmacsIn::SessionOpen {
            session: "s".into(),
            title: "t".into(),
        })
        .await
        .unwrap();
        assert_eq!(reg.last_seq("s"), 1);
        // The provider resends the un-acked cid=5 -> recognized, not re-appended.
        reg.handle_emacs(0, mk_msg(5, "hi")).await.unwrap();
        assert_eq!(reg.last_seq("s"), 1, "resend across restart must not duplicate");
        // A genuinely new cid=6 still lands.
        reg.handle_emacs(0, mk_msg(6, "bye")).await.unwrap();
        assert_eq!(reg.last_seq("s"), 2);
    }

    #[tokio::test]
    async fn active_count_tracks_open_close_and_connection_drop() {
        let dir = tempfile::tempdir().unwrap();
        let reg = Registry::new(dir.path().to_path_buf());
        let rx = reg.active_rx();
        assert_eq!(*rx.borrow(), 0);
        for s in ["a", "b"] {
            reg.handle_emacs(1, EmacsIn::SessionOpen { session: s.into(), title: s.into() })
                .await
                .unwrap();
        }
        assert_eq!(*rx.borrow(), 2);
        // explicit buffer close decrements
        reg.handle_emacs(1, EmacsIn::SessionClose { session: "a".into() })
            .await
            .unwrap();
        assert_eq!(*rx.borrow(), 1);
        // the owning connection dropping frees the rest -> daemon can wind down
        reg.close_connection(1);
        assert_eq!(*rx.borrow(), 0);
    }

    #[tokio::test]
    async fn reconnect_readopts_session_so_old_conn_drop_is_harmless() {
        let dir = tempfile::tempdir().unwrap();
        let reg = Registry::new(dir.path().to_path_buf());
        reg.handle_emacs(1, EmacsIn::SessionOpen { session: "s".into(), title: "t".into() })
            .await
            .unwrap();
        // A reconnect re-announces the same session on a NEW connection.
        reg.handle_emacs(2, EmacsIn::SessionOpen { session: "s".into(), title: "t".into() })
            .await
            .unwrap();
        assert_eq!(*reg.active_rx().borrow(), 1);
        // The stale (old) connection dropping must NOT free it -- ownership moved.
        reg.close_connection(1);
        assert_eq!(*reg.active_rx().borrow(), 1, "blip must not orphan the session");
        // The current owner dropping does free it.
        reg.close_connection(2);
        assert_eq!(*reg.active_rx().borrow(), 0);
    }

    #[tokio::test]
    async fn permission_resolves_once() {
        let dir = tempfile::tempdir().unwrap();
        let reg = Registry::new(dir.path().to_path_buf());
        reg.handle_emacs(0, EmacsIn::Permission {
            session: "s".into(),
            id: "p1".into(),
            command: "rm -rf".into(),
            options: vec![],
        })
        .await
        .unwrap();

        // unknown ids are never "first"
        assert!(!reg.resolve_permission("s", "nope"));
        // first answer wins, second (raced) duplicate is dropped
        assert!(reg.resolve_permission("s", "p1"));
        assert!(!reg.resolve_permission("s", "p1"));
    }

    #[tokio::test]
    async fn session_open_announces_to_connected() {
        let dir = tempfile::tempdir().unwrap();
        let reg = Registry::new(dir.path().to_path_buf());
        let mut rx = reg.subscribe(); // a phone already connected
        reg.handle_emacs(0, EmacsIn::SessionOpen {
            session: "s".into(),
            title: "My Task".into(),
        })
        .await
        .unwrap();
        match rx.recv().await.unwrap() {
            WireMsg::SessionList { sessions } => {
                assert_eq!(sessions.len(), 1);
                assert_eq!(sessions[0].id, "s");
                assert_eq!(sessions[0].title, "My Task");
            }
            other => panic!("expected SessionList, got {other:?}"),
        }
    }

    #[tokio::test]
    async fn running_bumps_turn() {
        let dir = tempfile::tempdir().unwrap();
        let reg = Registry::new(dir.path().to_path_buf());
        reg.handle_emacs(0, EmacsIn::SessionOpen {
            session: "s".into(),
            title: "t".into(),
        })
        .await
        .unwrap();
        let mut rx = reg.subscribe();
        reg.handle_emacs(0, EmacsIn::Status {
            session: "s".into(),
            state: SessionState::Running,
        })
        .await
        .unwrap();
        reg.handle_emacs(0, EmacsIn::Msg {
            session: "s".into(),
            seq: 0,
            turn: 0,
            payload: Payload::AgentMessage { text: "hi".into() },
            cid: None,
            epoch: None,
        })
        .await
        .unwrap();

        // drain the Status broadcast, then the Update
        assert!(matches!(rx.recv().await.unwrap(), WireMsg::Status { .. }));
        match rx.recv().await.unwrap() {
            WireMsg::Update(u) => assert_eq!(u.turn, 1),
            other => panic!("expected Update, got {other:?}"),
        }
    }
}
