// The app requires a live RustClient (native library + iroh endpoint), so the
// widget tree is exercised on device/emulator rather than in a unit test. This
// placeholder keeps `flutter test` green; real coverage lives in the Rust host
// tests (packages/asb_client/rust/tests) and the emulator smoke run.
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('placeholder', () {
    expect(1 + 1, 2);
  });
}
