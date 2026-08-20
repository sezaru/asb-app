//! The `flutter_rust_bridge` shim. Delegates to [`crate::client`] and flattens
//! `asb-protocol` types into frb-friendly DTOs.
//!
//! frb generates a Dart class per type reachable from here, and struggles with
//! deeply-nested tagged enums owned by another crate, so the wire model is
//! restated as flat DTOs — the same reason caremate's bridge restates
//! `VaultChange` rather than re-exporting roam's type.

use std::path::Path;

use asb_protocol::client::{PhoneReceiver, PhoneSender};
use asb_protocol::model::{
    CommandInfo, ConfigOption, Content, Payload, PlanEntry, PlanStatus, SessionConfig, Update,
};
use asb_protocol::wire::{SessionMeta, WireMsg};
use flutter_rust_bridge::frb;
// `StreamSink` is generated per-crate by frb's `frb_generated_stream_sink!`
// macro (invoked from frb_generated.rs), so it lives in that module.
use crate::frb_generated::StreamSink;
use tokio::sync::Mutex;

use crate::client::Client;

/// A phone client handle. Opaque to Dart — it owns a live iroh endpoint.
#[frb(opaque)]
pub struct RustClient {
    inner: Client,
}

impl RustClient {
    /// Open the client rooted at an app-private `dir`, reachable over the
    /// internet (iroh relays + discovery).
    pub async fn open(dir: String) -> anyhow::Result<RustClient> {
        Ok(RustClient {
            inner: Client::open(Path::new(&dir)).await?,
        })
    }

    /// Open on a minimal endpoint (LAN only, no relays) — for local testing.
    pub async fn open_local(dir: String) -> anyhow::Result<RustClient> {
        Ok(RustClient {
            inner: Client::open_local(Path::new(&dir)).await?,
        })
    }

    /// This device's node id, hex-encoded.
    #[frb(sync)]
    pub fn node_id_hex(&self) -> String {
        hex(self.inner.node_id())
    }

    /// The hosts this client has paired with, hex node ids.
    pub fn hosts_hex(&self) -> anyhow::Result<Vec<String>> {
        Ok(self.inner.hosts()?.into_iter().map(hex).collect())
    }

    /// Pair with a host addressed by its hex node id, using `code`.
    pub async fn pair(
        &self,
        code: String,
        host_node_id_hex: String,
        fcm: Option<String>,
    ) -> anyhow::Result<String> {
        let node_id = parse_hex32(&host_node_id_hex)?;
        let (id, addr) = Client::addr_from_node_id(node_id)?;
        let host = self.inner.pair(&code, id, addr, fcm).await?;
        Ok(hex(host))
    }

    /// Connect to a host and return a session. Call [`RustSession::events`] to
    /// start the inbound stream; send back via the session's other methods.
    pub async fn connect(&self, host_node_id_hex: String) -> anyhow::Result<RustSession> {
        let node_id = parse_hex32(&host_node_id_hex)?;
        let (_id, addr) = Client::addr_from_node_id(node_id)?;
        let (sender, receiver) = self.inner.connect_split(addr).await?;
        Ok(RustSession {
            sender: Mutex::new(sender),
            receiver: Mutex::new(Some(receiver)),
        })
    }
}

/// A live connection. Opaque; the receive loop and outbound sends use separate
/// stream halves, so a half-read frame is never cancelled by a send.
#[frb(opaque)]
pub struct RustSession {
    sender: Mutex<PhoneSender>,
    receiver: Mutex<Option<PhoneReceiver>>,
}

impl RustSession {
    /// Stream inbound host events until the connection drops. Callable once; the
    /// returned future runs the receive loop, so frb turns this into a Dart
    /// `Stream<HostEventDto>`.
    pub async fn events(&self, sink: StreamSink<HostEventDto>) -> anyhow::Result<()> {
        let mut receiver = self
            .receiver
            .lock()
            .await
            .take()
            .ok_or_else(|| anyhow::anyhow!("events() already started"))?;
        loop {
            match receiver.next_msg().await {
                Ok(m) => {
                    if sink.add(map_event(m)).is_err() {
                        break;
                    }
                }
                Err(_) => {
                    let _ = sink.add(HostEventDto::Disconnected);
                    break;
                }
            }
        }
        Ok(())
    }

