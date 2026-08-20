use std::collections::{HashMap, HashSet};
use std::path::PathBuf;
use std::sync::Mutex;

use asb_protocol::emacs::EmacsIn;
use asb_protocol::model::{Payload, SessionConfig, SessionId, SessionState, Seq, TurnId, Update};
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
    /// Resume gate: session -> the connection that reserved it. Set at
    /// agent-shell-start (before the session is opened by a prompt), so a second
    /// buffer/instance resuming the same session is denied. Released when the
    /// owner closes the session or its connection drops.
    claims: Mutex<HashMap<SessionId, u64>>,
    tx: broadcast::Sender<WireMsg>,
    /// Count of active (open) sessions, published on every change. The daemon
    /// watches this to self-terminate once the last agent-shell buffer closes.
    active_tx: watch::Sender<usize>,
    /// Kept alive so `active_tx.send` always has a receiver and therefore always
    /// updates the stored count -- otherwise a send with no live subscriber is a
    /// silent no-op and the count desyncs.
    _active_keepalive: watch::Receiver<usize>,
}

/// A session title from its first prompt: first line, trimmed, capped so a long
/// prompt doesn't bloat the list.
fn title_hint(prompt: &str) -> String {
    let line = prompt.lines().next().unwrap_or("").trim();
    if line.chars().count() > 80 {
        format!("{}…", line.chars().take(79).collect::<String>())
    } else if line.is_empty() {
        "session".to_string()
    } else {
        line.to_string()
    }
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
    /// Latest backend knobs (models/modes/thought + commands) for this session,
    /// mirrored to phones. Empty until the provider sends its first `Config`.
    config: SessionConfig,
}

