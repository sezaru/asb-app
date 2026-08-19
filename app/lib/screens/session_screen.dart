import 'package:asb_client/asb_client.dart';
import 'package:flutter/material.dart';

import '../host_conn.dart';
import '../markdown.dart';
import '../theme.dart';
import '../widgets.dart';

const _kindLabel = {
  'read': 'Read',
  'edit': 'Edit',
  'command': 'Command',
  'search': 'Search',
  'fetch': 'Fetch',
  'other': 'Tool',
};
const _kindNoun = {
  'read': 'read',
  'edit': 'edited',
  'command': 'ran',
  'search': 'searched',
  'fetch': 'fetched',
  'other': 'used',
};

String _fmtTok(BigInt n) {
  if (n >= BigInt.from(1000)) {
    final s = (n.toDouble() / 1000).toStringAsFixed(1);
    return '${s.endsWith('.0') ? s.substring(0, s.length - 2) : s}k';
  }
  return '$n';
}

class SessionScreen extends StatefulWidget {
  final HostConn conn;
  final String sessionId;
  final bool expandAll; // demo harness: open every fold on first render
  const SessionScreen({
    super.key,
    required this.conn,
    required this.sessionId,
    this.expandAll = false,
  });
  @override
  State<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends State<SessionScreen> {
  final _open = <String, bool>{};
  final _foldDefault = <String, bool>{};
  final _input = TextEditingController();
  final _scroll = ScrollController();
  bool _slash = false;

  SessionData get _s =>
      widget.conn.sessions[widget.sessionId] ??
      SessionData(title: widget.sessionId);

  String? _firstText(List<ContentDto> content) {
    final c = content.where((c) => c.kind == 'text').firstOrNull;
    return c?.text;
  }

  bool _foldOpen(String key, bool defOpen) {
    _foldDefault.putIfAbsent(key, () => widget.expandAll ? true : defOpen);
    return _open[key] ?? _foldDefault[key]!;
  }

  void _toggle(String key) {
    final cur = _open[key] ?? _foldDefault[key] ?? false;
    setState(() => _open[key] = !cur);
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    return Scaffold(
      backgroundColor: p.bg,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: AnimatedBuilder(
          animation: widget.conn,
          builder: (context, _) {
            final s = _s;
            return Column(
              children: [
                _headerBand(p, s),
                Expanded(
                  child: ListView(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(0, 10, 0, 12),
                    children: [
                      ..._buildRows(p, s),
                      if (s.pending != null) _permBar(p, s.pending!),
                    ],
                  ),
                ),
                _composer(p, s),
              ],
            );
          },
        ),
      ),
    );
  }

