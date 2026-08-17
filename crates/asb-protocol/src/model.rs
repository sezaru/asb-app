use serde::{Deserialize, Serialize};

/// The agent-shell ACP session id (a UUID string), stable across resume.
pub type SessionId = String;
pub type Seq = u64;
pub type TurnId = u64;

/// A single structured piece of a mirrored turn. Lossless: the client, not the
/// wire, decides how to collapse these.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(tag = "type", rename_all = "snake_case")]
pub enum Payload {
    AgentMessage { text: String },
    Thought { text: String },
    ToolCall(ToolCall),
    ToolCallUpdate {
        id: String,
        status: ToolStatus,
        content: Vec<Content>,
    },
    Plan { entries: Vec<String> },
    Usage { input: u64, output: u64 },
    UserMessage { text: String },
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct ToolCall {
    pub id: String,
    pub kind: ToolKind,
    pub title: String,
    pub command: Option<String>,
    pub status: ToolStatus,
    pub content: Vec<Content>,
    pub locations: Vec<String>,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ToolKind {
    Read,
    Edit,
    Command,
    Search,
    Fetch,
    Other,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ToolStatus {
    Pending,
    Running,
    Done,
    Failed,
}

/// Struct variants (not newtype) so serde's internal `kind` tagging works.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(tag = "kind", rename_all = "snake_case")]
pub enum Content {
    Text { text: String },
    Diff { path: String, diff: String },
    FileRef { path: String },
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum SessionState {
    Running,
    Idle,
}

/// One mirrored event, ordered by `seq`, grouped into a turn by `turn`.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct Update {
    pub session: SessionId,
    pub seq: Seq,
    pub turn: TurnId,
    pub payload: Payload,
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn tool_call_payload_roundtrips() {
        let p = Payload::ToolCall(ToolCall {
            id: "t1".into(),
            kind: ToolKind::Command,
            title: "run tests".into(),
            command: Some("cargo test".into()),
            status: ToolStatus::Running,
            content: vec![Content::Text {
                text: "output…".into(),
            }],
            locations: vec![],
        });
        let j = serde_json::to_string(&p).unwrap();
        let back: Payload = serde_json::from_str(&j).unwrap();
        assert_eq!(p, back);
    }

    #[test]
    fn content_variants_roundtrip() {
        let c = vec![
            Content::Text { text: "t".into() },
            Content::Diff {
                path: "a.rs".into(),
                diff: "@@".into(),
            },
            Content::FileRef { path: "b.rs".into() },
        ];
        let j = serde_json::to_string(&c).unwrap();
        let back: Vec<Content> = serde_json::from_str(&j).unwrap();
        assert_eq!(c, back);
    }
}