    pub async fn hello(
        &self,
        fcm: Option<String>,
        high_water: Vec<HighWaterDto>,
    ) -> anyhow::Result<()> {
        let map = high_water
            .into_iter()
            .map(|h| (h.session, h.last_seq))
            .collect();
        self.sender.lock().await.hello(fcm, map).await
    }

    pub async fn input(&self, session: String, text: String) -> anyhow::Result<()> {
        self.sender.lock().await.input(&session, &text).await
    }

    pub async fn answer_permission(
        &self,
        session: String,
        id: String,
        option: String,
    ) -> anyhow::Result<()> {
        self.sender
            .lock()
            .await
            .permission(&session, &id, &option)
            .await
    }

    pub async fn interrupt(&self, session: String) -> anyhow::Result<()> {
        self.sender.lock().await.interrupt(&session).await
    }

    /// Send a slash command (e.g. `/model`, `/mode`, `/thought`, `/compact`) to
    /// the host. `arg` is the value for setters like `/model <id>`.
    pub async fn command(
        &self,
        session: String,
        name: String,
        arg: Option<String>,
    ) -> anyhow::Result<()> {
        self.sender.lock().await.command(&session, &name, arg).await
    }

    /// Browse the HOST filesystem. `path` None starts at home. The reply arrives
    /// on the event stream as `HostEventDto::FsEntries` (or `FsError`), matched
    /// by `req`.
    pub async fn fs_list(&self, req: u64, path: Option<String>) -> anyhow::Result<()> {
        self.sender.lock().await.fs_list(req, path).await
    }

    /// Begin a chunked attachment upload. Bytes follow via [`upload_chunk`];
    /// [`upload_finish`] seals it and the landed path returns as
    /// `HostEventDto::UploadDone`. Streaming keeps every frame small and the
    /// phone's working set to one chunk.
    pub async fn upload_start(&self, req: u64, name: String) -> anyhow::Result<()> {
        self.sender.lock().await.upload_start(req, &name).await
    }

    /// Send one raw byte slice of the upload under `req` (Dart passes a
    /// `Uint8List`; no base64 on the wire).
    pub async fn upload_chunk(&self, req: u64, data: Vec<u8>) -> anyhow::Result<()> {
        self.sender.lock().await.upload_chunk(req, &data).await
    }

    /// Seal the upload under `req`; the host replies `UploadDone` with the path.
    pub async fn upload_finish(&self, req: u64) -> anyhow::Result<()> {
        self.sender.lock().await.upload_finish(req).await
    }

    /// Start a brand-new session on the host from `prompt` (its first message
    /// and title). `cwd` is an optional host directory (pick one via `fs_list`).
    /// The new session mirrors back through the event stream — a fresh
    /// `Sessions` list with an added open entry, then its updates.
    pub async fn new_session(&self, req: u64, prompt: String, cwd: Option<String>) -> anyhow::Result<()> {
        self.sender.lock().await.new_session(req, &prompt, cwd).await
    }

    /// Reopen a closed session (one with `SessionMetaDto::open == false`) by id.
    /// It resumes on the host and mirrors back like any live session.
    pub async fn open_session(&self, session: String) -> anyhow::Result<()> {
        self.sender.lock().await.open_session(&session).await
    }
}

/// A per-session catch-up high-water mark passed to `hello`.
pub struct HighWaterDto {
    pub session: String,
    pub last_seq: u64,
}

/// An event from the host, flattened for Dart.
pub enum HostEventDto {
    Sessions(Vec<SessionMetaDto>),
    Update(UpdateDto),
    Status { session: String, running: bool },
    Permission(PermissionReqDto),
    PermissionResolved { session: String, id: String },
    Config { session: String, config: SessionConfigDto },
    /// Reply to `fs_list`, matched by `req`.
    FsEntries {
        req: u64,
        dir: String,
        parent: Option<String>,
        entries: Vec<FsEntryDto>,
    },
    /// Reply to `upload`, matched by `req`: the attachment's host path.
    UploadDone { req: u64, path: String },
    /// A browse or upload failed, matched by `req`.
    FsError { req: u64, message: String },
    Disconnected,
}

