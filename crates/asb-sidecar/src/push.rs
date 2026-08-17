use async_trait::async_trait;

/// Sends a wake-only push to a client's token. The real FCM implementation
/// lands in the push plan; the trait is the seam so UnifiedPush can slot in.
#[async_trait]
pub trait PushSender: Send + Sync {
    async fn wake(&self, token: &str, host_id: &str, session: &str, kind: &str);
}

pub struct NoopPush;

#[async_trait]
impl PushSender for NoopPush {
    async fn wake(&self, _token: &str, _host_id: &str, _session: &str, _kind: &str) {}
}
