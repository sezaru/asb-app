import 'package:flutter/material.dart';

import 'theme.dart';

/// The `.btn` family from the design system. `kind` maps to primary/secondary/
/// ghost; [block] stretches full-width; [icon] makes a square icon button.
enum BtnKind { primary, secondary, ghost }

class NButton extends StatelessWidget {
  final String? label;
  final IconData? leading;
  final VoidCallback? onTap;
  final BtnKind kind;
  final bool block;
  final double minHeight;
  final double fontSize;
  final bool dashed;
  final Color? tint; // overrides border+text (e.g. destructive)
  final double gap;

  const NButton({
    super.key,
    this.label,
    this.leading,
    required this.onTap,
    this.kind = BtnKind.secondary,
    this.block = false,
    this.minHeight = 40,
    this.fontSize = 14,
    this.dashed = false,
    this.tint,
    this.gap = 7,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final Color fg = tint ??
        switch (kind) {
          BtnKind.primary => p.accent,
          BtnKind.ghost => p.accent,
          BtnKind.secondary => p.text,
        };
    final Color? border = switch (kind) {
      BtnKind.primary => tint ?? p.accent,
      BtnKind.secondary => tint ?? p.divider,
      BtnKind.ghost => null,
    };

    final child = Row(
      mainAxisSize: block ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (leading != null) ...[
          Icon(leading, size: fontSize + 2, color: fg),
          SizedBox(width: gap),
        ],
        if (label != null)
          Text(label!, style: ui(fontSize, weight: FontWeight.w500, color: fg)),
      ],
    );

    return _Tappable(
      onTap: onTap,
      borderRadius: 8,
      child: Container(
        constraints: BoxConstraints(minHeight: minHeight),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: dashed
            ? null
            : BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: border == null
                    ? null
                    : Border.all(color: border, width: 1),
              ),
        foregroundDecoration: dashed
            ? _DashedBorder(color: border ?? p.divider, radius: 8)
            : null,
        child: child,
      ),
    );
  }
}

/// A square icon button (`.btn-icon`), 44×44 tap target like the mock.
class NIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final double size;
  final Color? color;
  final double box;
  const NIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.size = 20,
    this.color,
    this.box = 44,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? context.p.n300;
    return _Tappable(
      onTap: onTap,
      borderRadius: box / 2,
      child: SizedBox(
        width: box,
        height: box,
        child: Icon(icon, size: size, color: c),
      ),
    );
  }
}

/// Uppercase mono section kicker (`RECENT`, `THEME`, `THIS PHONE`, …).
class SectionLabel extends StatelessWidget {
  final String text;
  const SectionLabel(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Text(
        text,
        style: mono(10, weight: FontWeight.w500, color: context.p.n600, spacing: 1.0),
      );
}

/// A big empty state: mono cross-hatch tile + title + body + primary CTA.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final String cta;
  final VoidCallback onCta;
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    required this.cta,
    required this.onCta,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    return Padding(
      padding: const EdgeInsets.fromLTRB(26, 0, 26, 22),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 82,
            height: 82,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: p.n800),
            ),
            foregroundDecoration: _Hatch(a: p.surface, b: p.bg),
            child: Icon(icon, size: 30, color: p.n600),
          ),
          const SizedBox(height: 22),
          Text(title,
              style: ui(23, weight: FontWeight.w500, color: p.text, height: 1.25, spacing: -0.4)),
          const SizedBox(height: 12),
          Text(body, style: ui(13.5, color: p.n400, height: 1.65)),
          const SizedBox(height: 22),
          NButton(
            label: cta,
            onTap: onCta,
            kind: BtnKind.primary,
            block: true,
            minHeight: 52,
            fontSize: 14.5,
          ),
        ],
      ),
    );
  }
}

/// A back/close header row: leading icon button + title (+ optional trailing).
class NavHeader extends StatelessWidget {
  final IconData leadingIcon;
  final VoidCallback onLeading;
  final Widget title;
  final Widget? trailing;
  final EdgeInsets padding;
  const NavHeader({
    super.key,
    this.leadingIcon = Icons.arrow_back,
    required this.onLeading,
    required this.title,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(9, 4, 15, 12),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        children: [
          NIconButton(icon: leadingIcon, onTap: onLeading, color: context.p.n300),
          const SizedBox(width: 3),
          Expanded(child: title),
          ?trailing,
        ],
      ),
    );
  }
}

