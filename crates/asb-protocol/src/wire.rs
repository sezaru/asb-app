use std::collections::HashMap;

use serde::{Deserialize, Serialize};

use crate::emacs::PermOption;
use crate::model::{SessionId, SessionState, Seq, Update};

/// Sidecar <-> phone, framed CBOR over an iroh bidirectional stream.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(tag = "type", rename_all = "snake_case")]
pub enum WireMsg {
    // phone -> host
    Hello {
        fcm_token: Option<String>,
        last_seq: HashMap<SessionId, Seq>,
    },
    Catchup {
        session: SessionId,
        since: Seq,
    },
    Input {
        session: SessionId,
        text: String,
    },
    PermissionRes {
        session: SessionId,
        id: String,
        option: String,
    },
    Command {
        session: SessionId,
        name: String,
        arg: Option<String>,
    },
    Interrupt {
        session: SessionId,
    },
    // host -> phone
    SessionList {
        sessions: Vec<SessionMeta>,
    },
    Update(Update),
    Status {
        session: SessionId,
        state: SessionState,
    },
    PermissionReq {
        session: SessionId,
        id: String,
        command: String,
        options: Vec<PermOption>,
    },
    /// A pending permission was answered (by any phone or by Emacs); every phone
    /// clears its prompt so a second device can't answer a resolved request.
    PermissionResolved {
        session: SessionId,
        id: String,
    },
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct SessionMeta {
    pub id: SessionId,
    pub title: String,
    pub state: SessionState,
    pub last_seq: Seq,
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::model::Payload;

    #[test]
    fn wire_update_cbor_roundtrips() {
        let m = WireMsg::Update(Update {
            session: "s".into(),
            seq: 3,
            turn: 1,
            payload: Payload::AgentMessage { text: "hi".into() },
        });
        let mut buf = Vec::new();
        ciborium::into_writer(&m, &mut buf).unwrap();
        let back: WireMsg = ciborium::from_reader(&buf[..]).unwrap();
        assert_eq!(m, back);
    }

    #[test]
    fn wire_hello_cbor_roundtrips() {
        let mut last = HashMap::new();
        last.insert("s".to_string(), 7u64);
        let m = WireMsg::Hello {
            fcm_token: Some("tok".into()),
            last_seq: last,
        };
        let mut buf = Vec::new();
        ciborium::into_writer(&m, &mut buf).unwrap();
        let back: WireMsg = ciborium::from_reader(&buf[..]).unwrap();
        assert_eq!(m, back);
    }
}
