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
    Plan { entries: Vec<PlanEntry> },
    Usage { input: u64, output: u64 },
    UserMessage { text: String },
}

/// One plan step, as agent-shell exposes it: its prose plus a lifecycle status
/// so the client can render real progress instead of guessing.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct PlanEntry {
    pub content: String,
    pub status: PlanStatus,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum PlanStatus {
    Pending,
    InProgress,
    Completed,
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

/// A selectable agent option (a model, a session/permission mode, or a thinking
/// level). `id` is what the agent wants back; `name` is the human label.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct ConfigOption {
    pub id: String,
    pub name: String,
    #[serde(default)]
    pub description: Option<String>,
}

/// One slash command the agent advertises, for the composer's autocomplete.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct CommandInfo {
    pub name: String,
    #[serde(default)]
    pub description: Option<String>,
}

/// The live, backend-authoritative knobs for a session: what the agent supports
/// and what is currently selected. Nothing here is hardcoded on the phone — the
/// provider fills it from agent-shell's own state and the phone mirrors it.
#[derive(Debug, Clone, PartialEq, Default, Serialize, Deserialize)]
pub struct SessionConfig {
    #[serde(default)]
    pub models: Vec<ConfigOption>,
    #[serde(default)]
    pub current_model: Option<String>,
    #[serde(default)]
    pub modes: Vec<ConfigOption>,
    #[serde(default)]
    pub current_mode: Option<String>,
    #[serde(default)]
    pub thought_levels: Vec<ConfigOption>,
    #[serde(default)]
    pub current_thought: Option<String>,
    #[serde(default)]
    pub commands: Vec<CommandInfo>,
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
