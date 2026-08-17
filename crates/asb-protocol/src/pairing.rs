//! PAKE-over-iroh pairing. The joiner (phone) is the SPAKE2 initiator and dials;
//! the host (sidecar) is the responder and accepts. After the handshake both
//! sides exchange their node ids (and the phone's FCM token) under the
//! PAKE-derived channel, yielding a [`RosterEntry`] for each side.

use std::time::Duration;

use anyhow::Context;
use iroh::{Endpoint, EndpointAddr, EndpointId};
use roam_pake::{Initiator, PairingCode, Responder, Side};
use serde::{Deserialize, Serialize};

use crate::identity::Identity;
use crate::net::{recv_frame, send_frame, PAIR_ALPN};
use crate::roster::{PeerKind, RosterEntry};

const HS_TIMEOUT: Duration = Duration::from_secs(20);

#[derive(Serialize, Deserialize)]
struct JoinInfo {
    node_id: [u8; 32],
    fcm_token: Option<String>,
}

#[derive(Serialize, Deserialize)]
struct HostInfo {
    node_id: [u8; 32],
}

async fn recv_frame_to(recv: &mut iroh::endpoint::RecvStream) -> anyhow::Result<Vec<u8>> {
    tokio::time::timeout(HS_TIMEOUT, recv_frame(recv))
        .await
        .context("pairing read timed out")?
}

fn confirm32(v: Vec<u8>) -> anyhow::Result<[u8; 32]> {
    v.try_into()
        .map_err(|_| anyhow::anyhow!("malformed 32-byte confirmation"))
}

/// Joiner side (phone): dial the host, run the PAKE as initiator, send our
/// identity + fcm token, learn the host's node id. Returns the host roster entry.
pub async fn pair_join(
    ep: &Endpoint,
    host_id: EndpointId,
    host_addr: EndpointAddr,
    code: PairingCode,
    me: &Identity,
    fcm: Option<String>,
) -> anyhow::Result<RosterEntry> {
    let conn = ep
        .connect(host_addr, PAIR_ALPN)
        .await
        .context("dial host pairing endpoint")?;
    let (mut send, mut recv) = conn.open_bi().await.context("open pairing bi stream")?;

    let (init, msg1) = Initiator::start(&code, *ep.id().as_bytes(), *host_id.as_bytes());
    send_frame(&mut send, &msg1).await?;
    let msg2 = recv_frame_to(&mut recv).await?;
    let (pending, my_confirm) = init.accept(&msg2).map_err(anyhow::Error::from)?;
    send_frame(&mut send, &my_confirm).await?;
    let their_confirm = confirm32(recv_frame_to(&mut recv).await?)?;
    let key = pending.verify(&their_confirm).map_err(anyhow::Error::from)?;

    let (mut sealer, mut opener) = key.split(Side::Initiator);
    let join = JoinInfo {
        node_id: me.node_id_bytes(),
        fcm_token: fcm,
    };
    send_frame(&mut send, &sealer.seal(&serde_json::to_vec(&join)?)).await?;
    let host_info: HostInfo =
        serde_json::from_slice(&opener.open(&recv_frame_to(&mut recv).await?)?)?;

    conn.close(0u32.into(), b"paired");
    Ok(RosterEntry {
        node_id: host_info.node_id,
        kind: PeerKind::Host,
        fcm_token: None,
        added_at: 0,
    })
}

