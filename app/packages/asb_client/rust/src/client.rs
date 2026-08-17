//! The phone-side client, shaped for the Dart UI but written as plain Rust.
//!
//! No `flutter_rust_bridge` attributes, ordinary `anyhow::Result`, no generated
//! types. This is the layer that can be wrong, so host `cargo test` exercises
//! it against a real `asb-sidecar` over a loopback iroh endpoint. `api::client`
//! adds the bridge shim and nothing else.

use std::collections::HashMap;
use std::path::{Path, PathBuf};
use std::time::Duration;

use asb_protocol::client::{PhoneClient, PhoneReceiver, PhoneSender};
use asb_protocol::identity::Identity;
use asb_protocol::model::Seq;
use asb_protocol::net::{build_endpoint, build_endpoint_minimal};
use asb_protocol::pairing::pair_join;
use asb_protocol::roam_pake::PairingCode;
use asb_protocol::roster::{PeerKind, Roster};
use asb_protocol::wire::WireMsg;
use iroh::{Endpoint, EndpointAddr, EndpointId};

/// A phone client: one iroh endpoint on this device's identity, plus the roster
/// of hosts it has paired with.
pub struct Client {
    dir: PathBuf,
    identity: Identity,
    endpoint: Endpoint,
}

impl Client {
    /// Open (or create) the client rooted at `dir` (an app-private directory),
    /// reachable over the internet via iroh relays + discovery.
    pub async fn open(dir: &Path) -> anyhow::Result<Self> {
        Self::build(dir, false).await
    }

    /// Like [`Client::open`] but on a minimal endpoint (no relays/discovery) —
    /// for LAN use and host tests.
    pub async fn open_local(dir: &Path) -> anyhow::Result<Self> {
        Self::build(dir, true).await
    }

    async fn build(dir: &Path, local: bool) -> anyhow::Result<Self> {
        std::fs::create_dir_all(dir)?;
        let identity = Identity::load_or_create(&dir.join("identity.json"))?;
        let endpoint = if local {
            build_endpoint_minimal(identity.secret_bytes()).await?
        } else {
            build_endpoint(identity.secret_bytes()).await?
        };
        Ok(Self {
            dir: dir.into(),
            identity,
            endpoint,
        })
    }

    /// This device's node id (ed25519 verifying key).
    pub fn node_id(&self) -> [u8; 32] {
        self.identity.node_id_bytes()
    }

    fn roster_path(&self) -> PathBuf {
        self.dir.join("hosts.json")
    }

    /// The hosts this client has paired with (node ids).
    pub fn hosts(&self) -> anyhow::Result<Vec<[u8; 32]>> {
        let roster = Roster::load(&self.roster_path())?;
        Ok(roster
            .entries()
            .iter()
            .filter(|e| e.kind == PeerKind::Host)
            .map(|e| e.node_id)
            .collect())
    }

    /// Run the PAKE pairing against `host_addr` using `code`, persist the host,
    /// and return its node id.
    pub async fn pair(
        &self,
        code: &str,
        host_id: EndpointId,
        host_addr: EndpointAddr,
        fcm: Option<String>,
    ) -> anyhow::Result<[u8; 32]> {
        let code = PairingCode::parse(code)?;
        let entry = pair_join(&self.endpoint, host_id, host_addr, code, &self.identity, fcm).await?;
        let node_id = entry.node_id;
        let mut roster = Roster::load(&self.roster_path())?;
        roster.add(entry)?;
        Ok(node_id)
    }

    /// Connect to a paired host and return a live session (sequential use).
    pub async fn connect(&self, host_addr: EndpointAddr) -> anyhow::Result<Session> {
        let inner = PhoneClient::connect(&self.endpoint, host_addr).await?;
        Ok(Session { inner })
    }

    /// Connect and split into send/receive halves, for the streaming api where a
    /// receive loop and outbound sends run concurrently.
    pub async fn connect_split(
        &self,
        host_addr: EndpointAddr,
    ) -> anyhow::Result<(PhoneSender, PhoneReceiver)> {
        let inner = PhoneClient::connect(&self.endpoint, host_addr).await?;
        Ok(inner.split())
    }

    /// Build an [`EndpointAddr`] dialable over relays/discovery from a node id.
    pub fn addr_from_node_id(node_id: [u8; 32]) -> anyhow::Result<(EndpointId, EndpointAddr)> {
        let id = EndpointId::from_bytes(&node_id)?;
        Ok((id, EndpointAddr::from(id)))
    }
}

/// A live connection to one host. Wraps [`PhoneClient`]; the api layer holds
/// this behind a mutex so Dart can drive it from multiple call sites.
pub struct Session {
    inner: PhoneClient,
}

impl Session {
    /// Greet the host with this client's push token and per-session catch-up
    /// high-water marks.
    pub async fn hello(
        &mut self,
        fcm: Option<String>,
        last_seq: HashMap<String, Seq>,
    ) -> anyhow::Result<()> {
        self.inner.hello(fcm, last_seq).await
    }

    /// Await the next message from the host (session list, update, status,
    /// permission request).
    pub async fn next(&mut self) -> anyhow::Result<WireMsg> {
        self.inner.next_msg().await
    }

    /// Await the next message, timing out after `d`.
    pub async fn next_timeout(&mut self, d: Duration) -> anyhow::Result<WireMsg> {
        tokio::time::timeout(d, self.inner.next_msg())
            .await
            .map_err(|_| anyhow::anyhow!("timed out waiting for host"))?
    }

    pub async fn input(&mut self, session: &str, text: &str) -> anyhow::Result<()> {
        self.inner.input(session, text).await
    }

    pub async fn permission(&mut self, session: &str, id: &str, option: &str) -> anyhow::Result<()> {
        self.inner.permission(session, id, option).await
    }

    pub async fn interrupt(&mut self, session: &str) -> anyhow::Result<()> {
        self.inner.interrupt(session).await
    }
}
