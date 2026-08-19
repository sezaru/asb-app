use std::collections::HashMap;
use std::fs::{File, OpenOptions};
use std::io::{BufReader, Read, Write};
use std::path::{Path, PathBuf};

use serde::{Deserialize, Serialize};

use crate::model::{Payload, Seq, TurnId, Update};

/// A durable, append-only per-session log. Each record is a 4-byte big-endian
/// length prefix followed by the CBOR encoding of a [`Record`]. `seq` is the
/// 1-based record index, assigned on append, and survives reopen.
pub struct ReplayLog {
    path: PathBuf,
    session: String,
    file: File,
    next_seq: Seq,
    /// Provider epoch -> highest applied client id, rebuilt from the log on
    /// open. Because the dedup key lives *in the persisted record*, this
    /// survives a daemon restart, so a resent (already-applied) message is
    /// recognized and skipped even after a crash — no duplicate, ever.
    applied: HashMap<String, u64>,
}

/// The on-disk record: an [`Update`] plus the optional at-least-once dedup key
/// `(epoch, cid)` of the provider message that produced it. Older logs hold a
/// bare `Update`; [`ReplayLog::scan`] falls back to that for back-compat.
#[derive(Serialize, Deserialize)]
struct Record {
    #[serde(rename = "u")]
    update: Update,
    #[serde(rename = "d", default, skip_serializing_if = "Option::is_none")]
    dedup: Option<(String, u64)>,
}

const MAX_RECORD: usize = 16 * 1024 * 1024;

impl ReplayLog {
    pub fn open(dir: &Path, session: &str) -> std::io::Result<Self> {
        std::fs::create_dir_all(dir)?;
        let path = dir.join(format!("{session}.log"));
        let existing = Self::scan(&path)?;
        let next_seq = existing.last().map(|r| r.update.seq + 1).unwrap_or(1);
        let mut applied: HashMap<String, u64> = HashMap::new();
        for r in &existing {
            if let Some((epoch, cid)) = &r.dedup {
                let hw = applied.entry(epoch.clone()).or_insert(0);
                if *cid > *hw {
                    *hw = *cid;
                }
            }
        }
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
            applied,
        })
    }

    /// True if `cid` for `epoch` was already durably appended (so a resend must
    /// be skipped, not re-applied). Monotonic per epoch, so a high-water compare.
    pub fn is_applied(&self, epoch: &str, cid: u64) -> bool {
        self.applied.get(epoch).is_some_and(|&hw| cid <= hw)
    }

    pub fn append(
        &mut self,
        payload: Payload,
        turn: TurnId,
        dedup: Option<(String, u64)>,
    ) -> std::io::Result<Seq> {
        let seq = self.next_seq;
        let rec = Record {
            update: Update {
                session: self.session.clone(),
                seq,
                turn,
                payload,
            },
            dedup: dedup.clone(),
        };
        let mut body = Vec::new();
        ciborium::into_writer(&rec, &mut body).expect("cbor encode is infallible for Record");
        self.file.write_all(&(body.len() as u32).to_be_bytes())?;
        self.file.write_all(&body)?;
        self.file.flush()?;
        self.next_seq += 1;
        if let Some((epoch, cid)) = dedup {
            let hw = self.applied.entry(epoch).or_insert(0);
            if cid > *hw {
                *hw = cid;
            }
        }
        Ok(seq)
    }

    /// Every record with `seq` strictly greater than `since`.
    pub fn read_since(&self, since: Seq) -> std::io::Result<Vec<Update>> {
        Ok(Self::scan(&self.path)?
            .into_iter()
            .map(|r| r.update)
            .filter(|u| u.seq > since)
            .collect())
    }

    pub fn last_seq(&self) -> Seq {
        self.next_seq.saturating_sub(1)
    }

    fn scan(path: &Path) -> std::io::Result<Vec<Record>> {
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
            // New records are `Record`; pre-dedup logs hold a bare `Update`.
            if let Ok(rec) = ciborium::from_reader::<Record, _>(&body[..]) {
                out.push(rec);
            } else if let Ok(update) = ciborium::from_reader::<Update, _>(&body[..]) {
                out.push(Record { update, dedup: None });
            } else {
                break; // torn/garbled record -> ignore the tail
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
        let s1 = log.append(msg("a"), 1, None).unwrap();
        let s2 = log.append(msg("b"), 1, None).unwrap();
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
            log.append(msg("a"), 1, None).unwrap();
        }
        let log = ReplayLog::open(dir.path(), "s").unwrap();
        assert_eq!(log.read_since(0).unwrap().len(), 1);
        assert_eq!(log.last_seq(), 1);
        // next append must continue from seq 2
        let mut log = log;
        assert_eq!(log.append(msg("b"), 1, None).unwrap(), 2);
    }

    #[test]
    fn dedup_high_water_survives_reopen() {
        let dir = tempfile::tempdir().unwrap();
        {
            let mut log = ReplayLog::open(dir.path(), "s").unwrap();
            log.append(msg("a"), 1, Some(("e".into(), 5))).unwrap();
            log.append(msg("b"), 1, Some(("e".into(), 7))).unwrap();
        }
        // Reopened from disk: the epoch high-water is rebuilt from the records.
        let log = ReplayLog::open(dir.path(), "s").unwrap();
        assert!(log.is_applied("e", 5));
        assert!(log.is_applied("e", 7));
        assert!(!log.is_applied("e", 8), "cid past high-water is not yet applied");
        assert!(!log.is_applied("other", 1), "unknown epoch is not applied");
    }

    #[test]
    fn torn_trailing_write_is_ignored() {
        let dir = tempfile::tempdir().unwrap();
        {
            let mut log = ReplayLog::open(dir.path(), "s").unwrap();
            log.append(msg("good"), 1, None).unwrap();
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