/// Host side (sidecar): accept the next pairing connection, run the PAKE as
/// responder, learn the joiner's identity, reveal ours. Returns the client entry.
pub async fn pair_host(
    ep: &Endpoint,
    code: &PairingCode,
    me: &Identity,
) -> anyhow::Result<RosterEntry> {
    loop {
        let incoming = ep
            .accept()
            .await
            .ok_or_else(|| anyhow::anyhow!("pairing endpoint closed"))?;
        let conn = match incoming.accept() {
            Ok(connecting) => connecting.await.context("accept pairing connection")?,
            Err(_) => continue,
        };
        if conn.alpn() != PAIR_ALPN {
            conn.close(0u32.into(), b"not pairing");
            continue;
        }
        let joiner = conn.remote_id();
        let (mut send, mut recv) = tokio::time::timeout(HS_TIMEOUT, conn.accept_bi())
            .await
            .context("peer never opened a pairing stream")?
            .context("accept pairing bi stream")?;

        let mut responder = Responder::new(code.clone(), me.node_id_bytes());
        let msg1 = recv_frame_to(&mut recv).await?;
        let (pending, msg2) = responder
            .respond(*joiner.as_bytes(), &msg1)
            .map_err(anyhow::Error::from)?;
        send_frame(&mut send, &msg2).await?;
        let their_confirm = confirm32(recv_frame_to(&mut recv).await?)?;
        let (key, my_confirm) = responder
            .verify(pending, &their_confirm)
            .map_err(anyhow::Error::from)?;
        send_frame(&mut send, &my_confirm).await?;

        let (mut sealer, mut opener) = key.split(Side::Responder);
        let join: JoinInfo = serde_json::from_slice(&opener.open(&recv_frame_to(&mut recv).await?)?)?;
        anyhow::ensure!(
            join.node_id == *joiner.as_bytes(),
            "pairing identity mismatch: PAKE id != QUIC id"
        );
        let host_info = HostInfo {
            node_id: me.node_id_bytes(),
        };
        send_frame(&mut send, &sealer.seal(&serde_json::to_vec(&host_info)?)).await?;
        conn.closed().await;

        return Ok(RosterEntry {
            node_id: join.node_id,
            kind: PeerKind::Client,
            fcm_token: join.fcm_token,
            added_at: 0,
        });
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::net::{build_endpoint_minimal, ready_addr};

    async fn ep_for(name: &str, dir: &std::path::Path) -> (Identity, Endpoint) {
        let id = Identity::load_or_create(&dir.join(format!("{name}.json"))).unwrap();
        let ep = build_endpoint_minimal(id.secret_bytes()).await.unwrap();
        (id, ep)
    }

    #[tokio::test]
    async fn pake_pairing_loopback_ok() {
        let dir = tempfile::tempdir().unwrap();
        let (host_id, host_ep) = ep_for("host", dir.path()).await;
        let (join_id, join_ep) = ep_for("join", dir.path()).await;
        let host_node = host_ep.id();
        let host_addr = ready_addr(&host_ep).await;
        let host_node_bytes = host_id.node_id_bytes();

        let code = PairingCode::generate();
        let code_str = code.as_str().to_string();

        let host_task = {
            let host_ep = host_ep.clone();
            tokio::spawn(async move { pair_host(&host_ep, &code, &host_id).await })
        };

        let joined = pair_join(
            &join_ep,
            host_node,
            host_addr,
            PairingCode::parse(&code_str).unwrap(),
            &join_id,
            Some("fcmtok".into()),
        )
        .await
        .unwrap();

        let host_side = host_task.await.unwrap().unwrap();
        assert_eq!(host_side.node_id, join_id.node_id_bytes());
        assert_eq!(host_side.fcm_token.as_deref(), Some("fcmtok"));
        assert_eq!(host_side.kind, PeerKind::Client);
        assert_eq!(joined.node_id, host_node_bytes);
        assert_eq!(joined.kind, PeerKind::Host);

        host_ep.close().await;
        join_ep.close().await;
    }

    #[tokio::test]
    async fn pake_pairing_wrong_code_fails() {
        let dir = tempfile::tempdir().unwrap();
        let (host_id, host_ep) = ep_for("host", dir.path()).await;
        let (join_id, join_ep) = ep_for("join", dir.path()).await;
        let host_node = host_ep.id();
        let host_addr = ready_addr(&host_ep).await;

        let good = PairingCode::generate();
        let host_task = {
            let host_ep = host_ep.clone();
            tokio::spawn(async move { pair_host(&host_ep, &good, &host_id).await })
        };

        // Join with a fresh random code (≠ `good` with prob 1 - 10⁻⁶).
        let res = pair_join(&join_ep, host_node, host_addr, PairingCode::generate(), &join_id, None)
            .await;
        assert!(res.is_err(), "wrong code must not pair");

        host_task.abort();
        host_ep.close().await;
        join_ep.close().await;
    }
}
