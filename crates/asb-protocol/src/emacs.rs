use serde::{Deserialize, Serialize};

use crate::model::{Payload, SessionConfig, SessionId, SessionState, Seq, TurnId};

/// Provider (Emacs) -> sidecar, one JSON object per line over the unix socket.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(tag = "t", rename_all = "kebab-case")]
pub enum EmacsIn {
    SessionOpen {
        session: SessionId,
        title: String,
    },
    Msg {
        session: SessionId,
        seq: Seq,
        turn: TurnId,
        payload: Payload,
        /// Per-session provider ordinal: the dedup key. The provider numbers a
        /// session's phrases 1,2,3… in stable order and replays them with the
        /// same ordinals on resume, so `ord <= high-water` is skipped (dedup +
        /// semantic re-mirror suppression) and only the new tail is appended.
        #[serde(default)]
        ord: Option<u64>,
    },
    Status {
        session: SessionId,
        state: SessionState,
    },
    Permission {
        session: SessionId,
        id: String,
        command: String,
        options: Vec<PermOption>,
    },
    SessionClose {
        session: SessionId,
    },
    /// The session's live knobs (models / modes / thinking levels + current) and
    /// advertised slash commands, read from agent-shell state. Sent at
    /// session-open and whenever agent-shell reports a change; the sidecar stores
    /// the latest and mirrors it to phones as `WireMsg::Config`.
    Config {
        session: SessionId,
        config: SessionConfig,
    },
    /// Synchronous resume gate: reserve SESSION before agent-shell opens the
    /// buffer, so the same session cannot be resumed in two buffers/instances
    /// at once. The sidecar replies `claim-result` correlated by `cid`.
    SessionClaim {
        session: SessionId,
        cid: u64,
    },
}

/// Sidecar -> provider (Emacs), one JSON object per line.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(tag = "t", rename_all = "kebab-case")]
pub enum EmacsOut {
    Inject {
        session: SessionId,
        text: String,
    },
    Command {
        session: SessionId,
        name: String,
        arg: Option<String>,
    },
    PermissionResponse {
        session: SessionId,
        id: String,
        option: String,
    },
    Interrupt {
        session: SessionId,
    },
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct PermOption {
    pub id: String,
    pub label: String,
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn emacs_in_msg_parses() {
        let line = r#"{"t":"msg","session":"s","seq":1,"turn":1,"payload":{"type":"agent_message","text":"hi"}}"#;
        match serde_json::from_str::<EmacsIn>(line).unwrap() {
            EmacsIn::Msg { session, seq, .. } => {
                assert_eq!(session, "s");
                assert_eq!(seq, 1);
            }
            _ => panic!("wrong variant"),
        }
    }

    #[test]
    fn emacs_out_inject_serializes_kebab() {
        let e = EmacsOut::Inject {
            session: "s".into(),
            text: "go".into(),
        };
        let j = serde_json::to_string(&e).unwrap();
        assert!(j.contains(r#""t":"inject""#), "got {j}");
    }
}
