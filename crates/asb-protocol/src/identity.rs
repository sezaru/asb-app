use std::path::Path;

use base64::Engine;
use ed25519_dalek::SigningKey;
use rand::rngs::OsRng;
use serde::{Deserialize, Serialize};

/// This device's long-term ed25519 keypair. The iroh `NodeId` equals the
/// verifying-key bytes, so persisting the secret pins a stable node identity.
pub struct Identity {
    signing: SigningKey,
}

#[derive(Serialize, Deserialize)]
struct OnDisk {
    secret_b64: String,
}

const B64: base64::engine::GeneralPurpose = base64::engine::general_purpose::STANDARD;

impl Identity {
    pub fn load_or_create(path: &Path) -> anyhow::Result<Self> {
        if let Ok(bytes) = std::fs::read(path) {
            let od: OnDisk = serde_json::from_slice(&bytes)?;
            let raw = B64.decode(od.secret_b64.as_bytes())?;
            let arr: [u8; 32] = raw
                .as_slice()
                .try_into()
                .map_err(|_| anyhow::anyhow!("identity secret is not 32 bytes"))?;
            return Ok(Self {
                signing: SigningKey::from_bytes(&arr),
            });
        }
        let signing = SigningKey::generate(&mut OsRng);
        let od = OnDisk {
            secret_b64: B64.encode(signing.to_bytes()),
        };
        std::fs::write(path, serde_json::to_vec(&od)?)?;
        #[cfg(unix)]
        {
            use std::os::unix::fs::PermissionsExt;
            std::fs::set_permissions(path, std::fs::Permissions::from_mode(0o600))?;
        }
        Ok(Self { signing })
    }

    pub fn secret_bytes(&self) -> [u8; 32] {
        self.signing.to_bytes()
    }

    pub fn node_id_bytes(&self) -> [u8; 32] {
        self.signing.verifying_key().to_bytes()
    }

    pub fn signing(&self) -> &SigningKey {
        &self.signing
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn identity_roundtrips_node_id() {
        let dir = tempfile::tempdir().unwrap();
        let p = dir.path().join("id.json");
        let a = Identity::load_or_create(&p).unwrap();
        let b = Identity::load_or_create(&p).unwrap();
        assert_eq!(a.node_id_bytes(), b.node_id_bytes());
        assert_eq!(a.secret_bytes(), b.secret_bytes());
    }

    #[test]
    fn distinct_paths_distinct_ids() {
        let dir = tempfile::tempdir().unwrap();
        let a = Identity::load_or_create(&dir.path().join("a.json")).unwrap();
        let b = Identity::load_or_create(&dir.path().join("b.json")).unwrap();
        assert_ne!(a.node_id_bytes(), b.node_id_bytes());
    }
}
