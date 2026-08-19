use std::collections::HashMap;
use std::path::PathBuf;
use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::{Arc, Mutex};

use asb_protocol::emacs::{EmacsIn, EmacsOut};
use asb_protocol::model::SessionId;
use tokio::io::{AsyncBufReadExt, AsyncWriteExt, BufReader};
use tokio::net::{UnixListener, UnixStream};
use tokio::sync::mpsc;
use tokio::task::JoinHandle;

use crate::registry::Registry;

/// session id -> line-writer of the connection that opened it.
type Owners = Arc<Mutex<HashMap<SessionId, mpsc::UnboundedSender<String>>>>;

fn emacs_out_session(ev: &EmacsOut) -> SessionId {
    match ev {
        EmacsOut::Inject { session, .. }
        | EmacsOut::Command { session, .. }
        | EmacsOut::PermissionResponse { session, .. }
        | EmacsOut::Interrupt { session } => session.clone(),
    }
}

/// Bind the unix socket and serve every connecting Emacs instance. `out_rx`
/// carries sidecar→provider events, routed to the connection owning each session.
pub fn spawn_emacs_server(
    sock: PathBuf,
    reg: Arc<Registry>,
    mut out_rx: mpsc::Receiver<EmacsOut>,
) -> anyhow::Result<JoinHandle<()>> {
    let _ = std::fs::remove_file(&sock);
    let listener = UnixListener::bind(&sock)?;
    let owners: Owners = Arc::new(Mutex::new(HashMap::new()));

    {
        let owners = owners.clone();
        tokio::spawn(async move {
            while let Some(ev) = out_rx.recv().await {
                let session = emacs_out_session(&ev);
                let line = match serde_json::to_string(&ev) {
                    Ok(l) => l,
                    Err(_) => continue,
                };
                let tx = owners.lock().unwrap().get(&session).cloned();
                if let Some(tx) = tx {
                    let _ = tx.send(line);
                }
            }
        });
    }

    let handle = tokio::spawn(async move {
        loop {
            match listener.accept().await {
                Ok((stream, _)) => {
                    let conn = NEXT_CONN.fetch_add(1, Ordering::Relaxed);
                    tokio::spawn(handle_conn(conn, stream, reg.clone(), owners.clone()));
                }
                Err(_) => break,
            }
        }
    });
    Ok(handle)
}

/// Ack a delivered client id back over the same socket. `t` distinguishes it
/// from an `EmacsOut` on the provider's line reader.
fn ack_line(cid: u64) -> String {
    format!("{{\"t\":\"ack\",\"cid\":{cid}}}")
}

/// Reply to a `session-claim`, correlated by `cid`, carrying the grant.
fn claim_result_line(cid: u64, granted: bool) -> String {
    format!("{{\"t\":\"claim-result\",\"cid\":{cid},\"granted\":{granted}}}")
}

/// Report a session's persisted ordinal high-water after a `session-open`, so
/// the provider seeds its per-session dedup counter.
fn session_hw_line(session: &str, hw: u64) -> String {
    let session = serde_json::to_string(session).unwrap_or_else(|_| "\"\"".into());
    format!("{{\"t\":\"session-hw\",\"session\":{session},\"hw\":{hw}}}")
}

/// Monotonic id per Emacs-server connection, so the registry can free the
/// sessions a dropped connection owned.
static NEXT_CONN: AtomicU64 = AtomicU64::new(1);

