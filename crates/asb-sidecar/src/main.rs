use std::path::PathBuf;
use std::sync::{Arc, Mutex};

use anyhow::Context;
use asb_protocol::identity::Identity;
use asb_protocol::net::build_endpoint;
use asb_protocol::pairing::pair_host;
use asb_protocol::roster::Roster;
use asb_sidecar::emacs_server::spawn_emacs_server;
use asb_sidecar::phone_server::{spawn_phone_server, spawn_push_watcher};
use asb_sidecar::presence::Presence;
use asb_sidecar::push::NoopPush;
use asb_sidecar::registry::Registry;
use roam_pake::PairingCode;
use tokio::sync::mpsc;

fn state_dir() -> PathBuf {
    if let Ok(x) = std::env::var("XDG_STATE_HOME") {
        return PathBuf::from(x).join("asb");
    }
    let home = std::env::var("HOME").unwrap_or_else(|_| ".".into());
    PathBuf::from(home).join(".local/state/asb")
}

fn socket_path() -> PathBuf {
    if let Ok(rt) = std::env::var("XDG_RUNTIME_DIR") {
        return PathBuf::from(rt).join("asb.sock");
    }
    state_dir().join("asb.sock")
}

fn hex(bytes: [u8; 32]) -> String {
    bytes.iter().map(|b| format!("{b:02x}")).collect()
}

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    tracing_subscriber::fmt().init();

    let dir = state_dir();
    std::fs::create_dir_all(&dir).context("create state dir")?;
    let identity = Identity::load_or_create(&dir.join("identity.json"))?;
    let roster_path = dir.join("roster.json");

    match std::env::args().nth(1).as_deref() {
        Some("run") => run(dir, identity, roster_path).await,
        Some("pair") => pair(identity, roster_path).await,
        _ => {
            eprintln!("usage: asb-sidecar <run|pair>");
            eprintln!("  run   start the resident daemon (Emacs socket + phone iroh server)");
            eprintln!("  pair  pair a new device (stop the daemon first)");
            std::process::exit(2);
        }
    }
}

async fn run(dir: PathBuf, identity: Identity, roster_path: PathBuf) -> anyhow::Result<()> {
    // single-instance guard
    let lock_path = dir.join("asb.lock");
    let lock = std::fs::OpenOptions::new()
        .create(true)
        .write(true)
        .open(&lock_path)?;
    use fs2::FileExt;
    if lock.try_lock_exclusive().is_err() {
        eprintln!("asb-sidecar already running (lock held at {})", lock_path.display());
        std::process::exit(1);
    }

    let host_id = hex(identity.node_id_bytes());
    let reg = Arc::new(Registry::new(dir.join("logs")));
    let roster = Arc::new(Mutex::new(Roster::load(&roster_path)?));
    let presence = Presence::new();
    let (out_tx, out_rx) = mpsc::channel(64);

    let ep = build_endpoint(identity.secret_bytes()).await?;
    let sock = socket_path();
    tracing::info!(host_id = %host_id, socket = %sock.display(), "asb-sidecar started");

    spawn_emacs_server(sock, reg.clone(), out_rx)?;
    spawn_push_watcher(
        reg.clone(),
        roster.clone(),
        presence.clone(),
        Arc::new(NoopPush),
        host_id,
    );
    let _srv = spawn_phone_server(ep.clone(), reg, roster, out_tx, presence);

    tokio::signal::ctrl_c().await?;
    tracing::info!("shutting down");
    ep.close().await;
    Ok(())
}

async fn pair(identity: Identity, roster_path: PathBuf) -> anyhow::Result<()> {
    let mut roster = Roster::load(&roster_path)?;
    let ep = build_endpoint(identity.secret_bytes()).await?;
    let code = PairingCode::generate();

    println!("\n  Pairing code : {}", code.as_str());
    println!("  Host node id : {}", hex(identity.node_id_bytes()));
    println!("\n  Enter these on the phone, then waiting for it to join…\n");

    let entry = pair_host(&ep, &code, &identity).await?;
    roster.add(entry)?;
    println!("  Paired ✓  (roster: {})", roster_path.display());
    ep.close().await;
    Ok(())
}
