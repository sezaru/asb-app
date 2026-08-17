//! Host tests for the plain-Rust core. The full pair+connect+mirror path is
//! proven at the protocol layer in `asb-sidecar` (`phone_mirrors_and_injects`);
//! here we cover the logic this crate adds on top: identity + host persistence
//! and node-id -> address round-tripping.

use asb_client::client::Client;

#[tokio::test]
async fn identity_persists_across_reopen() {
    let dir = tempfile::tempdir().unwrap();
    let node_id = {
        let c = Client::open_local(dir.path()).await.unwrap();
        c.node_id()
    };
    let c2 = Client::open_local(dir.path()).await.unwrap();
    assert_eq!(node_id, c2.node_id(), "same dir must yield the same identity");
    assert!(c2.hosts().unwrap().is_empty(), "no hosts paired yet");
}

#[tokio::test]
async fn node_id_round_trips_through_address() {
    let dir = tempfile::tempdir().unwrap();
    let c = Client::open_local(dir.path()).await.unwrap();
    let nid = c.node_id();
    let (id, _addr) = Client::addr_from_node_id(nid).unwrap();
    assert_eq!(*id.as_bytes(), nid);
}
