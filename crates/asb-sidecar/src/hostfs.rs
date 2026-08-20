//! Host-filesystem access for the phone: directory browsing and attachment
//! uploads. The sidecar runs on the host, so these are plain `std::fs` calls —
//! no Emacs round-trip. Replies go straight back on the requesting phone's
//! stream (see `phone_server`), never broadcast.

use std::fs::File;
use std::path::{Path, PathBuf};

use anyhow::Context;
use asb_protocol::wire::FsEntry;

/// The user's home, the default starting point for a browse.
fn home() -> PathBuf {
    std::env::var_os("HOME").map(PathBuf::from).unwrap_or_else(|| PathBuf::from("/"))
}

/// Where uploaded attachments land: `$XDG_CACHE_HOME/asb/uploads` (or
/// `~/.cache/asb/uploads`). The agent references files here by absolute path.
fn uploads_dir() -> PathBuf {
    let base = std::env::var_os("XDG_CACHE_HOME")
        .map(PathBuf::from)
        .unwrap_or_else(|| home().join(".cache"));
    base.join("asb").join("uploads")
}

/// List a host directory. `path` None starts at home. Entries are dirs-first,
/// then alphabetical (case-insensitive). Returns `(resolved_dir, parent)` too so
/// the phone can render the location and a ".." affordance.
pub fn list_dir(path: Option<&str>) -> anyhow::Result<(String, Option<String>, Vec<FsEntry>)> {
    let target = match path {
        Some(p) if !p.is_empty() => PathBuf::from(p),
        _ => home(),
    };
    let dir = std::fs::canonicalize(&target).with_context(|| format!("resolve {target:?}"))?;
    anyhow::ensure!(dir.is_dir(), "{} is not a directory", dir.display());

    let mut entries = Vec::new();
    for de in std::fs::read_dir(&dir).with_context(|| format!("read {}", dir.display()))? {
        let de = match de {
            Ok(de) => de,
            Err(_) => continue,
        };
        let name = de.file_name().to_string_lossy().into_owned();
        // A symlink to a dir should browse as a dir; fall back to the entry type.
        let is_dir = de
            .metadata()
            .map(|m| m.is_dir())
            .or_else(|_| de.file_type().map(|t| t.is_dir()))
            .unwrap_or(false);
        entries.push(FsEntry {
            path: de.path().to_string_lossy().into_owned(),
            name,
            is_dir,
        });
    }
    entries.sort_by(|a, b| {
        b.is_dir
            .cmp(&a.is_dir)
            .then_with(|| a.name.to_lowercase().cmp(&b.name.to_lowercase()))
    });

    let parent = dir.parent().map(|p| p.to_string_lossy().into_owned());
    Ok((dir.to_string_lossy().into_owned(), parent, entries))
}

/// Open a fresh file under the uploads dir for a chunked upload, returning its
/// path and handle. `name` is reduced to a bare filename; collisions get a `-N`
/// suffix so a re-upload never clobbers an earlier file. The caller appends
/// decoded chunks to the handle and keeps the path to reply with.
pub fn create_upload(name: &str) -> anyhow::Result<(PathBuf, File)> {
    let dir = uploads_dir();
    std::fs::create_dir_all(&dir).with_context(|| format!("create {}", dir.display()))?;
    let target = unique_path(&dir, sanitize(name));
    let file = File::create(&target).with_context(|| format!("create {}", target.display()))?;
    Ok((target, file))
}

/// Strip any directory components and reject empties, so an upload can only ever
/// land inside the uploads dir.
fn sanitize(name: &str) -> String {
    let base = Path::new(name)
        .file_name()
        .map(|s| s.to_string_lossy().into_owned())
        .unwrap_or_default();
    let base = base.trim();
    if base.is_empty() || base == "." || base == ".." {
        "upload".to_string()
    } else {
        base.to_string()
    }
}

/// `dir/name`, or `dir/stem-N.ext` for the first N that doesn't exist.
fn unique_path(dir: &Path, name: String) -> PathBuf {
    let candidate = dir.join(&name);
    if !candidate.exists() {
        return candidate;
    }
    let path = Path::new(&name);
    let stem = path.file_stem().map(|s| s.to_string_lossy().into_owned()).unwrap_or_else(|| name.clone());
    let ext = path.extension().map(|e| format!(".{}", e.to_string_lossy())).unwrap_or_default();
    for n in 1.. {
        let candidate = dir.join(format!("{stem}-{n}{ext}"));
        if !candidate.exists() {
            return candidate;
        }
    }
    unreachable!()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn list_dir_sorts_dirs_first() {
        let tmp = tempfile::tempdir().unwrap();
        std::fs::create_dir(tmp.path().join("zsub")).unwrap();
        std::fs::write(tmp.path().join("afile.txt"), b"x").unwrap();
        std::fs::write(tmp.path().join("bfile.txt"), b"y").unwrap();

        let (dir, parent, entries) = list_dir(Some(tmp.path().to_str().unwrap())).unwrap();
        assert!(dir.ends_with(tmp.path().file_name().unwrap().to_str().unwrap()));
        assert!(parent.is_some());
        assert_eq!(entries.len(), 3);
        assert_eq!(entries[0].name, "zsub");
        assert!(entries[0].is_dir);
        assert_eq!(entries[1].name, "afile.txt");
        assert_eq!(entries[2].name, "bfile.txt");
    }

    #[test]
    fn create_upload_opens_unique_and_dedups() {
        use std::io::Write;
        let tmp = tempfile::tempdir().unwrap();
        std::env::set_var("XDG_CACHE_HOME", tmp.path());

        let (p1, mut f1) = create_upload("shot.png").unwrap();
        f1.write_all(b"hello bytes").unwrap();
        drop(f1);
        assert!(p1.to_string_lossy().ends_with("shot.png"));
        assert_eq!(std::fs::read(&p1).unwrap(), b"hello bytes");

        let (p2, _f2) = create_upload("shot.png").unwrap();
        assert!(p2.to_string_lossy().ends_with("shot-1.png"), "got {}", p2.display());
    }

    #[test]
    fn sanitize_strips_directories() {
        assert_eq!(sanitize("../../etc/passwd"), "passwd");
        assert_eq!(sanitize("/abs/path/x.jpg"), "x.jpg");
        assert_eq!(sanitize(""), "upload");
    }
}
