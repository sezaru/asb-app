use std::collections::HashMap;
use std::path::PathBuf;
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
                    tokio::spawn(handle_conn(stream, reg.clone(), owners.clone()));
                }
                Err(_) => break,
            }
        }
    });
    Ok(handle)
}

async fn handle_conn(stream: UnixStream, reg: Arc<Registry>, owners: Owners) {
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
        // Never die on a malformed line (ACP-proxy lesson); just skip it.
        let Ok(msg) = serde_json::from_str::<EmacsIn>(&line) else {
            continue;
        };
        if let EmacsIn::SessionOpen { session, .. } = &msg {
            owners
                .lock()
                .unwrap()
                .insert(session.clone(), line_tx.clone());
            mine.push(session.clone());
        }
        let _ = reg.handle_emacs(msg).await;
    }

    // deregister only the sessions still owned by *this* connection
    let mut o = owners.lock().unwrap();
    for s in mine {
        if o.get(&s).map(|t| t.same_channel(&line_tx)).unwrap_or(false) {
            o.remove(&s);
        }
    }
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

        out_tx
            .send(EmacsOut::Inject {
                session: "s".into(),
                text: "go".into(),
            })
            .await
            .unwrap();
        let line = read_one_line(&mut cli).await;
        assert!(line.contains("\"t\":\"inject\""), "got {line}");
    }
}
