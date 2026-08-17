use std::path::{Path, PathBuf};

use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum PeerKind {
    /// A host we (a client) are paired with.
    Host,
    /// A client paired with us (a host).
    Client,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct RosterEntry {
    pub node_id: [u8; 32],
    pub kind: PeerKind,
    pub fcm_token: Option<String>,
    pub added_at: u64,
}

/// The signed allow-list persisted to disk. Symmetric: a host stores `Client`
/// entries, a client stores `Host` entries.
pub struct Roster {
    entries: Vec<RosterEntry>,
    path: PathBuf,
}

impl Roster {
    pub fn load(path: &Path) -> anyhow::Result<Self> {
        let entries = match std::fs::read(path) {
            Ok(bytes) => serde_json::from_slice(&bytes)?,
            Err(_) => Vec::new(),
        };
        Ok(Self {
            entries,
            path: path.to_path_buf(),
        })
    }

    pub fn add(&mut self, entry: RosterEntry) -> anyhow::Result<()> {
        self.entries.retain(|e| e.node_id != entry.node_id);
        self.entries.push(entry);
        self.persist()
    }

    fn persist(&self) -> anyhow::Result<()> {
        std::fs::write(&self.path, serde_json::to_vec_pretty(&self.entries)?)?;
        Ok(())
    }

    pub fn contains(&self, node_id: &[u8; 32]) -> bool {
        self.entries.iter().any(|e| &e.node_id == node_id)
    }

    pub fn client_tokens(&self) -> Vec<String> {
        self.entries
            .iter()
            .filter(|e| e.kind == PeerKind::Client)
            .filter_map(|e| e.fcm_token.clone())
            .collect()
    }

    pub fn entries(&self) -> &[RosterEntry] {
        &self.entries
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn roster_persists_and_gates() {
        let dir = tempfile::tempdir().unwrap();
        let p = dir.path().join("roster.json");
        let mut r = Roster::load(&p).unwrap();
        let node = [7u8; 32];
        r.add(RosterEntry {
            node_id: node,
            kind: PeerKind::Client,
            fcm_token: Some("tok".into()),
            added_at: 0,
        })
        .unwrap();

        let r2 = Roster::load(&p).unwrap();
        assert!(r2.contains(&node));
        assert!(!r2.contains(&[0u8; 32]));
        assert_eq!(r2.client_tokens(), vec!["tok".to_string()]);
    }

    #[test]
    fn add_is_idempotent_by_node_id() {
        let dir = tempfile::tempdir().unwrap();
        let p = dir.path().join("roster.json");
        let mut r = Roster::load(&p).unwrap();
        let node = [9u8; 32];
        for tok in ["a", "b"] {
            r.add(RosterEntry {
                node_id: node,
                kind: PeerKind::Client,
                fcm_token: Some(tok.into()),
                added_at: 0,
            })
            .unwrap();
        }
        assert_eq!(r.entries().len(), 1);
        assert_eq!(r.client_tokens(), vec!["b".to_string()]); // last write wins
    }
}
