//! Everything Dart can reach. `flutter_rust_bridge_codegen` scans this module
//! tree and nothing else, so a type is on the boundary if and only if it is
//! reachable from here.

pub mod client;
