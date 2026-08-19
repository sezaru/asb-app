import 'package:flutter/material.dart';

import 'theme.dart';

/// A small, dependency-free markdown renderer tuned to the Nocturne palette.
/// Covers what an agent actually emits: paragraphs, bold/italic, inline code,
/// fenced + indented code, bullet/numbered lists, headings, blockquotes, links.
class MdText extends StatelessWidget {
  final String text;
  final TextStyle base;

  /// Mono style for inline code / code fences (defaults derived from [base]).
  final Color? codeColor;
  final Color? codeBg;
  final Color? ruleColor;

  const MdText(
    this.text, {
    super.key,
    required this.base,
    this.codeColor,
    this.codeBg,
    this.ruleColor,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final cCol = codeColor ?? p.n200;
    final cBg = codeBg ?? p.well;
    final blocks = _parseBlocks(text.replaceAll('\r\n', '\n'));
    final widgets = <Widget>[];
    for (var i = 0; i < blocks.length; i++) {
      final b = blocks[i];
      if (i > 0) widgets.add(SizedBox(height: _gap(blocks[i - 1], b)));
      widgets.add(_render(context, b, cCol, cBg));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  double _gap(_Block prev, _Block cur) {
    final tight = (prev.type == _Bt.listItem && cur.type == _Bt.listItem);
    return tight ? 3 : 8;
  }

  Widget _render(BuildContext context, _Block b, Color cCol, Color cBg) {
    final p = context.p;
    switch (b.type) {
      case _Bt.code:
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: cBg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: p.n800),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Text(b.text,
                style: mono(11, height: 1.6, color: cCol)),
          ),
        );
      case _Bt.heading:
        final size = b.level <= 1 ? 17.0 : (b.level == 2 ? 15.5 : 14.0);
        return _inline(context, b.text,
            base.copyWith(fontSize: size, fontWeight: FontWeight.w600), cCol, cBg);
      case _Bt.quote:
        return Container(
          padding: const EdgeInsets.only(left: 10),
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: p.n700, width: 2)),
          ),
          child: _inline(context, b.text,
              base.copyWith(color: p.n400, fontStyle: FontStyle.italic), cCol, cBg),
        );
      case _Bt.listItem:
        final marker = b.ordinal != null ? '${b.ordinal}.' : '•';
        return Padding(
          padding: EdgeInsets.only(left: 2.0 + b.indent * 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: b.ordinal != null ? 20 : 14,
                child: Text(marker,
                    style: base.copyWith(color: base.color?.withValues(alpha: 0.75))),
              ),
              Expanded(child: _inline(context, b.text, base, cCol, cBg)),
            ],
          ),
        );
      case _Bt.paragraph:
        return _inline(context, b.text, base, cCol, cBg);
    }
  }

  Widget _inline(BuildContext context, String src, TextStyle style, Color cCol,
      Color cBg) {
    return Text.rich(
      TextSpan(children: _spans(src, style, cCol, cBg)),
      style: style,
    );
  }

  // ── inline span parsing: **bold** *italic* `code` [text](url) ──────────────
  List<InlineSpan> _spans(String s, TextStyle style, Color cCol, Color cBg) {
    final out = <InlineSpan>[];
    final buf = StringBuffer();
    void flush() {
      if (buf.isNotEmpty) {
        out.add(TextSpan(text: buf.toString(), style: style));
        buf.clear();
      }
    }

    var i = 0;
    while (i < s.length) {
      final c = s[i];
      // inline code
      if (c == '`') {
        final end = s.indexOf('`', i + 1);
        if (end > i) {
          flush();
          out.add(TextSpan(
            text: s.substring(i + 1, end),
            style: mono(style.fontSize == null ? 11 : style.fontSize! - 1.5,
                color: cCol, height: style.height),
          ));
          // a faint background isn't drawable per-span without a painter; the
          // mono face + colour is the affordance.
          i = end + 1;
          continue;
        }
      }
      // bold (** or __)
      if ((c == '*' || c == '_') && i + 1 < s.length && s[i + 1] == c) {
        final tok = '$c$c';
        final end = s.indexOf(tok, i + 2);
        if (end > i) {
          flush();
          out.addAll(_spans(s.substring(i + 2, end),
              style.copyWith(fontWeight: FontWeight.w700), cCol, cBg));
          i = end + 2;
          continue;
        }
      }
      // italic (* or _), not mid-word for _
      if (c == '*' || c == '_') {
        final end = s.indexOf(c, i + 1);
        if (end > i && end != i + 1) {
          flush();
          out.addAll(_spans(s.substring(i + 1, end),
              style.copyWith(fontStyle: FontStyle.italic), cCol, cBg));
          i = end + 1;
          continue;
        }
      }
      // link [text](url) — render text only (no navigation surface here)
      if (c == '[') {
        final close = s.indexOf(']', i + 1);
        if (close > i && close + 1 < s.length && s[close + 1] == '(') {
          final paren = s.indexOf(')', close + 2);
          if (paren > close) {
            flush();
            out.addAll(_spans(s.substring(i + 1, close),
                style.copyWith(decoration: TextDecoration.underline), cCol, cBg));
            i = paren + 1;
            continue;
          }
        }
      }
      buf.write(c);
      i++;
    }
    flush();
    return out;
  }

  // ── block parsing ──────────────────────────────────────────────────────────
  List<_Block> _parseBlocks(String src) {
    final lines = src.split('\n');
    final blocks = <_Block>[];
    final para = <String>[];
    void flushPara() {
      if (para.isNotEmpty) {
        blocks.add(_Block(_Bt.paragraph, para.join(' ').trim()));
        para.clear();
      }
    }

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final trimmed = line.trimLeft();
      // fenced code
      if (trimmed.startsWith('```')) {
        flushPara();
        final body = <String>[];
        i++;
        while (i < lines.length && !lines[i].trimLeft().startsWith('```')) {
          body.add(lines[i]);
          i++;
        }
        blocks.add(_Block(_Bt.code, body.join('\n')));
        continue;
      }
      if (trimmed.isEmpty) {
        flushPara();
        continue;
      }
      // heading
      final h = RegExp(r'^(#{1,6})\s+(.*)$').firstMatch(trimmed);
      if (h != null) {
        flushPara();
        blocks.add(_Block(_Bt.heading, h.group(2)!.trim(), level: h.group(1)!.length));
        continue;
      }
      // horizontal rule → skip as a thin spacer (rare)
      if (RegExp(r'^(---+|\*\*\*+|___+)$').hasMatch(trimmed)) {
        flushPara();
        continue;
      }
      // blockquote
      if (trimmed.startsWith('>')) {
        flushPara();
        blocks.add(_Block(_Bt.quote, trimmed.replaceFirst(RegExp(r'^>\s?'), '')));
        continue;
      }
      // bullet list
      final b = RegExp(r'^([-*+])\s+(.*)$').firstMatch(trimmed);
      if (b != null) {
        flushPara();
        final indent = (line.length - trimmed.length) ~/ 2;
        blocks.add(_Block(_Bt.listItem, b.group(2)!.trim(), indent: indent));
        continue;
      }
      // numbered list
      final n = RegExp(r'^(\d+)\.\s+(.*)$').firstMatch(trimmed);
      if (n != null) {
        flushPara();
        final indent = (line.length - trimmed.length) ~/ 2;
        blocks.add(_Block(_Bt.listItem, n.group(2)!.trim(),
            indent: indent, ordinal: int.tryParse(n.group(1)!)));
        continue;
      }
      para.add(trimmed);
    }
    flushPara();
    return blocks;
  }
}

enum _Bt { paragraph, heading, code, quote, listItem }

class _Block {
  final _Bt type;
  final String text;
  final int level;
  final int indent;
  final int? ordinal;
  _Block(this.type, this.text,
      {this.level = 1, this.indent = 0, this.ordinal});
}