  // ── Header band ──────────────────────────────────────────────────────────
  Widget _headerBand(Palette p, SessionData s) {
    final anyOpen = _open.values.any((v) => v);
    return Container(
      padding: const EdgeInsets.fromLTRB(15, 4, 15, 10),
      decoration: BoxDecoration(
        color: p.band,
        border: Border(bottom: BorderSide(color: p.divider)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              NIconButton(
                icon: Icons.arrow_back,
                onTap: () => Navigator.of(context).pop(),
                color: p.n300,
              ),
              const SizedBox(width: 3),
              Expanded(
                child: Text(s.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: ui(15.5, weight: FontWeight.w500, color: p.text, spacing: -0.18)),
              ),
              NIconButton(
                icon: anyOpen ? Icons.unfold_less : Icons.unfold_more,
                size: 17,
                onTap: _toggleFoldAll,
                color: p.n400,
              ),
            ],
          ),
          _breadcrumb(p, s),
        ],
      ),
    );
  }

  Widget _breadcrumb(Palette p, SessionData s) {
    final running = s.running;
    final usage = _usage(s);
    Widget sep() => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: Icon(Icons.arrow_right, size: 12, color: p.n700),
        );
    Widget crumb(String text, Color color, {VoidCallback? onTap, bool dotted = false}) {
      final child = Text(text, style: mono(10.5, weight: FontWeight.w500, color: color));
      if (onTap == null) return child;
      return GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: dotted
              ? BoxDecoration(border: Border(bottom: BorderSide(color: p.n700)))
              : null,
          child: child,
        ),
      );
    }

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 0,
      runSpacing: 2,
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 6),
          child: _PulseDot(color: running ? p.accent : p.n700, pulse: running, size: 6),
        ),
        crumb('Claude', p.a300),
        sep(),
        crumb(widget.conn.model, p.text,
            dotted: true, onTap: () => _pickModel()),
        sep(),
        crumb(widget.conn.thinking, p.n300,
            dotted: true, onTap: () => _pickThinking()),
        sep(),
        crumb(widget.conn.permMode, p.n400,
            dotted: true, onTap: () => _pickPerm()),
        sep(),
        crumb(usage, p.n400),
      ],
    );
  }

  String _usage(SessionData s) {
    var i = BigInt.zero, o = BigInt.zero;
    for (final u in s.updates) {
      if (u.payload case PayloadDto_Usage(:final input, :final output)) {
        i += input;
        o += output;
      }
    }
    return i == BigInt.zero ? 'no usage yet' : '${_fmtTok(i)}↑ ${_fmtTok(o)}↓';
  }

  void _toggleFoldAll() {
    final anyOpen = _open.values.any((v) => v);
    setState(() {
      if (anyOpen) {
        _open.updateAll((k, v) => false);
      } else {
        for (final k in _foldDefault.keys) {
          if (k.startsWith('g:')) _open[k] = true;
        }
      }
    });
  }

  // ── Rows ─────────────────────────────────────────────────────────────────
  List<Widget> _buildRows(Palette p, SessionData s) {
    final rows = <Widget>[];
    // group updates by turn (contiguous). The sidecar's raw `turn` is not a
    // stable counter — it resets to 1 whenever the session entry is recreated
    // (e.g. a daemon restart), so we render a 1-based *sequential* index over
    // the contiguous groups instead of the raw value.
    final turns = <List<UpdateDto>>[];
    for (final u in s.updates) {
      if (turns.isEmpty || turns.last.first.turn != u.turn) {
        turns.add([u]);
      } else {
        turns.last.add(u);
      }
    }
    final running = s.running;

    for (var ti = 0; ti < turns.length; ti++) {
      final turn = turns[ti];
      final live = running && ti == turns.length - 1;
      rows.add(_turnDivider(p, ti + 1, live));

      // merge tool_call_update into tool_call by id, keep order
      final nodes = <_N>[];
      final byId = <String, _N>{};
      for (final u in turn) {
        final pl = u.payload;
        if (pl is PayloadDto_ToolCall) {
          final n = _N.tool(pl.id, pl.kind, pl.title, pl.command, pl.status, pl.content);
          n.desc = _firstText(pl.content);
          byId[pl.id] = n;
          nodes.add(n);
        } else if (pl is PayloadDto_ToolCallUpdate) {
          final e = byId[pl.id];
          if (e != null) {
            final done = pl.status == 'done' || pl.status == 'failed';
            if (pl.content.isNotEmpty) {
              // Before completion, content carries the human description of what
              // the tool is doing ("List contents of working directory"); on
              // completion it carries the output. Keep the last description so a
              // command row can show it, and let output land in `content`.
              if (!done) {
                final t = _firstText(pl.content);
                if (t != null && t.isNotEmpty) e.desc = t;
              }
              e.content = pl.content;
            }
            e.status = pl.status;
          } else {
            nodes.add(_N.tool(pl.id, 'other', 'tool update', null, pl.status, pl.content));
          }
        } else {
          nodes.add(_N.payload(pl, u.seq));
        }
      }

      // collapse runs of thought/tool into a fold group
      List<_N>? group;
      var gi = 0;
      void flush() {
        if (group == null) return;
        gi += 1;
        final key = 'g:$ti:$gi';
        final open = _foldOpen(key, live);
        rows.add(_foldSummary(p, key, group!, open));
        if (open) {
          for (var ni = 0; ni < group!.length; ni++) {
            rows.addAll(_emitNode(p, group![ni], '$key:$ni'));
          }
        }
        group = null;
      }

      for (final n in nodes) {
        if (n.isThought || n.isTool) {
          (group ??= <_N>[]).add(n);
          continue;
        }
        flush();
        rows.add(_payloadRow(p, n));
      }
      flush();
    }
    return rows;
  }

  Widget _turnDivider(Palette p, int index, bool live) {
    final color = live ? p.a300 : p.n600;
    return Padding(
      padding: const EdgeInsets.fromLTRB(15, 6, 15, 8),
      child: Row(
        children: [
          Text('TURN $index', style: mono(10, weight: FontWeight.w500, color: color, spacing: 1.1)),
          const SizedBox(width: 9),
          Expanded(
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                    colors: [live ? p.a700 : p.divider, Colors.transparent]),
              ),
            ),
          ),
          const SizedBox(width: 9),
          Text(live ? 'now' : '', style: mono(10, weight: FontWeight.w500, color: color, spacing: 1.1)),
        ],
      ),
    );
  }

  Widget _foldSummary(Palette p, String key, List<_N> group, bool open) {
    final counts = <String, int>{};
    var thought = false;
    for (final n in group) {
      if (n.isThought) {
        thought = true;
      } else {
        counts[n.kind] = (counts[n.kind] ?? 0) + 1;
      }
    }
    final bits = <String>[];
    if (thought) bits.add('Thought');
    counts.forEach((k, n) {
      final noun = _kindNoun[k] ?? 'used';
      final unit = k == 'command'
          ? (n == 1 ? 'command' : 'commands')
          : (n == 1 ? 'file' : 'files');
      bits.add('$noun $n $unit');
    });
    final pending =
        group.any((n) => n.isTool && (n.status == 'running' || n.status == 'pending'));
    final text = bits.join(', ') + (pending ? '…' : '');
    return GestureDetector(
      onTap: () => _toggle(key),
      behavior: HitTestBehavior.opaque,
      child: Container(
        constraints: const BoxConstraints(minHeight: 38),
        padding: const EdgeInsets.symmetric(horizontal: 15),
        child: Row(
          children: [
            Icon(open ? Icons.keyboard_arrow_down : Icons.chevron_right,
                size: 15, color: p.n600),
            const SizedBox(width: 8),
            Expanded(
              child: Text(text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: mono(11.5, color: pending ? p.a300 : p.n600)),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _emitNode(Palette p, _N n, String key) {
    final out = <Widget>[];
    if (n.isThought) {
      final tk = 'th:$key';
      final open = _foldOpen(tk, false);
      out.add(_nodeLine(
        p,
        key: tk,
        expandable: true,
        open: open,
        kind: 'Thought',
        kindColor: p.a300,
        text: n.text,
        textColor: p.n500,
      ));
      // A thought is prose (markdown), not shell output — render it as such.
      if (open) {
        out.add(Padding(
          padding: const EdgeInsets.fromLTRB(27, 2, 15, 8),
          child: MdText(n.text, base: ui(12.5, color: p.n400, height: 1.55)),
        ));
      }
      return out;
    }
    // tool
    final diff = n.content.where((c) => c.kind == 'diff').firstOrNull;
    final txt = n.content.where((c) => c.kind == 'text').firstOrNull;
    final ref = n.content.where((c) => c.kind == 'file_ref').firstOrNull;
    final detailKey = 't:${n.id}';
    final defOpen = n.kind == 'command' && (n.status == 'running' || n.status == 'failed');
    final open = _foldOpen(detailKey, defOpen);
    final expandable = diff != null || txt != null;
    // For a command, the executed line/description is what matters — fall back to
    // the captured description when the agent didn't supply a raw command string.
    final label = n.kind == 'command'
        ? (n.command?.isNotEmpty == true ? n.command! : (n.desc ?? n.title))
        : (n.command ?? ref?.path ?? n.title);

    String plus = '', minus = '';
    if (diff != null) {
      final ls = (diff.diff ?? '').split('\n');
      plus = '+${ls.where((l) => l.startsWith('+')).length}';
      minus = '−${ls.where((l) => l.startsWith('-')).length}';
    }

    out.add(_nodeLine(
      p,
      key: detailKey,
      expandable: expandable,
      open: open,
      status: n.status,
      kind: _kindLabel[n.kind] ?? 'Tool',
      kindColor: p.a300,
      text: label,
      textColor: n.kind == 'edit' ? p.text : p.n400,
      rtl: (ref != null || n.kind == 'edit') && label.contains('/'),
      plus: plus,
      minus: minus,
    ));
    if (open && diff != null) {
      out.add(_diffBlock(p, diff.path ?? '', diff.diff ?? ''));
    } else if (open && txt != null) {
      out.add(_outputBlock(
        p,
        (txt.text ?? '').split('\n').map((l) {
          final err = RegExp(r'FAIL|error|exit 1').hasMatch(l);
          return (line: l, color: err ? p.neg : (l.startsWith(r'$') ? p.n200 : p.n400));
        }).toList(),
      ));
    }
    return out;
  }

  Widget _nodeLine(
    Palette p, {
    required String key,
    required bool expandable,
    required bool open,
    String? status,
    required String kind,
    required Color kindColor,
    required String text,
    required Color textColor,
    bool rtl = false,
    String plus = '',
    String minus = '',
  }) {
    final caret = expandable
        ? (open ? Icons.keyboard_arrow_down : Icons.chevron_right)
        : Icons.fiber_manual_record;
    return GestureDetector(
      onTap: expandable ? () => _toggle(key) : null,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 15),
        constraints: const BoxConstraints(minHeight: 34),
        child: Row(
          children: [
            Icon(caret, size: expandable ? 10 : 6, color: p.n700),
            const SizedBox(width: 8),
            if (status != null) ...[
              _StatusMark(status: status),
              const SizedBox(width: 7),
            ],
            Text(kind, style: mono(11.5, color: kindColor)),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
                style: mono(11.5, color: textColor),
              ),
            ),
            if (plus.isNotEmpty) ...[
              const SizedBox(width: 6),
              Text(plus, style: mono(10.5, color: p.pos)),
              const SizedBox(width: 4),
              Text(minus, style: mono(10.5, color: p.neg)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _diffBlock(Palette p, String path, String diff) {
    return Container(
      margin: const EdgeInsets.fromLTRB(27, 2, 15, 8),
      decoration: BoxDecoration(
        color: p.well,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: p.n800),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: p.divider)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(path,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textDirection: TextDirection.rtl,
                      style: mono(10.5, color: p.n500)),
                ),
                const SizedBox(width: 8),
                Icon(Icons.copy, size: 13, color: p.n500),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final l in diff.split('\n'))
                    Container(
                      width: double.infinity,
                      color: l.startsWith('+')
                          ? p.posBg
                          : l.startsWith('-')
                              ? p.negBg
                              : Colors.transparent,
                      padding: const EdgeInsets.symmetric(horizontal: 9),
                      child: Text(l.isEmpty ? ' ' : l,
                          style: mono(10.5,
                              height: 1.75,
                              color: l.startsWith('+')
                                  ? p.pos
                                  : l.startsWith('-')
                                      ? p.neg
                                      : l.startsWith('@@')
                                          ? p.n500
                                          : p.n400)),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _outputBlock(Palette p, List<({String line, Color color})> lines) {
    return Container(
      margin: const EdgeInsets.fromLTRB(27, 2, 15, 8),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: p.well,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: p.n800),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final l in lines)
              Text(l.line.isEmpty ? ' ' : l.line,
                  style: mono(10.5, height: 1.75, color: l.color)),
          ],
        ),
      ),
    );
  }

  Widget _payloadRow(Palette p, _N n) {
    final pl = n.payload!;
    switch (pl) {
      case PayloadDto_UserMessage(:final text):
        return _userRow(p, text, phone: widget.conn.isPhoneEcho(n.seq));
      case PayloadDto_AgentMessage(:final text):
        return Padding(
          padding: const EdgeInsets.fromLTRB(15, 6, 15, 14),
          child: MdText(text, base: ui(14.5, color: p.text, height: 1.6)),
        );
      case PayloadDto_Plan(:final entries):
        return _planCard(p, entries);
      case PayloadDto_Usage(:final input, :final output):
        return Padding(
          padding: const EdgeInsets.fromLTRB(15, 0, 15, 6),
          child: Row(
            children: [
              Icon(Icons.speed, size: 12, color: p.n500),
              const SizedBox(width: 8),
              Text('usage · in ${_fmtTok(input)} / out ${_fmtTok(output)}',
                  style: mono(10.5, color: p.n500)),
            ],
          ),
        );
      case PayloadDto_Thought(:final text):
        return Padding(
          padding: const EdgeInsets.fromLTRB(15, 6, 15, 8),
          child: MdText(text, base: ui(13.5, color: p.n400, height: 1.5)),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _userRow(Palette p, String text, {bool phone = false}) {
    return Container(
      margin: const EdgeInsets.fromLTRB(15, 0, 15, 10),
      padding: const EdgeInsets.only(left: 11),
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: p.a700, width: 2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MdText(text, base: ui(13.5, color: p.n200, height: 1.5)),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(phone ? Icons.smartphone : Icons.terminal, size: 12, color: p.n500),
              if (phone) ...[
                const SizedBox(width: 5),
                Text('sent from this phone',
                    style: mono(9.5, color: p.n600, spacing: 0.3)),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _planCard(Palette p, List<String> entries) {
    return Container(
      margin: const EdgeInsets.fromLTRB(15, 0, 15, 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: p.n800),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.checklist, size: 13, color: p.n500),
              const SizedBox(width: 7),
              Text('PLAN', style: mono(10, weight: FontWeight.w500, color: p.n500, spacing: 1.0)),
            ],
          ),
          const SizedBox(height: 7),
          for (var i = 0; i < entries.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Icon(i < 2 ? Icons.check_circle : Icons.circle_outlined,
                        size: 13, color: i < 2 ? p.pos : p.n600),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(entries[i],
                        style: ui(12.5,
                            color: i < 2 ? p.n500 : p.n200,
                            height: 1.5,
                            decoration: i < 2 ? TextDecoration.lineThrough : null)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ── Permission ─────────────────────────────────────────────────────────────
  Widget _permBar(Palette p, PermissionReqDto req) {
    int slot(String label) {
      final l = label.toLowerCase();
      if (RegExp(r'deny|reject|\bno\b|cancel').hasMatch(l)) return 0;
      if (RegExp(r"always|session|don't ask").hasMatch(l)) return 1;
      return 2;
    }

    final opts = [
      for (var i = 0; i < req.options.length; i++) (o: req.options[i], i: i, w: slot(req.options[i].label))
    ]..sort((a, b) => a.w != b.w ? a.w - b.w : a.i - b.i);

    return Container(
      margin: const EdgeInsets.fromLTRB(15, 4, 15, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: p.a900,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: p.accent),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _PulseDot(color: p.accent, pulse: true, size: 7),
              const SizedBox(width: 8),
              Text('PERMISSION NEEDED',
                  style: mono(10, weight: FontWeight.w500, color: p.a300, spacing: 1.1)),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
            decoration: BoxDecoration(
              color: p.well,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: p.a700),
            ),
            child: Text(req.command, style: mono(12, color: p.text, height: 1.6)),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (var k = 0; k < opts.length; k++) ...[
                if (k > 0) const SizedBox(width: 7),
                Expanded(
                  flex: opts[k].w == 2 ? 13 : 10,
                  child: NButton(
                    label: opts[k].o.label,
                    onTap: () => widget.conn.answer(req, opts[k].o.id),
                    kind: opts[k].w == 2 ? BtnKind.primary : BtnKind.secondary,
                    minHeight: 44,
                    fontSize: 13,
                    tint: opts[k].w == 0 ? p.neg : null,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Text('id ${req.id.length >= 6 ? req.id.substring(req.id.length - 6) : req.id} · any device can answer',
              style: mono(10.5, color: p.n500)),
        ],
      ),
    );
  }

  // ── Composer ─────────────────────────────────────────────────────────────
  Widget _composer(Palette p, SessionData s) {
    final running = s.running;
    return Container(
      padding: const EdgeInsets.fromLTRB(13, 8, 13, 10),
      decoration: BoxDecoration(
        color: p.band,
        border: Border(top: BorderSide(color: p.divider)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (running) ...[
            Row(
              children: [
                Icon(Icons.hourglass_bottom, size: 12, color: p.n500),
                const SizedBox(width: 7),
                Text('AGENT IS MID-TURN · THE SIDECAR MAY REFUSE',
                    style: mono(10, weight: FontWeight.w500, color: p.n500, spacing: 0.7)),
              ],
            ),
            const SizedBox(height: 7),
          ],
          if (_slash) _slashMenu(p),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              NIconButton(
                icon: Icons.attach_file,
                size: 19,
                color: p.n400,
                onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Attachments aren’t wired yet.')),
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: TextField(
                  controller: _input,
                  style: ui(13.5, color: p.text),
                  cursorColor: p.accent,
                  minLines: 1,
                  maxLines: 5,
                  onChanged: (v) {
                    final on = v.startsWith('/');
                    if (on != _slash) setState(() => _slash = on);
                  },
                  onSubmitted: (_) => _send(s),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: running
                        ? 'Send anyway — it may be refused'
                        : 'Message the agent or /command…',
                    hintStyle: ui(13.5, color: p.n600),
                    filled: true,
                    fillColor: p.surface,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: p.divider)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: p.accent)),
                  ),
                ),
              ),
              const SizedBox(width: 7),
              _SendButton(color: p.accent, onTap: () => _send(s)),
              if (running) ...[
                const SizedBox(width: 7),
                NIconButton(
                  icon: Icons.stop_circle_outlined,
                  size: 20,
                  color: p.neg,
                  onTap: () => widget.conn.interrupt(widget.sessionId),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _slashMenu(Palette p) {
    const items = [
      ('/compact', 'summarise the conversation so far'),
      ('/clear', 'start a fresh context'),
      ('/model', 'switch the model'),
      ('/plan', 'ask for a plan before acting'),
    ];
    return Container(
      margin: const EdgeInsets.only(bottom: 7),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: p.n800),
      ),
      child: Column(
        children: [
          for (final it in items)
            GestureDetector(
              onTap: () {
                _input.text = '${it.$1} ';
                _input.selection = TextSelection.collapsed(offset: _input.text.length);
              },
              behavior: HitTestBehavior.opaque,
              child: Container(
                constraints: const BoxConstraints(minHeight: 40),
                padding: const EdgeInsets.symmetric(horizontal: 11),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: p.divider)),
                ),
                child: Row(
                  children: [
                    Text(it.$1, style: mono(11.5, weight: FontWeight.w500, color: p.a300)),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(it.$2,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: ui(11, color: p.n500)),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _send(SessionData s) async {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    _input.clear();
    setState(() => _slash = false);
    await widget.conn.send(widget.sessionId, text);
  }

  // ── Pickers ────────────────────────────────────────────────────────────────
  Future<void> _pickModel() async {
    final v = await showNPicker<String>(
      context: context,
      title: 'Model',
      command: '/model',
      current: widget.conn.model,
      footnote: 'sent as WireMsg::Command · session ${widget.sessionId.substring(0, 8)}',
      options: const [
        ('Opus', 'Opus', 'deepest reasoning, slowest'),
        ('Sonnet', 'Sonnet', 'the everyday balance'),
        ('Haiku', 'Haiku', 'fast and cheap for small edits'),
      ],
    );
    if (v != null) widget.conn.setModel(v);
  }

  Future<void> _pickThinking() async {
    final v = await showNPicker<String>(
      context: context,
      title: 'Thinking level',
      command: '/thinking',
      current: widget.conn.thinking,
      options: const [
        ('off', 'off', 'answer directly, no visible reasoning'),
        ('think', 'think', 'a short pass before acting'),
        ('think hard', 'think hard', 'longer budget on tricky work'),
      ],
    );
    if (v != null) widget.conn.setThinking(v);
  }

  Future<void> _pickPerm() async {
    final v = await showNPicker<String>(
      context: context,
      title: 'Permission mode',
      command: '/permissions',
      current: widget.conn.permMode,
      options: const [
        ('Default', 'Default', 'ask before anything that writes or runs'),
        ('Accept edits', 'Accept edits', 'file edits go through, commands still ask'),
        ('Bypass', 'Bypass', 'never ask — everything is allowed'),
      ],
    );
    if (v != null) widget.conn.setPermMode(v);
  }
}

/// A merged stream node: either a raw payload, or a tool_call with its updates
/// folded in.
class _N {
  final bool isTool;
  final bool isThought;
  // tool fields
  final String id;
  String kind;
  final String title;
  final String? command;
  String status;
  List<ContentDto> content;
  String? desc; // best human description captured before completion (commands)
  // payload fields
  final PayloadDto? payload;
  final BigInt seq;

  _N.tool(this.id, this.kind, this.title, this.command, this.status, this.content)
      : isTool = true,
        isThought = false,
        payload = null,
        seq = BigInt.zero;

  _N.payload(this.payload, this.seq)
      : isTool = false,
        isThought = payload is PayloadDto_Thought,
        id = '',
        kind = '',
        title = '',
        command = null,
        status = '',
        content = const [];

  String get text => switch (payload) {
        PayloadDto_Thought(:final text) => text,
        _ => '',
      };
}

class _StatusMark extends StatelessWidget {
  final String status;
  const _StatusMark({required this.status});
  @override
  Widget build(BuildContext context) {
    final p = context.p;
    switch (status) {
      case 'running':
        return SizedBox(
          width: 12,
          height: 12,
          child: CircularProgressIndicator(strokeWidth: 1.4, color: p.a300),
        );
      case 'failed':
        return Icon(Icons.close, size: 12, color: p.neg);
      case 'pending':
        return Icon(Icons.circle_outlined, size: 12, color: p.n600);
      default:
        return Icon(Icons.check, size: 12, color: p.n500);
    }
  }
}

class _SendButton extends StatelessWidget {
  final Color color;
  final VoidCallback onTap;
  const _SendButton({required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color),
        ),
        child: Icon(Icons.arrow_upward, size: 19, color: color),
      ),
    );
  }
}

class _PulseDot extends StatefulWidget {
  final Color color;
  final bool pulse;
  final double size;
  const _PulseDot({required this.color, this.pulse = false, this.size = 7});
  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1400))
    ..repeat(reverse: true);
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dot = Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
    );
    if (!widget.pulse) return dot;
    return FadeTransition(
      opacity: Tween(begin: 1.0, end: 0.28)
          .animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut)),
      child: dot,
    );
  }
}