/// "THIS PHONE" footer (with the short node id) used on Machines/Pair.
class PhoneFooter extends StatelessWidget {
  final String nodeShort;
  final Widget? trailing;
  final bool topBorder;
  const PhoneFooter({super.key, required this.nodeShort, this.trailing, this.topBorder = true});

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 2),
      decoration: topBorder
          ? BoxDecoration(border: Border(top: BorderSide(color: p.divider)))
          : null,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('THIS PHONE',
                    style: mono(10, weight: FontWeight.w500, color: p.n600, spacing: 1.0)),
                const SizedBox(height: 4),
                Text(nodeShort, style: mono(11.5, color: p.n400)),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// A modal bottom sheet picker (model / thinking / permission-mode).
Future<T?> showNPicker<T>({
  required BuildContext context,
  required String title,
  required String command,
  required List<(T value, String label, String hint)> options,
  required T current,
  String? footnote,
}) {
  final p = context.p;
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: p.bg.withValues(alpha: 0.72),
    builder: (ctx) => PaletteScope(
      palette: p,
      child: Container(
        decoration: BoxDecoration(
          color: p.surface,
          border: Border(top: BorderSide(color: p.a700)),
          borderRadius: const BorderRadius.vertical(
              top: Radius.circular(14), bottom: Radius.circular(34)),
        ),
        padding: const EdgeInsets.fromLTRB(15, 12, 15, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                    color: p.n700, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(title, style: ui(13.5, weight: FontWeight.w500, color: p.text)),
                const SizedBox(width: 9),
                Text(command, style: mono(10.5, color: p.n500)),
              ],
            ),
            const SizedBox(height: 10),
            for (final o in options) ...[
              _PickerRow(
                label: o.$2,
                hint: o.$3,
                active: o.$1 == current,
                onTap: () => Navigator.of(ctx).pop(o.$1),
              ),
              const SizedBox(height: 6),
            ],
            if (footnote != null) ...[
              const SizedBox(height: 4),
              Text(footnote, style: mono(10.5, color: p.n500, height: 1.5)),
            ],
          ],
        ),
      ),
    ),
  );
}

class _PickerRow extends StatelessWidget {
  final String label, hint;
  final bool active;
  final VoidCallback onTap;
  const _PickerRow(
      {required this.label, required this.hint, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    return _Tappable(
      onTap: onTap,
      borderRadius: 8,
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
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: ui(13, weight: FontWeight.w500, color: p.text)),
                  const SizedBox(height: 2),
                  Text(hint, style: ui(11, color: p.n500)),
                ],
              ),
            ),
            if (active)
              Icon(Icons.check_circle, size: 18, color: p.accent),
          ],
        ),
      ),
    );
  }
}

/// Shared ripple-free tap wrapper with a subtle pressed tint.
class _Tappable extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double borderRadius;
  const _Tappable({required this.child, required this.onTap, this.borderRadius = 8});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(borderRadius),
        splashColor: context.p.accent.withValues(alpha: 0.10),
        highlightColor: context.p.accent.withValues(alpha: 0.06),
        child: child,
      ),
    );
  }
}

/// A dashed rounded border (for the "Pair a machine" / "New session" buttons).
class _DashedBorder extends Decoration {
  final Color color;
  final double radius;
  const _DashedBorder({required this.color, required this.radius});
  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) =>
      _DashedPainter(color, radius);
}

class _DashedPainter extends BoxPainter {
  final Color color;
  final double radius;
  _DashedPainter(this.color, this.radius);
  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration cfg) {
    final rect = offset & cfg.size!;
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = color;
    final path = Path()..addRRect(rrect);
    const dash = 5.0, gap = 4.0;
    for (final metric in path.computeMetrics()) {
      double d = 0;
      while (d < metric.length) {
        canvas.drawPath(metric.extractPath(d, d + dash), paint);
        d += dash + gap;
      }
    }
  }
}

/// A 45° cross-hatch fill (the empty-state placeholder tiles).
class _Hatch extends Decoration {
  final Color a, b;
  const _Hatch({required this.a, required this.b});
  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) => _HatchPainter(a, b);
}

class _HatchPainter extends BoxPainter {
  final Color a, b;
  _HatchPainter(this.a, this.b);
  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration cfg) {
    final rect = offset & cfg.size!;
    canvas.save();
    canvas.clipRRect(RRect.fromRectAndRadius(rect, const Radius.circular(14)));
    canvas.drawRect(rect, Paint()..color = b);
    final paint = Paint()..color = a..strokeWidth = 8;
    const step = 16.0;
    for (double x = -rect.height; x < rect.width; x += step) {
      canvas.drawLine(
        offset + Offset(x, 0),
        offset + Offset(x + rect.height, rect.height),
        paint,
      );
    }
    canvas.restore();
  }
}
