use serde::{Deserialize, Serialize};

use crate::model::{Payload, SessionId, SessionState, Seq, TurnId};

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
        /// At-least-once dedup key, from the provider's outbox. `cid` is
        /// monotonic within an `epoch` (one provider process lifetime); a
        /// resent `cid <= applied` is skipped, not re-appended.
        #[serde(default)]
        cid: Option<u64>,
        #[serde(default)]
        epoch: Option<String>,
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
