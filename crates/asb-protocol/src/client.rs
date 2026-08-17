//! The phone-side session client, reused by the sidecar's tests and (later) by
//! the Flutter Rust core via flutter_rust_bridge.

use std::collections::HashMap;
use std::time::Duration;

use iroh::endpoint::{Connection, RecvStream, SendStream};
use iroh::{Endpoint, EndpointAddr};

use crate::model::{Seq, SessionId, Update};
use crate::net::{recv_frame, send_frame, ASB_ALPN};
use crate::wire::WireMsg;

pub struct PhoneClient {
    _conn: Connection,
    send: SendStream,
    recv: RecvStream,
}

impl PhoneClient {
    pub async fn connect(ep: &Endpoint, host: EndpointAddr) -> anyhow::Result<Self> {
        let conn = ep.connect(host, ASB_ALPN).await?;
        let (send, recv) = conn.open_bi().await?;
        Ok(Self {
            _conn: conn,
            send,
            recv,
        })
    }

    async fn send_msg(&mut self, m: &WireMsg) -> anyhow::Result<()> {
        let mut buf = Vec::new();
        ciborium::into_writer(m, &mut buf)?;
        send_frame(&mut self.send, &buf).await
    }

    pub async fn next_msg(&mut self) -> anyhow::Result<WireMsg> {
        let body = recv_frame(&mut self.recv).await?;
        Ok(ciborium::from_reader(&body[..])?)
    }

    pub async fn hello(
        &mut self,
        fcm_token: Option<String>,
        last_seq: HashMap<SessionId, Seq>,
    ) -> anyhow::Result<()> {
        self.send_msg(&WireMsg::Hello {
            fcm_token,
            last_seq,
        })
        .await
    }

    pub async fn catchup(&mut self, session: &str, since: Seq) -> anyhow::Result<()> {
        self.send_msg(&WireMsg::Catchup {
            session: session.into(),
            since,
        })
        .await
    }

    pub async fn input(&mut self, session: &str, text: &str) -> anyhow::Result<()> {
        self.send_msg(&WireMsg::Input {
            session: session.into(),
            text: text.into(),
        })
        .await
    }

    pub async fn permission(&mut self, session: &str, id: &str, option: &str) -> anyhow::Result<()> {
        self.send_msg(&WireMsg::PermissionRes {
            session: session.into(),
            id: id.into(),
            option: option.into(),
        })
        .await
    }

    pub async fn interrupt(&mut self, session: &str) -> anyhow::Result<()> {
        self.send_msg(&WireMsg::Interrupt {
            session: session.into(),
        })
        .await
    }

    /// Read messages until the next `Update` arrives or `d` elapses.
    pub async fn next_update_timeout(&mut self, d: Duration) -> anyhow::Result<Update> {
        let deadline = tokio::time::Instant::now() + d;
        loop {
            let remaining = deadline.saturating_duration_since(tokio::time::Instant::now());
            anyhow::ensure!(!remaining.is_zero(), "timed out waiting for an update");
            let m = tokio::time::timeout(remaining, self.next_msg())
                .await
                .map_err(|_| anyhow::anyhow!("timed out waiting for an update"))??;
            if let WireMsg::Update(u) = m {
                return Ok(u);
            }
        }
    }
}
