use std::collections::{HashMap, HashSet};
use std::path::PathBuf;
use std::sync::Mutex;

use asb_protocol::emacs::EmacsIn;
use asb_protocol::model::{SessionId, SessionState, Seq, TurnId, Update};
use asb_protocol::replay::ReplayLog;
use asb_protocol::wire::{SessionMeta, WireMsg};
use tokio::sync::broadcast;

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
}

struct SessionEntry {
    log: ReplayLog,
    title: String,
    state: SessionState,
    turn: TurnId,
    /// Optimistically set the instant a phone prompt is accepted, before Emacs
    /// reports Running, so a second prompt racing within the same RTT loses.
    /// Cleared by the next Status from Emacs (which is then authoritative).
    input_claimed: bool,
}

impl Registry {
    pub fn new(dir: PathBuf) -> Self {
        let (tx, _) = broadcast::channel(1024);
        Self {
            dir,
            sessions: Mutex::new(HashMap::new()),
            pending_perms: Mutex::new(HashSet::new()),
            tx,
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

    pub async fn handle_emacs(&self, msg: EmacsIn) -> anyhow::Result<()> {
        let mut sessions = self.sessions.lock().unwrap();
        match msg {
            EmacsIn::SessionOpen { session, title } => {
                if !sessions.contains_key(&session) {
                    let log = ReplayLog::open(&self.dir, &session)?;
                    sessions.insert(
                        session,
                        SessionEntry {
                            log,
                            title,
                            state: SessionState::Idle,
                            turn: 0,
                            input_claimed: false,
                        },
                    );
                }
            }
            EmacsIn::Msg {
                session, payload, ..
            } => {
                let entry = sessions
                    .get_mut(&session)
                    .ok_or_else(|| anyhow::anyhow!("msg for unknown session {session}"))?;
                let seq = entry.log.append(payload.clone(), entry.turn)?;
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

        reg.handle_emacs(EmacsIn::SessionOpen {
            session: "s".into(),
            title: "t".into(),
        })
        .await
        .unwrap();
        reg.handle_emacs(EmacsIn::Msg {
            session: "s".into(),
            seq: 0,
            turn: 99, // provider's turn is advisory; the registry owns it
            payload: Payload::AgentMessage { text: "hi".into() },
        })
        .await
        .unwrap();

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
    async fn permission_resolves_once() {
        let dir = tempfile::tempdir().unwrap();
        let reg = Registry::new(dir.path().to_path_buf());
        reg.handle_emacs(EmacsIn::Permission {
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
    async fn running_bumps_turn() {
        let dir = tempfile::tempdir().unwrap();
        let reg = Registry::new(dir.path().to_path_buf());
        reg.handle_emacs(EmacsIn::SessionOpen {
            session: "s".into(),
            title: "t".into(),
        })
        .await
        .unwrap();
        let mut rx = reg.subscribe();
        reg.handle_emacs(EmacsIn::Status {
            session: "s".into(),
            state: SessionState::Running,
        })
        .await
        .unwrap();
        reg.handle_emacs(EmacsIn::Msg {
            session: "s".into(),
            seq: 0,
            turn: 0,
            payload: Payload::AgentMessage { text: "hi".into() },
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
