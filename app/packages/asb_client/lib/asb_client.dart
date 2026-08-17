/// An asb-sidecar phone client, reachable from Dart.
///
/// Call [RustLib.init] once before touching anything else — it loads the native
/// library and starts the Rust side's worker pool. Everything below it is
/// generated; the hand-written surface of this package is exactly this file.
library;

export 'src/rust/api/client.dart';
export 'src/rust/frb_generated.dart' show RustLib;
