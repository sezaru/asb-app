use std::path::PathBuf;
use std::sync::{Arc, Mutex};
use std::time::Duration;

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
use fs2::FileExt;
use roam_pake::PairingCode;
use tokio::sync::mpsc;
use tokio::sync::watch;

/// One shared per-machine state dir: identity + roster (pairing) are shared
/// across every Emacs instance, so pairing is done once and survives restarts.
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

/// No agent-shell buffer has appeared within this window after spawn -> the
/// spawner died before opening a session; don't linger.
const STARTUP_GRACE: Duration = Duration::from_secs(30);
/// Every buffer closed (or its Emacs dropped) -> wait this long before exiting,
/// so a brief socket blip / reconnect doesn't churn the daemon.
const IDLE_GRACE: Duration = Duration::from_secs(15);

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    tracing_subscriber::fmt().with_writer(std::io::stderr).init();

    let dir = state_dir();
    std::fs::create_dir_all(&dir).context("create state dir")?;
    let identity = Identity::load_or_create(&dir.join("identity.json"))?;
    let roster_path = dir.join("roster.json");

    match std::env::args().nth(1).as_deref() {
        Some("run") => run(dir, identity, roster_path).await,
        Some("pair") => pair(identity, roster_path).await,
        _ => {
            eprintln!("usage: asb-sidecar <run|pair>");
            eprintln!("  run   start the shared daemon (Emacs socket + phone iroh server)");
            eprintln!("  pair  pair a new device (stop the daemon first)");
            std::process::exit(2);
        }
    }
}

async fn run(dir: PathBuf, identity: Identity, roster_path: PathBuf) -> anyhow::Result<()> {
    // Single shared daemon per machine, elected by an OS flock. The kernel
    // releases the lock automatically on crash/kill -9/power-loss, so there is
    // no stale lock to clean up. A late spawner simply loses the election and
    // exits 0 -- its Emacs then connects to the winner over the shared socket.
    let lock_path = dir.join("asb.lock");
    let lock = std::fs::OpenOptions::new()
        .create(true)
        .write(true)
        .open(&lock_path)?;
    if lock.try_lock_exclusive().is_err() {
        tracing::info!("another asb-sidecar already holds {}; exiting", lock_path.display());
        return Ok(());
    }

    let host_id = hex(identity.node_id_bytes());
    let reg = Arc::new(Registry::new(dir.join("logs")));
    let roster = Arc::new(Mutex::new(Roster::load(&roster_path)?));
    let presence = Presence::new();
    let (out_tx, out_rx) = mpsc::channel(64);

    let ep = build_endpoint(identity.secret_bytes()).await?;
    let sock = socket_path();
    tracing::info!(host_id = %host_id, socket = %sock.display(), "asb-sidecar started");

    let active = reg.active_rx();
    spawn_emacs_server(sock, reg.clone(), out_rx)?;
    spawn_push_watcher(
        reg.clone(),
        roster.clone(),
        presence.clone(),
        Arc::new(NoopPush),
        host_id,
    );
    let _srv = spawn_phone_server(ep.clone(), reg, roster, out_tx, presence);

    // Lifetime = live agent-shell buffers (active sessions), NOT the spawning
    // Emacs. Exit when the last buffer anywhere closes.
    tokio::select! {
        _ = tokio::signal::ctrl_c() => tracing::info!("interrupted"),
        _ = wait_until_idle(active) => tracing::info!("no active sessions; shutting down"),
    }
    ep.close().await;
    Ok(())
}

/// Resolve once the daemon should exit: no session ever opened within the
/// startup grace, or every session closed and stayed closed for the idle grace.
async fn wait_until_idle(mut active: watch::Receiver<usize>) {
    // Startup: wait for the first session, or bail if none appears.
    if *active.borrow() == 0 {
        tokio::select! {
            _ = wait_for(&mut active, |n| n > 0) => {}
            _ = tokio::time::sleep(STARTUP_GRACE) => {
                if *active.borrow() == 0 {
                    return;
                }
            }
        }
    }
    // Steady state: exit only after the count has been 0 for the whole grace.
    loop {
        wait_for(&mut active, |n| n == 0).await;
        tokio::select! {
            _ = tokio::time::sleep(IDLE_GRACE) => {
                if *active.borrow() == 0 {
                    return;
                }
            }
            // Re-armed by a new/reconnected session before the grace elapsed.
            _ = wait_for(&mut active, |n| n > 0) => {}
        }
    }
}

/// Await the next `active` value satisfying `pred` (returns immediately if the
/// current value already does). Resolves if the sender is dropped.
async fn wait_for(active: &mut watch::Receiver<usize>, pred: impl Fn(usize) -> bool) {
    if pred(*active.borrow()) {
        return;
    }
    while active.changed().await.is_ok() {
        if pred(*active.borrow()) {
            return;
        }
    }
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