async fn handle_conn(conn: u64, stream: UnixStream, reg: Arc<Registry>, owners: Owners) {
    let (read_half, mut write_half) = stream.into_split();
    let (line_tx, mut line_rx) = mpsc::unbounded_channel::<String>();

    tokio::spawn(async move {
        while let Some(line) = line_rx.recv().await {
            if write_half.write_all(line.as_bytes()).await.is_err()
                || write_half.write_all(b"\n").await.is_err()
            {
                break;
            }
        }
    });

    let mut lines = BufReader::new(read_half).lines();
    let mut mine: Vec<SessionId> = Vec::new();
    while let Ok(Some(line)) = lines.next_line().await {
        if line.trim().is_empty() {
            continue;
        }
        // Optional at-least-once envelope: {"cid":<int>,...} riding alongside the
        // typed message. We ack the cid so the provider can drop it from its
        // outbox -- but ONLY once the message is durably handled. Dedup of a
        // resend lives in the registry/log (which persists across restarts), so
        // an already-applied `Msg` is a no-op there yet still gets acked here.
        let cid = serde_json::from_str::<serde_json::Value>(&line)
            .ok()
            .and_then(|v| v.get("cid").and_then(|x| x.as_u64()));
        match serde_json::from_str::<EmacsIn>(&line) {
            // Synchronous resume gate: reply with the grant, correlated by cid,
            // and do NOT fall through to the generic ack.
            Ok(EmacsIn::SessionClaim { session, cid }) => {
                let granted = reg.claim(conn, &session);
                let _ = line_tx.send(claim_result_line(cid, granted));
                continue;
            }
            Ok(msg) => {
                let mut opened: Option<SessionId> = None;
                if let EmacsIn::SessionOpen { session, .. } = &msg {
                    owners
                        .lock()
                        .unwrap()
                        .insert(session.clone(), line_tx.clone());
                    mine.push(session.clone());
                    opened = Some(session.clone());
                }
                match reg.handle_emacs(conn, msg).await {
                    Ok(()) => {
                        // Report the session's persisted ordinal high-water so the
                        // provider seeds its counter (resume without replay) and
                        // knows how far a replay must re-number before appending.
                        if let Some(session) = opened {
                            let hw = reg.high_water(&session);
                            let _ = line_tx.send(session_hw_line(&session, hw));
                        }
                        if let Some(c) = cid {
                            let _ = line_tx.send(ack_line(c));
                        }
                    }
                    // Transient (e.g. a msg racing ahead of its session-open):
                    // withhold the ack so the provider resends it.
                    Err(e) => tracing::warn!("handle_emacs failed, not acking: {e:#}"),
                }
            }
            // Never die on a malformed line (ACP-proxy lesson). Ack it so the
            // provider stops resending an unparseable line forever.
            Err(_) => {
                if let Some(c) = cid {
                    let _ = line_tx.send(ack_line(c));
                }
            }
        }
    }

    // deregister only the sessions still owned by *this* connection
    {
        let mut o = owners.lock().unwrap();
        for s in mine {
            if o.get(&s).map(|t| t.same_channel(&line_tx)).unwrap_or(false) {
                o.remove(&s);
            }
        }
    }
    // Free this connection's active sessions so the ref-count reflects the drop
    // (its Emacs closed or crashed); local unix sockets signal EOF promptly.
    reg.close_connection(conn);
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::time::Duration;
    use tokio::io::AsyncReadExt;

    async fn read_one_line(s: &mut UnixStream) -> String {
        let mut buf = Vec::new();
        let mut byte = [0u8; 1];
        loop {
            let n = tokio::time::timeout(Duration::from_secs(2), s.read(&mut byte))
                .await
                .expect("read timed out")
                .unwrap();
            if n == 0 || byte[0] == b'\n' {
                break;
            }
            buf.push(byte[0]);
        }
        String::from_utf8(buf).unwrap()
    }

    /// Read lines until one contains `needle`, skipping unrelated frames (e.g.
    /// the `session-hw` a session-open now emits ahead of an ack).
    async fn read_until(s: &mut UnixStream, needle: &str) -> String {
        for _ in 0..10 {
            let line = read_one_line(s).await;
            if line.contains(needle) {
                return line;
            }
        }
        panic!("never saw a line containing {needle}");
    }

    #[tokio::test]
    async fn emacs_socket_roundtrip() {
        let dir = tempfile::tempdir().unwrap();
        let sock = dir.path().join("asb.sock");
        let reg = Arc::new(Registry::new(dir.path().to_path_buf()));
        let (out_tx, out_rx) = mpsc::channel(16);
        let _srv = spawn_emacs_server(sock.clone(), reg.clone(), out_rx).unwrap();

        let mut cli = UnixStream::connect(&sock).await.unwrap();
        cli.write_all(b"{\"t\":\"session-open\",\"session\":\"s\",\"title\":\"t\"}\n")
            .await
            .unwrap();
        cli.write_all(b"{\"t\":\"msg\",\"session\":\"s\",\"seq\":0,\"turn\":1,\"payload\":{\"type\":\"agent_message\",\"text\":\"hi\"}}\n")
            .await
            .unwrap();

        for _ in 0..100 {
            if reg.last_seq("s") == 1 {
                break;
            }
            tokio::time::sleep(Duration::from_millis(10)).await;
        }
        assert_eq!(reg.last_seq("s"), 1);

        // session-open replies session-hw (high-water 0 for a fresh session).
        let hw = read_until(&mut cli, "\"t\":\"session-hw\"").await;
        assert!(hw.contains("\"hw\":0"), "got {hw}");

        out_tx
            .send(EmacsOut::Inject {
                session: "s".into(),
                text: "go".into(),
            })
            .await
            .unwrap();
        let line = read_until(&mut cli, "\"t\":\"inject\"").await;
        assert!(line.contains("\"t\":\"inject\""), "got {line}");
    }

    #[tokio::test]
    async fn session_claim_grants_then_blocks_second_connection() {
        let dir = tempfile::tempdir().unwrap();
        let sock = dir.path().join("asb.sock");
        let reg = Arc::new(Registry::new(dir.path().to_path_buf()));
        let (_out_tx, out_rx) = mpsc::channel(16);
        let _srv = spawn_emacs_server(sock.clone(), reg.clone(), out_rx).unwrap();

        // First connection resumes session s -> granted.
        let mut a = UnixStream::connect(&sock).await.unwrap();
        a.write_all(b"{\"t\":\"session-claim\",\"session\":\"s\",\"cid\":7}\n")
            .await
            .unwrap();
        let r = read_one_line(&mut a).await;
        assert!(r.contains("\"t\":\"claim-result\"") && r.contains("\"cid\":7")
                && r.contains("\"granted\":true"), "got {r}");

        // A second connection resuming the same session -> denied.
        let mut b = UnixStream::connect(&sock).await.unwrap();
        b.write_all(b"{\"t\":\"session-claim\",\"session\":\"s\",\"cid\":9}\n")
            .await
            .unwrap();
        let r2 = read_one_line(&mut b).await;
        assert!(r2.contains("\"cid\":9") && r2.contains("\"granted\":false"), "got {r2}");

        // First connection drops -> its reservation frees; b may now claim.
        drop(a);
        tokio::time::sleep(Duration::from_millis(50)).await;
        b.write_all(b"{\"t\":\"session-claim\",\"session\":\"s\",\"cid\":10}\n")
            .await
            .unwrap();
        let r3 = read_one_line(&mut b).await;
        assert!(r3.contains("\"cid\":10") && r3.contains("\"granted\":true"), "got {r3}");
    }

    #[tokio::test]
    async fn cid_is_acked_and_msg_deduped_by_ord() {
        let dir = tempfile::tempdir().unwrap();
        let sock = dir.path().join("asb.sock");
        let reg = Arc::new(Registry::new(dir.path().to_path_buf()));
        let (_out_tx, out_rx) = mpsc::channel(16);
        let _srv = spawn_emacs_server(sock.clone(), reg.clone(), out_rx).unwrap();

        let mut cli = UnixStream::connect(&sock).await.unwrap();
        cli.write_all(b"{\"t\":\"session-open\",\"session\":\"s\",\"title\":\"t\",\"cid\":1}\n")
            .await
            .unwrap();
        // A msg carrying ord=1 (dedup key) and cid=2 (ack correlation).
        let msg = b"{\"t\":\"msg\",\"session\":\"s\",\"seq\":0,\"turn\":0,\"payload\":{\"type\":\"agent_message\",\"text\":\"hi\"},\"ord\":1,\"cid\":2}\n";
        cli.write_all(msg).await.unwrap();

        // The cid ack rides through for both the session-open (1) and the msg (2).
        assert!(read_until(&mut cli, "\"cid\":1").await.contains("\"t\":\"ack\""));
        assert!(read_until(&mut cli, "\"cid\":2").await.contains("\"t\":\"ack\""));
        for _ in 0..100 {
            if reg.last_seq("s") == 1 {
                break;
            }
            tokio::time::sleep(Duration::from_millis(10)).await;
        }
        assert_eq!(reg.last_seq("s"), 1);

        // Resend the same ord=1 under a DIFFERENT cid=3: acked, but dedup is by
        // ord, so it is NOT re-appended (a resume replaying the phrase, too).
        cli.write_all(b"{\"t\":\"msg\",\"session\":\"s\",\"seq\":0,\"turn\":0,\"payload\":{\"type\":\"agent_message\",\"text\":\"hi\"},\"ord\":1,\"cid\":3}\n")
            .await
            .unwrap();
        assert!(read_until(&mut cli, "\"cid\":3").await.contains("\"t\":\"ack\""));
        tokio::time::sleep(Duration::from_millis(50)).await;
        assert_eq!(reg.last_seq("s"), 1, "resent ordinal must not duplicate");

        // A new ord=2 lands.
        cli.write_all(b"{\"t\":\"msg\",\"session\":\"s\",\"seq\":0,\"turn\":0,\"payload\":{\"type\":\"agent_message\",\"text\":\"bye\"},\"ord\":2,\"cid\":4}\n")
            .await
            .unwrap();
        assert!(read_until(&mut cli, "\"cid\":4").await.contains("\"t\":\"ack\""));
        for _ in 0..100 {
            if reg.last_seq("s") == 2 {
                break;
            }
            tokio::time::sleep(Duration::from_millis(10)).await;
        }
        assert_eq!(reg.last_seq("s"), 2);
    }
}
