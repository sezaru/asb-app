use anyhow::Context;
use iroh::endpoint::presets;
use iroh::endpoint::{RecvStream, SendStream};
use iroh::{Endpoint, SecretKey};
use iroh_mdns_address_lookup::MdnsAddressLookup;
use tokio::io::{AsyncRead, AsyncReadExt, AsyncWrite, AsyncWriteExt};

/// Steady-state ALPN: a rostered phone streams session updates + drives input.
pub const ASB_ALPN: &[u8] = b"asb/1";
/// One-shot PAKE pairing ALPN.
pub const PAIR_ALPN: &[u8] = b"asb-pair/1";

pub const MAX_FRAME: usize = 8 * 1024 * 1024;

/// The one iroh endpoint for this device, bound to `secret_32` (so the NodeId
/// equals the ed25519 verifying key), serving both the steady-state and pairing
/// ALPNs. N0 discovery (pkarr/DNS/relay) handles the public-internet path;
/// mDNS address lookup advertises this device's LAN addresses so two peers on
/// the same network hole-punch a direct link instead of relaying everything
/// (same-NAT peers can't hairpin their public reflexive address).
pub async fn build_endpoint(secret_32: [u8; 32]) -> anyhow::Result<Endpoint> {
    let secret = SecretKey::from_bytes(&secret_32);
    let endpoint = Endpoint::builder(presets::N0)
        .secret_key(secret)
        .alpns(vec![ASB_ALPN.to_vec(), PAIR_ALPN.to_vec()])
        .bind()
        .await?;
    // mDNS is best-effort and added AFTER bind on purpose: on Android the
    // multicast socket can fail to bind (needs a WifiManager.MulticastLock), and
    // if that were passed into `.bind()` iroh's `into_address_lookup(&ep)?` would
    // sink the ENTIRE endpoint — no iroh at all. Post-bind, a failure just drops
    // the LAN direct-path optimization; the relay/pkarr path stays intact.
    match MdnsAddressLookup::builder().build(endpoint.id()) {
        Ok(mdns) => {
            if let Ok(lookup) = endpoint.address_lookup() {
                lookup.add(mdns);
            }
        }
        Err(e) => tracing::warn!("mDNS local discovery unavailable: {e:#}"),
    }
    Ok(endpoint)
}

/// A `Minimal`-preset endpoint (no pkarr/DNS/relay): reachable only via a
/// directly-supplied address. Used by loopback tests and future LAN-only paths.
pub async fn build_endpoint_minimal(secret_32: [u8; 32]) -> anyhow::Result<Endpoint> {
    let secret = SecretKey::from_bytes(&secret_32);
    let endpoint = Endpoint::builder(presets::Minimal)
        .secret_key(secret)
        .alpns(vec![ASB_ALPN.to_vec(), PAIR_ALPN.to_vec()])
        .bind()
        .await?;
    Ok(endpoint)
}

/// Snapshot a dialable address, waiting (bounded) for a direct one to appear.
pub async fn ready_addr(endpoint: &Endpoint) -> iroh::EndpointAddr {
    let deadline = tokio::time::Instant::now() + std::time::Duration::from_secs(5);
    while tokio::time::Instant::now() < deadline {
        if endpoint.addr().ip_addrs().next().is_some() {
            break;
        }
        tokio::time::sleep(std::time::Duration::from_millis(50)).await;
    }
    endpoint.addr()
}

/// 4-byte big-endian length prefix + body.
pub async fn write_frame<W: AsyncWrite + Unpin>(w: &mut W, body: &[u8]) -> anyhow::Result<()> {
    anyhow::ensure!(body.len() <= MAX_FRAME, "frame too large: {}", body.len());
    w.write_all(&(body.len() as u32).to_be_bytes()).await?;
    w.write_all(body).await?;
    w.flush().await?;
    Ok(())
}

pub async fn read_frame<R: AsyncRead + Unpin>(r: &mut R) -> anyhow::Result<Vec<u8>> {
    let mut len = [0u8; 4];
    r.read_exact(&mut len).await?;
    let n = u32::from_be_bytes(len) as usize;
    anyhow::ensure!(n <= MAX_FRAME, "frame too large: {n}");
    let mut body = vec![0u8; n];
    r.read_exact(&mut body).await?;
    Ok(body)
}

/// Same 4-byte-BE framing, over an iroh (quinn) bidirectional stream. iroh
/// streams expose inherent `write_all`/`read_exact`, not the tokio traits, so
/// these can't share the generic helpers above.
pub async fn send_frame(send: &mut SendStream, body: &[u8]) -> anyhow::Result<()> {
    anyhow::ensure!(body.len() <= MAX_FRAME, "frame too large: {}", body.len());
    send.write_all(&(body.len() as u32).to_be_bytes())
        .await
        .context("write frame len")?;
    send.write_all(body).await.context("write frame body")?;
    Ok(())
}

pub async fn recv_frame(recv: &mut RecvStream) -> anyhow::Result<Vec<u8>> {
    let mut len = [0u8; 4];
    recv.read_exact(&mut len).await.context("read frame len")?;
    let n = u32::from_be_bytes(len) as usize;
    anyhow::ensure!(n <= MAX_FRAME, "frame too large: {n}");
    let mut body = vec![0u8; n];
    recv.read_exact(&mut body).await.context("read frame body")?;
    Ok(body)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn frame_roundtrips_over_duplex() {
        let (mut a, mut b) = tokio::io::duplex(1024);
        let payload = b"hello frame".to_vec();
        let p2 = payload.clone();
        let h = tokio::spawn(async move {
            write_frame(&mut a, &p2).await.unwrap();
        });
        let got = read_frame(&mut b).await.unwrap();
        h.await.unwrap();
        assert_eq!(got, payload);
    }

    #[tokio::test]
    async fn multiple_frames_stay_ordered() {
        let (mut a, mut b) = tokio::io::duplex(4096);
        let h = tokio::spawn(async move {
            for i in 0u8..5 {
                write_frame(&mut a, &[i; 3]).await.unwrap();
            }
        });
        for i in 0u8..5 {
            assert_eq!(read_frame(&mut b).await.unwrap(), vec![i; 3]);
        }
        h.await.unwrap();
    }
}
