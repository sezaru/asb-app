import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_controller.dart';
import '../theme.dart';
import '../widgets.dart';

class PairScreen extends StatefulWidget {
  const PairScreen({super.key});
  @override
  State<PairScreen> createState() => _PairScreenState();
}

class _PairScreenState extends State<PairScreen> {
  bool _qr = true;
  final _code = TextEditingController();
  final _host = TextEditingController();
  final _nick = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _host.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _code.dispose();
    _host.dispose();
    _nick.dispose();
    super.dispose();
  }

  bool get _validHost {
    final h = _host.text.trim().toLowerCase();
    return h.length == 64 && RegExp(r'^[0-9a-f]{64}$').hasMatch(h);
  }

  Future<void> _pair() async {
    final app = AppScope.of(context);
    final code = _code.text.trim();
    final host = _host.text.trim().toLowerCase();
    if (code.isEmpty || !_validHost) {
      _snack('Enter the pairing code and a valid 64-hex node id.');
      return;
    }
    setState(() => _busy = true);
    try {
      await app.client.pair(code: code, hostNodeIdHex: host);
      final nick = _nick.text.trim();
      if (nick.isNotEmpty) await app.setNickname(host, nick);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      _snack('Pairing failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String m) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final app = AppScope.of(context);
    return Scaffold(
      backgroundColor: p.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            NavHeader(
              leadingIcon: Icons.close,
              onLeading: () => Navigator.of(context).pop(),
              title: Text('Pair a machine',
                  style: ui(15, weight: FontWeight.w500, color: p.text)),
              padding: const EdgeInsets.fromLTRB(15, 4, 18, 0),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
                children: [
                  _Segmented(
                    left: 'Scan a code',
                    right: 'Type it',
                    leftSelected: _qr,
                    onLeft: () => setState(() => _qr = true),
                    onRight: () => setState(() => _qr = false),
                  ),
                  const SizedBox(height: 16),
                  if (_qr) _scan(p) else _manual(p),
                ],
              ),
            ),
            PhoneFooter(
              nodeShort: shortHex(app.nodeId),
              trailing: NButton(
                label: 'COPY',
                leading: Icons.copy,
                fontSize: 10,
                minHeight: 36,
                gap: 5,
                onTap: () {
                  Clipboard.setData(ClipboardData(text: app.nodeId));
                  _snack('Node id copied.');
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _scan(Palette p) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: Container(
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(14)),
            foregroundDecoration: _viewfinder(p),
            child: Center(
              child: Text('CAMERA PREVIEW',
                  style: mono(10.5, weight: FontWeight.w500, color: p.n600, spacing: 1.05)),
            ),
          ),
        ),
        const SizedBox(height: 15),
        Text.rich(
          TextSpan(
            style: ui(13.5, color: p.n300, height: 1.65),
            children: [
              const TextSpan(text: 'Run '),
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                      color: p.surface, borderRadius: BorderRadius.circular(4)),
                  child: Text('asb-sidecar pair', style: mono(12.5, color: p.text)),
                ),
              ),
              const TextSpan(
                  text:
                      ' on the machine and point the camera at the code it prints. The QR carries the pairing code and the node id together.'),
            ],
          ),
        ),
        const SizedBox(height: 15),
        NButton(
          label: 'Enter it by hand instead',
          onTap: () => setState(() => _qr = false),
          kind: BtnKind.primary,
          block: true,
          minHeight: 52,
          fontSize: 14.5,
        ),
      ],
    );
  }

  Widget _manual(Palette p) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Field(
          label: 'Pairing code',
          child: _input(p, _code, 'ABC-123', mono: true),
        ),
        const SizedBox(height: 17),
        _Field(
          label: 'Host node id · 64 hex',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _input(p, _host, '64 hex characters', mono: true, maxLines: 2),
              if (_host.text.trim().isNotEmpty) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(_validHost ? Icons.check_circle : Icons.error_outline,
                        size: 13, color: _validHost ? p.a300 : p.neg),
                    const SizedBox(width: 6),
                    Text(_validHost ? 'Valid ed25519 key' : 'Needs 64 hex characters',
                        style: ui(11, color: _validHost ? p.a300 : p.neg)),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 17),
        _Field(
          label: 'Call it',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _input(p, _nick, 'workbench'),
              const SizedBox(height: 6),
              Text('Stored on this phone only — the protocol carries node ids, not names.',
                  style: ui(11, color: p.n500, height: 1.5)),
            ],
          ),
        ),
        const SizedBox(height: 17),
        NButton(
          label: _busy ? 'Pairing…' : 'Pair',
          onTap: _busy ? null : _pair,
          kind: BtnKind.primary,
          block: true,
          minHeight: 52,
          fontSize: 14.5,
        ),
      ],
    );
  }

  Widget _input(Palette p, TextEditingController c, String hint,
      {bool mono = false, int maxLines = 1}) {
    return TextField(
      controller: c,
      maxLines: maxLines,
      style: mono
          ? monoStyle(14, p.text, spacing: 0.5)
          : ui(14, color: p.text),
      cursorColor: p.accent,
      decoration: InputDecoration(
        isDense: true,
        hintText: hint,
        hintStyle: (mono ? monoStyle(14, p.n600) : ui(14, color: p.n600)),
        filled: true,
        fillColor: p.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        enabledBorder: _border(p.divider),
        focusedBorder: _border(p.accent),
      ),
    );
  }

  OutlineInputBorder _border(Color c) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: c),
      );

  Decoration _viewfinder(Palette p) => _ViewfinderDeco(p);
}