pub struct FsEntryDto {
    pub name: String,
    pub path: String,
    pub is_dir: bool,
}

/// A session's backend knobs, flattened for Dart.
pub struct SessionConfigDto {
    pub models: Vec<ConfigOptionDto>,
    pub current_model: Option<String>,
    pub modes: Vec<ConfigOptionDto>,
    pub current_mode: Option<String>,
    pub thought_levels: Vec<ConfigOptionDto>,
    pub current_thought: Option<String>,
    pub commands: Vec<CommandInfoDto>,
}

pub struct ConfigOptionDto {
    pub id: String,
    pub name: String,
    pub description: Option<String>,
}

pub struct CommandInfoDto {
    pub name: String,
    pub description: Option<String>,
}

pub struct SessionMetaDto {
    pub id: String,
    pub title: String,
    pub running: bool,
    pub last_seq: u64,
    /// True for a live/mirrored session; false for a closed one the host still
    /// has a log for — the phone lists these as resumable via `open_session`.
    pub open: bool,
}

pub struct UpdateDto {
    pub session: String,
    pub seq: u64,
    pub turn: u64,
    pub payload: PayloadDto,
}

pub enum PayloadDto {
    AgentMessage {
        text: String,
    },
    Thought {
        text: String,
    },
    UserMessage {
        text: String,
    },
    ToolCall {
        id: String,
        kind: String,
        title: String,
        command: Option<String>,
        status: String,
        content: Vec<ContentDto>,
        locations: Vec<String>,
    },
    ToolCallUpdate {
        id: String,
        status: String,
        content: Vec<ContentDto>,
    },
    Plan {
        entries: Vec<PlanEntryDto>,
    },
    Usage {
        input: u64,
        output: u64,
    },
}

pub struct PlanEntryDto {
    pub content: String,
    /// `"pending"` | `"in_progress"` | `"completed"`.
    pub status: String,
}

/// One content block: `kind` is `"text"`/`"diff"`/`"file_ref"` and only the
/// matching fields are set.
pub struct ContentDto {
    pub kind: String,
    pub text: Option<String>,
    pub path: Option<String>,
    pub diff: Option<String>,
}

pub struct PermissionReqDto {
    pub session: String,
    pub id: String,
    pub command: String,
    pub options: Vec<PermOptionDto>,
}

pub struct PermOptionDto {
    pub id: String,
    pub label: String,
}

fn map_event(m: WireMsg) -> HostEventDto {
    match m {
        WireMsg::SessionList { sessions } => {
            HostEventDto::Sessions(sessions.into_iter().map(map_meta).collect())
        }
        WireMsg::Update(u) => HostEventDto::Update(map_update(u)),
        WireMsg::Status { session, state } => HostEventDto::Status {
            session,
            running: matches!(state, asb_protocol::model::SessionState::Running),
        },
        WireMsg::PermissionReq {
            session,
            id,
            command,
            options,
        } => HostEventDto::Permission(PermissionReqDto {
            session,
            id,
            command,
            options: options
                .into_iter()
                .map(|o| PermOptionDto {
                    id: o.id,
                    label: o.label,
                })
                .collect(),
        }),
        WireMsg::PermissionResolved { session, id } => {
            HostEventDto::PermissionResolved { session, id }
        }
        WireMsg::Config { session, config } => HostEventDto::Config {
            session,
            config: map_config(config),
        },
        WireMsg::FsEntries { req, dir, parent, entries } => HostEventDto::FsEntries {
            req,
            dir,
            parent,
            entries: entries
                .into_iter()
                .map(|e| FsEntryDto {
                    name: e.name,
                    path: e.path,
                    is_dir: e.is_dir,
                })
                .collect(),
        },
        WireMsg::UploadDone { req, path } => HostEventDto::UploadDone { req, path },
        WireMsg::FsError { req, message } => HostEventDto::FsError { req, message },
        // phone -> host variants never arrive here.
        _ => HostEventDto::Disconnected,
    }
}

