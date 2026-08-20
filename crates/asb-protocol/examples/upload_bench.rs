//! Isolates the asb upload path (iroh QUIC + chunked raw-byte protocol) between
//! two hosts on a LAN — no phone, no wifi confounders. Uses the REAL PhoneClient
//! upload_* methods and the same WireMsg framing the sidecar uses.
//!
//!   server: prints ADDR=<json>, then receives one upload and reports MB/s
//!   client <ADDR-json> [total_mib]: uploads total_mib (default 512) in 4MiB
//!           raw chunks and reports MB/s
use std::time::Instant;

use asb_protocol::client::PhoneClient;
use asb_protocol::net::{build_endpoint, build_endpoint_minimal, ready_addr, recv_frame, send_frame};
use asb_protocol::wire::WireMsg;
use iroh::Endpoint;

const CHUNK: usize = 4 << 20;

/// ASB_FULL=1 -> full endpoint (relay + mDNS + hole-punching, traverses
/// firewalls between hosts); else minimal (direct addr only, loopback/open-port).
async fn mk_ep(secret: [u8; 32]) -> anyhow::Result<Endpoint> {
    if std::env::var_os("ASB_FULL").is_some() {
        build_endpoint(secret).await
    } else {
        build_endpoint_minimal(secret).await
    }
}

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    let args: Vec<String> = std::env::args().collect();
    match args.get(1).map(String::as_str) {
        Some("server") => server().await,
        Some("client") => {
            let addr_json = args.get(2).expect("need ADDR json");
            let total_mib: usize = args.get(3).and_then(|s| s.parse().ok()).unwrap_or(512);
            client(addr_json, total_mib).await
        }
        _ => {
            eprintln!("usage: upload_bench server | client <ADDR-json> [total_mib]");
            Ok(())
        }
    }
}

async fn server() -> anyhow::Result<()> {
    let ep = mk_ep([9u8; 32]).await?;
    let addr = ready_addr(&ep).await;
    println!("ADDR={}", serde_json::to_string(&addr)?);
    println!("(waiting for client...)");

    let incoming = ep.accept().await.ok_or_else(|| anyhow::anyhow!("no incoming"))?;
    let conn = incoming.accept()?.await?;
    let (mut send, mut recv) = conn.accept_bi().await?;

    let mut total = 0usize;
    let mut start: Option<Instant> = None;
    loop {
        let body = recv_frame(&mut recv).await?;
        let msg: WireMsg = ciborium::from_reader(&body[..])?;
        match msg {
            WireMsg::UploadStart { .. } => {}
            WireMsg::UploadChunk { data, .. } => {
                if start.is_none() {
                    start = Some(Instant::now());
                }
                total += data.len();
            }
            WireMsg::UploadFinish { req } => {
                let el = start.map(|s| s.elapsed().as_secs_f64()).unwrap_or(0.0);
                let mb = total as f64 / 1_048_576.0;
                println!(
                    "SERVER received {:.0} MB in {:.2}s = {:.1} MB/s ({:.0} Mbps)",
                    mb,
                    el,
                    mb / el,
                    mb * 8.0 / el
                );
                let mut buf = Vec::new();
                ciborium::into_writer(
                    &WireMsg::UploadDone { req, path: "/tmp/bench".into() },
                    &mut buf,
                )?;
                send_frame(&mut send, &buf).await?;
                // Let the client read UploadDone before we drop the connection.
                tokio::time::sleep(std::time::Duration::from_secs(1)).await;
                break;
            }
            _ => {}
        }
    }
    Ok(())
}

async fn client(addr_json: &str, total_mib: usize) -> anyhow::Result<()> {
    let addr: iroh::EndpointAddr = serde_json::from_str(addr_json)?;
    let ep = mk_ep([10u8; 32]).await?;
    let mut cli = PhoneClient::connect(&ep, addr).await?;

    let chunk = vec![0x5au8; CHUNK];
    let n_chunks = (total_mib << 20) / CHUNK;
    let req = 1u64;

    let t0 = Instant::now();
    cli.upload_start(req, "bench.bin").await?;
    for _ in 0..n_chunks {
        cli.upload_chunk(req, &chunk).await?;
    }
    cli.upload_finish(req).await?;
    loop {
        match cli.next_msg().await? {
            WireMsg::UploadDone { .. } => break,
            WireMsg::FsError { message, .. } => anyhow::bail!("upload failed: {message}"),
            _ => {}
        }
    }
    let el = t0.elapsed().as_secs_f64();
    let mb = (n_chunks * CHUNK) as f64 / 1_048_576.0;
    println!(
        "CLIENT sent {:.0} MB in {:.2}s = {:.1} MB/s ({:.0} Mbps)",
        mb,
        el,
        mb / el,
        mb * 8.0 / el
    );
    Ok(())
}