impl Registry {
    pub fn new(dir: PathBuf) -> Self {
        let (tx, _) = broadcast::channel(1024);
        let (active_tx, active_keepalive) = watch::channel(0);
        Self {
            dir,
            sessions: Mutex::new(HashMap::new()),
            pending_perms: Mutex::new(HashSet::new()),
            claims: Mutex::new(HashMap::new()),
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
        self.claims.lock().unwrap().retain(|_, &mut c| c != conn);
        let mut sessions = self.sessions.lock().unwrap();
        let before = sessions.len();
        sessions.retain(|_, e| e.owner != conn);
        if sessions.len() != before {
            let _ = self.active_tx.send(sessions.len());
        }
    }

    /// Atomically reserve SESSION for a resume under CONN.  Returns false when
    /// it is already open or reserved by a DIFFERENT connection (resumed
    /// elsewhere) -- the caller then blocks agent-shell from opening the buffer.
    /// Re-entrant for the same conn (a retry).  A dropped connection's
    /// reservations are swept by `close_connection`, so a crash never wedges a
    /// session as permanently un-resumable.
    pub fn claim(&self, conn: u64, session: &SessionId) -> bool {
        // Already open under a different live connection also blocks (the
        // reservation may have lapsed but the session is genuinely active).
        if let Some(e) = self.sessions.lock().unwrap().get(session) {
            if e.owner != conn {
                return false;
            }
        }
        let mut claims = self.claims.lock().unwrap();
        match claims.get(session) {
            Some(&owner) if owner != conn => false,
            _ => {
                claims.insert(session.clone(), conn);
                true
            }
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

    /// Record a client-injected prompt as a `user_message` Update so it shows on
    /// EVERY connected client (and late joiners, via the replay log) -- not just
    /// the device that typed it. The Emacs send-command tap suppresses the mirror
    /// for remote-injected prompts, so the sidecar is the sole source here.
    /// Called only after `try_claim_input` succeeded: the session is idle and the
    /// next Emacs `Status Running` bumps `turn` to `turn + 1`, so that is the turn
    /// this prompt belongs to (grouping it with its own response, not the prior
    /// turn). Best-effort: a log-append failure is logged and dropped.
    pub fn inject_user_message(&self, session: &SessionId, text: String) {
        let mut sessions = self.sessions.lock().unwrap();
        let Some(entry) = sessions.get_mut(session) else {
            return;
        };
        let turn = entry.turn + 1;
        let payload = Payload::UserMessage { text };
        match entry.log.append(payload.clone(), turn, None) {
            Ok(seq) => {
                let _ = self.tx.send(WireMsg::Update(Update {
                    session: session.clone(),
                    seq,
                    turn,
                    payload,
                }));
            }
            Err(e) => tracing::warn!("failed to log injected prompt for {session}: {e:#}"),
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
                            config: SessionConfig::default(),
                        },
                    );
                    // Announce the new session to phones already connected, so it
                    // shows its title right away (a fresh connect learns it via the
                    // hello SessionList instead).
                    let metas = self.metas_locked(&sessions);
                    let _ = self.tx.send(WireMsg::SessionList { sessions: metas });
                }
                let _ = self.active_tx.send(sessions.len());
            }
            EmacsIn::Msg {
                session,
                payload,
                ord,
                ..
            } => {
                let entry = sessions
                    .get_mut(&session)
                    .ok_or_else(|| anyhow::anyhow!("msg for unknown session {session}"))?;
                // A resend OR a replayed phrase whose ordinal is at/below the
                // persisted high-water is already durable: skip the append AND the
                // re-broadcast, so a resume never duplicates history on any phone.
                if let Some(o) = ord {
                    if entry.log.is_applied(o) {
                        return Ok(());
                    }
                }
                let seq = entry.log.append(payload.clone(), entry.turn, ord)?;
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
                self.claims.lock().unwrap().remove(&session);
                self.pending_perms.lock().unwrap().retain(|(s, _)| s != &session);
                let _ = self.active_tx.send(sessions.len());
                // Re-publish the full list so phones flip the just-closed session
                // to open:false (resumable) rather than dropping it — its log is
                // still on disk.
                let metas = self.metas_locked(&sessions);
                let _ = self.tx.send(WireMsg::SessionList { sessions: metas });
            }
            EmacsIn::Config { session, config } => {
                if let Some(entry) = sessions.get_mut(&session) {
                    entry.config = config.clone();
                    let _ = self.tx.send(WireMsg::Config { session, config });
                }
            }
            // Handled synchronously in the emacs server (it needs the boolean
            // reply); never reaches the registry's async dispatch.
            EmacsIn::SessionClaim { .. } => {}
        }
        Ok(())
    }

    /// The session's persisted ordinal high-water, reported to the provider on
    /// session-open so it can seed its per-session counter (and, on a replay,
    /// know how far to re-number before new phrases start appending).
    pub fn high_water(&self, session: &str) -> u64 {
        self.sessions
            .lock()
            .unwrap()
            .get(session)
            .map(|e| e.log.high_water_ord())
            .unwrap_or(0)
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
                open: true,
            })
            .collect()
    }

    /// Every open session plus every closed session the host still has a log
    /// for (marked `open: false`), so the phone can list closed sessions as
    /// resumable. Sent in the connect burst and re-sent whenever a session
    /// opens or closes.
    pub fn full_session_list(&self) -> Vec<SessionMeta> {
        let sessions = self.sessions.lock().unwrap();
        self.metas_locked(&sessions)
    }

    /// Build the open+closed metadata list from an already-held sessions guard
    /// (so callers inside `handle_emacs` don't re-lock and deadlock).
    fn metas_locked(&self, sessions: &HashMap<SessionId, SessionEntry>) -> Vec<SessionMeta> {
        let open_ids: HashSet<SessionId> = sessions.keys().cloned().collect();
        let mut metas: Vec<SessionMeta> = sessions
            .iter()
            .map(|(id, e)| SessionMeta {
                id: id.clone(),
                title: e.title.clone(),
                state: e.state,
                last_seq: e.log.last_seq(),
                open: true,
            })
            .collect();
        metas.extend(self.closed_metas(&open_ids));
        metas
    }

    /// Scan the log directory for sessions not in `open_ids` and describe each
    /// as resumable metadata: title = its first user prompt (first line,
    /// truncated), last_seq from the log. Skips empty/garbled logs.
    fn closed_metas(&self, open_ids: &HashSet<SessionId>) -> Vec<SessionMeta> {
        let mut out = Vec::new();
        let rd = match std::fs::read_dir(&self.dir) {
            Ok(r) => r,
            Err(_) => return out,
        };
        for ent in rd.flatten() {
            let path = ent.path();
            let Some(session) = path
                .file_name()
                .and_then(|n| n.to_str())
                .and_then(|n| n.strip_suffix(".log"))
            else {
                continue;
            };
            if open_ids.contains(session) {
                continue;
            }
            let Ok(log) = ReplayLog::open(&self.dir, session) else {
                continue;
            };
            let updates = log.read_since(0).unwrap_or_default();
            if updates.is_empty() {
                continue;
            }
            let title = updates
                .iter()
                .find_map(|u| match &u.payload {
                    Payload::UserMessage { text } => Some(text.clone()),
                    _ => None,
                })
                .unwrap_or_else(|| "session".to_string());
            out.push(SessionMeta {
                id: session.to_string(),
                title: title_hint(&title),
                state: SessionState::Idle,
                last_seq: log.last_seq(),
                open: false,
            });
        }
        out
    }

    /// Every session's stored config, for the initial burst to a connecting
    /// phone. Sessions still at the default (provider hasn't sent one) are
    /// skipped — there's nothing to mirror yet.
    pub fn configs(&self) -> Vec<(SessionId, SessionConfig)> {
        self.sessions
            .lock()
            .unwrap()
            .iter()
            .filter(|(_, e)| e.config != SessionConfig::default())
            .map(|(id, e)| (id.clone(), e.config.clone()))
            .collect()
    }

    pub fn read_since(&self, session: &str, since: Seq) -> anyhow::Result<Vec<Update>> {
        let sessions = self.sessions.lock().unwrap();
        match sessions.get(session) {
            Some(e) => Ok(e.log.read_since(since)?),
            None => Ok(vec![]),
        }
    }

    /// Read a session's persisted transcript straight from its on-disk log,
    /// whether or not it's currently open — a resumed (closed) session is not in
    /// the map, so `read_since` would return nothing. Used to replay its backlog
    /// to the phone that reopened it.
    pub fn read_log_since(&self, session: &str, since: Seq) -> anyhow::Result<Vec<Update>> {
        {
            let sessions = self.sessions.lock().unwrap();
            if let Some(e) = sessions.get(session) {
                return Ok(e.log.read_since(since)?);
            }
        }
        match ReplayLog::open(&self.dir, session) {
            Ok(log) => Ok(log.read_since(since)?),
            Err(_) => Ok(vec![]),
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
            ord: None,
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
        let mk_msg = |o: u64, text: &str| EmacsIn::Msg {
            session: "s".into(),
            seq: 0,
            turn: 0,
            payload: Payload::AgentMessage { text: text.into() },
            ord: Some(o),
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
        // The provider resends ord=5 (or a resume replays that phrase) -> the
        // rebuilt high-water recognizes it, so it is not re-appended.
        reg.handle_emacs(0, mk_msg(5, "hi")).await.unwrap();
        assert_eq!(reg.last_seq("s"), 1, "resend across restart must not duplicate");
        // A genuinely new ord=6 still lands.
        reg.handle_emacs(0, mk_msg(6, "bye")).await.unwrap();
        assert_eq!(reg.last_seq("s"), 2);
    }

    #[tokio::test]
    async fn inject_user_message_broadcasts_next_turn() {
        let dir = tempfile::tempdir().unwrap();
        let reg = Registry::new(dir.path().to_path_buf());
        reg.handle_emacs(0, EmacsIn::SessionOpen { session: "s".into(), title: "t".into() })
            .await
            .unwrap();
        // One completed turn so `turn` sits at 1 and the session is idle.
        reg.handle_emacs(0, EmacsIn::Status { session: "s".into(), state: SessionState::Running })
            .await
            .unwrap();
        reg.handle_emacs(0, EmacsIn::Status { session: "s".into(), state: SessionState::Idle })
            .await
            .unwrap();

        let mut rx = reg.subscribe();
        reg.inject_user_message(&"s".to_string(), "do it again".into());
        // Grouped with the turn it starts (2), not the completed one (1), and
        // durably logged so a late joiner replays it.
        match rx.recv().await.unwrap() {
            WireMsg::Update(u) => {
                assert_eq!(u.turn, 2, "prompt groups with the turn it starts");
                assert_eq!(u.seq, 1);
                match u.payload {
                    Payload::UserMessage { text } => assert_eq!(text, "do it again"),
                    other => panic!("expected UserMessage, got {other:?}"),
                }
            }
            other => panic!("expected Update, got {other:?}"),
        }
        assert_eq!(reg.read_since("s", 0).unwrap().len(), 1);
    }

    #[tokio::test]
    async fn closed_session_listed_as_resumable() {
        let dir = tempfile::tempdir().unwrap();
        let reg = Registry::new(dir.path().to_path_buf());
        reg.handle_emacs(0, EmacsIn::SessionOpen { session: "s".into(), title: "t".into() })
            .await
            .unwrap();
        // A user prompt becomes the resumable title once the session closes.
        reg.handle_emacs(0, EmacsIn::Msg {
            session: "s".into(),
            seq: 0,
            turn: 0,
            payload: Payload::UserMessage { text: "fix the flaky test\nmore".into() },
            ord: None,
        })
        .await
        .unwrap();

        // Open: present and open=true; no closed entries yet.
        let open = reg.full_session_list();
        assert_eq!(open.len(), 1);
        assert!(open[0].open);

        reg.handle_emacs(0, EmacsIn::SessionClose { session: "s".into() })
            .await
            .unwrap();

        // Closed: still listed, now open=false, title = first line of the prompt.
        let after = reg.full_session_list();
        assert_eq!(after.len(), 1);
        assert_eq!(after[0].id, "s");
        assert!(!after[0].open);
        assert_eq!(after[0].title, "fix the flaky test");

        // A resuming phone can still read the closed session's transcript off
        // disk (it's gone from the in-memory map), so its backlog can be
        // replayed instead of showing an empty history.
        let backlog = reg.read_log_since("s", 0).unwrap();
        assert_eq!(backlog.len(), 1);
        assert!(matches!(
            &backlog[0].payload,
            Payload::UserMessage { text } if text.starts_with("fix the flaky test")
        ));
        // In-map read returns nothing for the closed session (regression guard).
        assert!(reg.read_since("s", 0).unwrap().is_empty());
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
    async fn claim_blocks_concurrent_resume_and_releases() {
        let dir = tempfile::tempdir().unwrap();
        let reg = Registry::new(dir.path().to_path_buf());
        let s = "s".to_string();
        // conn 1 reserves it; a retry from conn 1 is re-entrant.
        assert!(reg.claim(1, &s));
        assert!(reg.claim(1, &s));
        // conn 2 (a second buffer/instance) is blocked while 1 holds it.
        assert!(!reg.claim(2, &s));
        // conn 1 closing the session releases the reservation.
        reg.handle_emacs(1, EmacsIn::SessionClose { session: s.clone() })
            .await
            .unwrap();
        assert!(reg.claim(2, &s));
        // conn 2's connection dropping (crash) releases its reservation too.
        reg.close_connection(2);
        assert!(reg.claim(1, &s));
    }

    #[tokio::test]
    async fn claim_blocked_by_active_session_owned_elsewhere() {
        let dir = tempfile::tempdir().unwrap();
        let reg = Registry::new(dir.path().to_path_buf());
        let s = "s".to_string();
        // Session already open under conn 1 (first prompt sent, past the gate).
        reg.handle_emacs(1, EmacsIn::SessionOpen { session: s.clone(), title: "t".into() })
            .await
            .unwrap();
        // A resume from conn 2 is blocked; the owner may still re-claim.
        assert!(!reg.claim(2, &s));
        assert!(reg.claim(1, &s));
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
            ord: None,
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
