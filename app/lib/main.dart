import 'package:asb_client/asb_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'app.dart';
import 'app_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  await SystemChrome.setPreferredOrientations(
      [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
  runApp(const Bootstrap());
}

// The frb bridge is process-global and must init exactly once, so a retry after
// a later failure (e.g. RustClient.open) doesn't re-init and throw.
bool _rustInited = false;

/// Bring up the Rust core + controller. Isolated behind [Bootstrap] so a failure
/// here surfaces as a retryable error screen instead of crashing to a blank
/// frame (an unhandled exception in `main` shows nothing on Android).
Future<AppController> _boot() async {
  if (!_rustInited) {
    await RustLib.init();
    _rustInited = true;
  }
  final dir = await getApplicationSupportDirectory();
  final client = await RustClient.open(dir: dir.path);
  return AppController.load(client: client, supportDir: dir.path);
}

/// Runs [_boot], showing a spinner while it works and a retryable error screen
/// if it throws, then hands off to [AsbApp] once the controller is ready.
class Bootstrap extends StatefulWidget {
  const Bootstrap({super.key});
  @override
  State<Bootstrap> createState() => _BootstrapState();
}

class _BootstrapState extends State<Bootstrap> {
  late Future<AppController> _future = _boot();

  void _retry() => setState(() => _future = _boot());

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AppController>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const _BootShell(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return _BootShell(child: _StartupError(error: snap.error!, onRetry: _retry));
        }
        return AsbApp(controller: snap.requireData);
      },
    );
  }
}

/// Minimal self-contained frame for the pre-controller states — deliberately
/// free of the app theme (which needs the controller that may have failed).
class _BootShell extends StatelessWidget {
  final Widget child;
  const _BootShell({required this.child});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFF0F1117),
        body: Center(child: child),
      ),
    );
  }
}

class _StartupError extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;
  const _StartupError({required this.error, required this.onRetry});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Couldn’t start',
              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          Flexible(
            child: SingleChildScrollView(
              child: Text('$error',
                  style: const TextStyle(color: Color(0xFFB4B7C0), fontSize: 13, height: 1.5)),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