fn map_config(c: SessionConfig) -> SessionConfigDto {
    let opt = |o: ConfigOption| ConfigOptionDto {
        id: o.id,
        name: o.name,
        description: o.description,
    };
    SessionConfigDto {
        models: c.models.into_iter().map(opt).collect(),
        current_model: c.current_model,
        modes: c.modes.into_iter().map(opt).collect(),
        current_mode: c.current_mode,
        thought_levels: c.thought_levels.into_iter().map(opt).collect(),
        current_thought: c.current_thought,
        commands: c
            .commands
            .into_iter()
            .map(|c: CommandInfo| CommandInfoDto {
                name: c.name,
                description: c.description,
            })
            .collect(),
    }
}

fn map_meta(m: SessionMeta) -> SessionMetaDto {
    SessionMetaDto {
        id: m.id,
        title: m.title,
        running: matches!(m.state, asb_protocol::model::SessionState::Running),
        last_seq: m.last_seq,
        open: m.open,
    }
}

fn map_update(u: Update) -> UpdateDto {
    UpdateDto {
        session: u.session,
        seq: u.seq,
        turn: u.turn,
        payload: map_payload(u.payload),
    }
}

fn map_payload(p: Payload) -> PayloadDto {
    use asb_protocol::model::{ToolKind, ToolStatus};
    let kind_str = |k: ToolKind| {
        match k {
            ToolKind::Read => "read",
            ToolKind::Edit => "edit",
            ToolKind::Command => "command",
            ToolKind::Search => "search",
            ToolKind::Fetch => "fetch",
            ToolKind::Other => "other",
        }
        .to_string()
    };
    let status_str = |s: ToolStatus| {
        match s {
            ToolStatus::Pending => "pending",
            ToolStatus::Running => "running",
            ToolStatus::Done => "done",
            ToolStatus::Failed => "failed",
        }
        .to_string()
    };
    match p {
        Payload::AgentMessage { text } => PayloadDto::AgentMessage { text },
        Payload::Thought { text } => PayloadDto::Thought { text },
        Payload::UserMessage { text } => PayloadDto::UserMessage { text },
        Payload::ToolCall(tc) => PayloadDto::ToolCall {
            id: tc.id,
            kind: kind_str(tc.kind),
            title: tc.title,
            command: tc.command,
            status: status_str(tc.status),
            content: tc.content.into_iter().map(map_content).collect(),
            locations: tc.locations,
        },
        Payload::ToolCallUpdate {
            id,
            status,
            content,
        } => PayloadDto::ToolCallUpdate {
            id,
            status: status_str(status),
            content: content.into_iter().map(map_content).collect(),
        },
        Payload::Plan { entries } => PayloadDto::Plan {
            entries: entries.into_iter().map(map_plan_entry).collect(),
        },
        Payload::Usage { input, output } => PayloadDto::Usage { input, output },
    }
}

fn map_plan_entry(e: PlanEntry) -> PlanEntryDto {
    PlanEntryDto {
        content: e.content,
        status: match e.status {
            PlanStatus::Pending => "pending",
            PlanStatus::InProgress => "in_progress",
            PlanStatus::Completed => "completed",
        }
        .to_string(),
    }
}

fn map_content(c: Content) -> ContentDto {
    match c {
        Content::Text { text } => ContentDto {
            kind: "text".into(),
            text: Some(text),
            path: None,
            diff: None,
        },
        Content::Diff { path, diff } => ContentDto {
            kind: "diff".into(),
            text: None,
            path: Some(path),
            diff: Some(diff),
        },
        Content::FileRef { path } => ContentDto {
            kind: "file_ref".into(),
            text: None,
            path: Some(path),
            diff: None,
        },
    }
}

fn hex(bytes: [u8; 32]) -> String {
    bytes.iter().map(|b| format!("{b:02x}")).collect()
}

fn parse_hex32(s: &str) -> anyhow::Result<[u8; 32]> {
    let s = s.trim();
    anyhow::ensure!(s.len() == 64, "expected a 64-char hex node id, got {}", s.len());
    let mut out = [0u8; 32];
    for (i, b) in out.iter_mut().enumerate() {
        *b = u8::from_str_radix(&s[i * 2..i * 2 + 2], 16)?;
    }
    Ok(out)
}
