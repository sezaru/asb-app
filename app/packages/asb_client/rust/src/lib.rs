//! asb_client — the Flutter-facing façade over an `asb-protocol` phone client.
//!
//! Two layers, deliberately split (the shape caremate's `roam_flutter` uses):
//!
//! * [`client`] — plain Rust, ordinary `anyhow::Result`, no bridge attributes.
//!   The real logic; host `cargo test` exercises it.
//! * `api` — the `flutter_rust_bridge` shim. Pure delegation + DTO flattening;
//!   it holds no logic, so nothing here can be wrong in a way only a device
//!   would reveal.
//!
//! `frb_generated` is written by `flutter_rust_bridge_codegen generate` and is
//! committed alongside the hand-written code. Regenerate it whenever anything
//! under `api/` changes; the pinned `=2.11.1`, the codegen binary, and the Dart
//! `flutter_rust_bridge` package must all agree.

pub mod api;
pub mod client;

mod frb_generated;
