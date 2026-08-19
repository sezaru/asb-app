import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_controller.dart';
import 'demo_seed.dart';
import 'host_conn.dart';
import 'screens/hosts_screen.dart';
import 'screens/session_screen.dart';
import 'theme.dart';

const _demo = bool.fromEnvironment('ASB_DEMO');

class AsbApp extends StatelessWidget {
  final AppController controller;
  const AsbApp({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return AppScope(
      controller: controller,
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          final sysDark =
              MediaQuery.maybeOf(context)?.platformBrightness == Brightness.dark;
          final palette = controller.theme.resolve(sysDark);
          return MaterialApp(
            title: 'asb',
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              useMaterial3: true,
              brightness: palette.brightness,
              scaffoldBackgroundColor: palette.bg,
              splashFactory: InkSparkle.splashFactory,
            ),
            builder: (context, child) {
              // Keep the OS status-bar icons legible over our ground.
              SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
                statusBarColor: Colors.transparent,
                statusBarIconBrightness: palette.brightness == Brightness.dark
                    ? Brightness.light
                    : Brightness.dark,
                systemNavigationBarColor: palette.bg,
                systemNavigationBarIconBrightness:
                    palette.brightness == Brightness.dark
                        ? Brightness.light
                        : Brightness.dark,
              ));
              return PaletteScope(palette: palette, child: child!);
            },
            home: _demo ? _DemoSession(controller: controller) : const HostsScreen(),
          );
        },
      ),
    );
  }
}

/// Debug harness (ASB_DEMO): opens the stream view on fixed sample data.
class _DemoSession extends StatelessWidget {
  final AppController controller;
  const _DemoSession({required this.controller});
  @override
  Widget build(BuildContext context) {
    final conn = HostConn.seeded(
      client: controller.client,
      hostId: 'demo',
      seed: demoSessions(),
    );
    return SessionScreen(conn: conn, sessionId: 'demo', expandAll: true);
  }
}

