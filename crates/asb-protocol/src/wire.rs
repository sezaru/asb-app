use std::collections::HashMap;

use serde::{Deserialize, Serialize};

use crate::emacs::PermOption;
use crate::model::{SessionConfig, SessionId, SessionState, Seq, Update};

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
    /// Browse the HOST machine's filesystem (the sidecar's own FS). `path` None
    /// means "start at the user's home". `req` correlates the reply to the phone
    /// that asked, so concurrent browses on one connection don't cross.
    FsList {
        req: u64,
        path: Option<String>,
    },
    /// Begin a chunked attachment upload: the sidecar opens a file for `name`.
    /// The bytes follow as `UploadChunk`s and `UploadFinish` seals it. Chunking
    /// keeps every frame well under `MAX_FRAME` and the phone's working set to
    /// one chunk regardless of file size.
    UploadStart {
        req: u64,
        name: String,
    },
    /// One raw byte slice of the file being uploaded under `req`. `serde_bytes`
    /// keeps it a CBOR byte string (not an int array), so the wire carries the
    /// bytes verbatim — no base64 inflation or encode/decode on either end.
    UploadChunk {
        req: u64,
        #[serde(with = "serde_bytes")]
        data: Vec<u8>,
    },
    /// Seal the upload under `req`; the sidecar flushes and replies `UploadDone`.
    UploadFinish {
        req: u64,
    },
    /// Start a brand-new agent session on the host from the phone. `prompt` is
    /// the first message (also the session's title, as elsewhere); `cwd` is an
    /// optional host directory to run it in (picked via the FS browser). There
    /// is no session id yet — the host spawns one and it mirrors back through the
    /// normal `SessionList`/`Update` path. `req` correlates a possible error.
    NewSession {
        req: u64,
        prompt: String,
        cwd: Option<String>,
    },
    /// Reopen an existing session the host still has a log for but which is not
    /// currently open in Emacs (see `SessionMeta::open`). The host resumes it;
    /// it then mirrors back like any live session.
    OpenSession {
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
    /// The session's backend-authoritative knobs: available models / modes /
    /// thinking levels (+ current) and the advertised slash commands. Sent on
    /// connect (per session, in the initial burst) and again whenever any of
    /// them changes. The phone replaces its whole config for the session.
    Config {
        session: SessionId,
        config: SessionConfig,
    },
    /// Reply to `FsList`: the resolved directory, its parent (None at the root),
    /// and its entries (dirs first, then files, each alphabetical).
    FsEntries {
        req: u64,
        dir: String,
        parent: Option<String>,
        entries: Vec<FsEntry>,
    },
    /// Reply to `Upload`: the attachment's absolute path on the host.
    UploadDone {
        req: u64,
        path: String,
    },
    /// A browse or upload failed; `req` correlates it to the request.
    FsError {
        req: u64,
        message: String,
    },
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct SessionMeta {
    pub id: SessionId,
    pub title: String,
    pub state: SessionState,
    pub last_seq: Seq,
    /// True when the session is live in Emacs (mirrored). False for a session
    /// the host still has a log for but which is closed — the phone lists these
    /// as resumable and can reopen one with `OpenSession`. Defaults true so an
    /// older peer that omits it is treated as open.
    #[serde(default = "default_true")]
    pub open: bool,
}

fn default_true() -> bool {
    true
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct FsEntry {
    pub name: String,
    pub path: String,
    pub is_dir: bool,
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
    fn wire_new_session_cbor_roundtrips() {
        let m = WireMsg::NewSession {
            req: 4,
            prompt: "fix the auth test".into(),
            cwd: Some("/home/me/proj".into()),
        };
        let mut buf = Vec::new();
        ciborium::into_writer(&m, &mut buf).unwrap();
        let back: WireMsg = ciborium::from_reader(&buf[..]).unwrap();
        assert_eq!(m, back);
    }

    #[test]
    fn session_meta_open_defaults_true() {
        // A peer that predates `open` omits it; the field must decode as true.
        let m = SessionMeta {
            id: "s".into(),
            title: "t".into(),
            state: crate::model::SessionState::Idle,
            last_seq: 3,
            open: false,
        };
        let mut buf = Vec::new();
        ciborium::into_writer(&m, &mut buf).unwrap();
        let back: SessionMeta = ciborium::from_reader(&buf[..]).unwrap();
        assert_eq!(m, back);
        assert!(!back.open);
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
