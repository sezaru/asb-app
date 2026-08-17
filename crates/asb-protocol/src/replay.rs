use std::fs::{File, OpenOptions};
use std::io::{BufReader, Read, Write};
use std::path::{Path, PathBuf};

use crate::model::{Payload, Seq, TurnId, Update};

/// A durable, append-only per-session log. Each record is a 4-byte big-endian
/// length prefix followed by the CBOR encoding of an [`Update`]. `seq` is the
/// 1-based record index, assigned on append, and survives reopen.
pub struct ReplayLog {
    path: PathBuf,
    session: String,
    file: File,
    next_seq: Seq,
}

const MAX_RECORD: usize = 16 * 1024 * 1024;

impl ReplayLog {
    pub fn open(dir: &Path, session: &str) -> std::io::Result<Self> {
        std::fs::create_dir_all(dir)?;
        let path = dir.join(format!("{session}.log"));
        let existing = Self::scan(&path)?;
        let next_seq = existing.last().map(|u| u.seq + 1).unwrap_or(1);
        let file = OpenOptions::new()
            .create(true)
            .append(true)
            .read(true)
            .open(&path)?;
        Ok(Self {
            path,
            session: session.to_string(),
            file,
            next_seq,
        })
    }

    pub fn append(&mut self, payload: Payload, turn: TurnId) -> std::io::Result<Seq> {
        let seq = self.next_seq;
        let u = Update {
            session: self.session.clone(),
            seq,
            turn,
            payload,
        };
        let mut body = Vec::new();
        ciborium::into_writer(&u, &mut body).expect("cbor encode is infallible for Update");
        self.file.write_all(&(body.len() as u32).to_be_bytes())?;
        self.file.write_all(&body)?;
        self.file.flush()?;
        self.next_seq += 1;
        Ok(seq)
    }

    /// Every record with `seq` strictly greater than `since`.
    pub fn read_since(&self, since: Seq) -> std::io::Result<Vec<Update>> {
        Ok(Self::scan(&self.path)?
            .into_iter()
            .filter(|u| u.seq > since)
            .collect())
    }

    pub fn last_seq(&self) -> Seq {
        self.next_seq.saturating_sub(1)
    }

    fn scan(path: &Path) -> std::io::Result<Vec<Update>> {
        let f = match File::open(path) {
            Ok(f) => f,
            Err(_) => return Ok(vec![]),
        };
        let mut r = BufReader::new(f);
        let mut out = Vec::new();
        loop {
            let mut len = [0u8; 4];
            if r.read_exact(&mut len).is_err() {
                break; // clean EOF or a torn length prefix -> stop
            }
            let n = u32::from_be_bytes(len) as usize;
            if n == 0 || n > MAX_RECORD {
                break;
            }
            let mut body = vec![0u8; n];
            if r.read_exact(&mut body).is_err() {
                break; // torn trailing record -> ignore the tail
            }
            match ciborium::from_reader::<Update, _>(&body[..]) {
                Ok(u) => out.push(u),
                Err(_) => break,
            }
        }
        Ok(out)
    }

    pub fn prune(self) -> std::io::Result<()> {
        std::fs::remove_file(&self.path)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn msg(t: &str) -> Payload {
        Payload::AgentMessage { text: t.into() }
    }

    #[test]
    fn append_and_read_since() {
        let dir = tempfile::tempdir().unwrap();
        let mut log = ReplayLog::open(dir.path(), "s").unwrap();
        let s1 = log.append(msg("a"), 1).unwrap();
        let s2 = log.append(msg("b"), 1).unwrap();
        assert_eq!((s1, s2), (1, 2));
        let got = log.read_since(1).unwrap();
        assert_eq!(got.len(), 1);
        assert_eq!(got[0].seq, 2);
    }

    #[test]
    fn survives_reopen() {
        let dir = tempfile::tempdir().unwrap();
        {
            let mut log = ReplayLog::open(dir.path(), "s").unwrap();
            log.append(msg("a"), 1).unwrap();
        }
        let log = ReplayLog::open(dir.path(), "s").unwrap();
        assert_eq!(log.read_since(0).unwrap().len(), 1);
        assert_eq!(log.last_seq(), 1);
        // next append must continue from seq 2
        let mut log = log;
        assert_eq!(log.append(msg("b"), 1).unwrap(), 2);
    }

    #[test]
    fn torn_trailing_write_is_ignored() {
        let dir = tempfile::tempdir().unwrap();
        {
            let mut log = ReplayLog::open(dir.path(), "s").unwrap();
            log.append(msg("good"), 1).unwrap();
        }
        // append junk that looks like a length prefix + short body
        let mut f = OpenOptions::new()
            .append(true)
            .open(dir.path().join("s.log"))
            .unwrap();
        f.write_all(&[0, 0, 0, 8, 1, 2]).unwrap(); // claims 8 bytes, only 2 present
        f.flush().unwrap();

        let log = ReplayLog::open(dir.path(), "s").unwrap();
        let got = log.read_since(0).unwrap();
        assert_eq!(got.len(), 1);
        assert!(matches!(&got[0].payload, Payload::AgentMessage { text } if text == "good"));
    }
}
