import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../theme.dart';
import '../widgets.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final app = AppScope.of(context);
    final sysDark =
        MediaQuery.maybeOf(context)?.platformBrightness == Brightness.dark;

    return Scaffold(
      backgroundColor: p.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            NavHeader(
              onLeading: () => Navigator.of(context).pop(),
              title: Text('Settings',
                  style: ui(20, weight: FontWeight.w500, color: p.text, spacing: -0.4)),
              padding: const EdgeInsets.fromLTRB(15, 4, 15, 12),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                children: [
                  const SectionLabel('THEME'),
                  const SizedBox(height: 9),
                  for (final t in ThemeChoice.values) ...[
                    _ThemeRow(
                      choice: t,
                      active: app.theme == t,
                      sysDark: sysDark,
                      onTap: () => app.setTheme(t),
                    ),
                    const SizedBox(height: 7),
                  ],
                  const SizedBox(height: 13),
                  const SectionLabel('THIS PHONE'),
                  const SizedBox(height: 9),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: p.n800),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _kv(p, 'node', shortHex(app.nodeId)),
                        const SizedBox(height: 9),
                        _kv(p, 'push', 'not registered yet'),
                        const SizedBox(height: 9),
                        _kv(p, 'state', 'replay log · on device'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _kv(Palette p, String k, String v) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        SizedBox(width: 42, child: Text(k, style: mono(11.5, color: p.n500))),
        const SizedBox(width: 9),
        Expanded(
          child: Text(v,
              maxLines: 1, overflow: TextOverflow.ellipsis, style: mono(11.5, color: p.n200)),
        ),
      ],
    );
  }
}

class _ThemeRow extends StatelessWidget {
  final ThemeChoice choice;
  final bool active, sysDark;
  final VoidCallback onTap;
  const _ThemeRow({
    required this.choice,
    required this.active,
    required this.sysDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final sw = choice.resolve(sysDark);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: active ? p.a900 : Colors.transparent,
          border: Border.all(color: active ? p.accent : p.n800),
        ),
        child: Row(
          children: [
            // Swatch: the theme's ground with its accent dot.
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: sw.bg,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: sw.n800),
              ),
              child: Center(
                child: Container(
                  width: 8,
                  height: 8,
                  decoration:
                      BoxDecoration(color: sw.accent, shape: BoxShape.circle),
                ),
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(choice.label,
                      style: ui(13.5, weight: FontWeight.w500, color: p.text)),
                  const SizedBox(height: 2),
                  Text(choice.hint(sysDark), style: ui(11, color: p.n500)),
                ],
              ),
            ),
            if (active) Icon(Icons.check_circle, size: 18, color: p.accent),
          ],
        ),
      ),
    );
  }
}