TextStyle monoStyle(double s, Color c, {double? spacing}) =>
    mono(s, color: c, spacing: spacing);

class _Field extends StatelessWidget {
  final String label;
  final Widget child;
  const _Field({required this.label, required this.child});
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 5),
          child: Text(label,
              style: ui(12, color: context.p.text.withValues(alpha: 0.7))),
        ),
        child,
      ],
    );
  }
}

class _Segmented extends StatelessWidget {
  final String left, right;
  final bool leftSelected;
  final VoidCallback onLeft, onRight;
  const _Segmented({
    required this.left,
    required this.right,
    required this.leftSelected,
    required this.onLeft,
    required this.onRight,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: p.divider),
      ),
      child: Row(
        children: [
          _cell(p, left, leftSelected, onLeft, const BorderRadius.horizontal(left: Radius.circular(8))),
          Container(width: 1, height: 34, color: p.divider),
          _cell(p, right, !leftSelected, onRight, const BorderRadius.horizontal(right: Radius.circular(8))),
        ],
      ),
    );
  }

  Widget _cell(Palette p, String text, bool sel, VoidCallback onTap, BorderRadius r) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: r,
            border: sel ? Border.all(color: p.accent) : null,
          ),
          child: Text(text,
              style: ui(13,
                  weight: FontWeight.w500, color: sel ? p.accent : p.n500)),
        ),
      ),
    );
  }
}

/// The scan viewfinder: hatched ground + four accent corner brackets.
class _ViewfinderDeco extends Decoration {
  final Palette p;
  const _ViewfinderDeco(this.p);
  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) => _ViewfinderPainter(p);
}

class _ViewfinderPainter extends BoxPainter {
  final Palette p;
  _ViewfinderPainter(this.p);
  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration cfg) {
    final rect = offset & cfg.size!;
    final rr = RRect.fromRectAndRadius(rect, const Radius.circular(14));
    canvas.save();
    canvas.clipRRect(rr);
    canvas.drawRect(rect, Paint()..color = p.bg);
    final hatch = Paint()..color = p.surface..strokeWidth = 9;
    for (double x = -rect.height; x < rect.width; x += 18) {
      canvas.drawLine(offset + Offset(x, 0),
          offset + Offset(x + rect.height, rect.height), hatch);
    }
    canvas.restore();
    // corner brackets
    final b = Paint()
      ..color = p.accent
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    const m = 32.0, len = 38.0;
    final l = rect.left, t = rect.top, r = rect.right, bt = rect.bottom;
    // TL
    canvas.drawPath(Path()..moveTo(l + m, t + m + len)..lineTo(l + m, t + m)..lineTo(l + m + len, t + m), b);
    // TR
    canvas.drawPath(Path()..moveTo(r - m - len, t + m)..lineTo(r - m, t + m)..lineTo(r - m, t + m + len), b);
    // BL
    canvas.drawPath(Path()..moveTo(l + m, bt - m - len)..lineTo(l + m, bt - m)..lineTo(l + m + len, bt - m), b);
    // BR
    canvas.drawPath(Path()..moveTo(r - m - len, bt - m)..lineTo(r - m, bt - m)..lineTo(r - m, bt - m - len), b);
  }
}
