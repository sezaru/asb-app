use std::sync::atomic::{AtomicUsize, Ordering};
use std::sync::Arc;

/// Counts currently-connected phone clients. Gates whether an FCM wake is sent
/// (a connected client already has the update live).
#[derive(Clone, Default)]
pub struct Presence(Arc<AtomicUsize>);

impl Presence {
    pub fn new() -> Self {
        Self::default()
    }

    pub fn connected(&self) -> usize {
        self.0.load(Ordering::SeqCst)
    }

    /// Marks one client connected until the returned guard drops.
    pub fn enter(&self) -> PresenceGuard {
        self.0.fetch_add(1, Ordering::SeqCst);
        PresenceGuard(self.0.clone())
    }
}

pub struct PresenceGuard(Arc<AtomicUsize>);

impl Drop for PresenceGuard {
    fn drop(&mut self) {
        self.0.fetch_sub(1, Ordering::SeqCst);
    }
}
