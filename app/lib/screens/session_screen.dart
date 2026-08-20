import 'package:asb_client/asb_client.dart';
import 'package:extended_text_field/extended_text_field.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

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

/// Control char delimiting an attachment pill-chip in the composer's raw text.
/// The user can't type it, so it never false-matches a real path.
const String _attachFlag = '\u0001';
final RegExp _attachRe = RegExp('\u0001([^\u0001]*)\u0001');

/// Turn the composer's chip tokens (`path`) into `@path` for the wire.
String _expandAttachments(String raw) =>
    raw.replaceAllMapped(_attachRe, (m) => '@${m.group(1)}');

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
  // Follow the stream only when already at the bottom — reading back through an
  // earlier turn is never yanked down by new output. Recomputed from the layout
  // *before* each conn update lands, then honoured after the frame settles.
  bool _pinned = true;

  SessionData get _s =>
      widget.conn.sessions[widget.sessionId] ??
      SessionData(title: widget.sessionId);

  @override
  void initState() {
    super.initState();
    widget.conn.addListener(_followStream);
  }

  void _followStream() {
    if (_scroll.hasClients) {
      final pos = _scroll.position;
      _pinned = pos.maxScrollExtent - pos.pixels < 48;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_pinned && _scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  String? _firstText(List<ContentDto> content) {
    final c = content.where((c) => c.kind == 'text').firstOrNull;
    return c?.text;
  }

  // The default is recomputed every build (never memoised) so a fold that opened
  // because its turn was live collapses itself once the turn lands — an explicit
  // tap, recorded in `_open`, outranks the live default either way.
  bool _foldOpen(String key, bool defOpen) {
    final d = widget.expandAll ? true : defOpen;
    _foldDefault[key] = d;
    return _open[key] ?? d;
  }

  void _toggle(String key) {
    final cur = _open[key] ?? _foldDefault[key] ?? false;
    setState(() => _open[key] = !cur);
  }

  @override
  void dispose() {
    widget.conn.removeListener(_followStream);
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
    // The 44×44 corner buttons sit flush to the edge (9px = 15 − their slack),
    // while the title and breadcrumb keep the content margin of 15.
    return Container(
      padding: const EdgeInsets.fromLTRB(9, 4, 9, 10),
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
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: Text(s.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: ui(15.5, weight: FontWeight.w500, color: p.text, spacing: -0.18)),
                ),
              ),
              NIconButton(
                icon: anyOpen ? Icons.unfold_less : Icons.unfold_more,
                size: 17,
                onTap: _toggleFoldAll,
                color: p.n400,
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: _breadcrumb(p, s),
          ),
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

    final cfg = s.config;
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
        crumb(_optName(cfg?.models, cfg?.currentModel, 'model'), p.text,
            dotted: true, onTap: () => _pickModel()),
        sep(),
        crumb(_optName(cfg?.thoughtLevels, cfg?.currentThought, 'thinking'), p.n300,
            dotted: true, onTap: () => _pickThinking()),
        sep(),
        crumb(_optName(cfg?.modes, cfg?.currentMode, 'mode'), p.n400,
            dotted: true, onTap: () => _pickPerm()),
        sep(),
        crumb(usage, p.n400),
      ],
    );
  }

  // Resolve a current option id to its human label from the backend list; fall
  // back to the raw id, then to a placeholder if the host hasn't reported yet.
  String _optName(List<ConfigOptionDto>? opts, String? current, String placeholder) {
    if (current == null || current.isEmpty) return placeholder;
    final o = opts?.where((o) => o.id == current).firstOrNull;
    return o?.name ?? current;
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
    // Segment the stream by author: a contiguous run of user messages is a "ME"
    // block, everything the agent produces (messages, thoughts, tools, plans,
    // usage) is a "CLAUDE" block. The author separator is the only thing that
    // distinguishes them — the message text itself is styled identically.
    bool isMe(UpdateDto u) => u.payload is PayloadDto_UserMessage;
    final segments = <({bool me, List<UpdateDto> items})>[];
    for (final u in s.updates) {
      if (segments.isEmpty || segments.last.me != isMe(u)) {
        segments.add((me: isMe(u), items: [u]));
      } else {
        segments.last.items.add(u);
      }
    }
    final running = s.running;

    for (var si = 0; si < segments.length; si++) {
      final seg = segments[si];
      if (seg.me) {
        final phone = seg.items.any((u) => widget.conn.isPhoneEcho(u.seq));
        rows.add(_authorDivider(p, me: true, phone: phone));
        for (final u in seg.items) {
          if (u.payload case PayloadDto_UserMessage(:final text)) {
            rows.add(_userRow(p, text));
          }
        }
      } else {
        final live = running && si == segments.length - 1;
        rows.add(_authorDivider(p, me: false, live: live));
        rows.addAll(_claudeBlock(p, seg.items, si, live));
      }
    }
    return rows;
  }

  // Render one agent block: merge tool_call_update into tool_call by id, then
  // collapse contiguous thought/tool runs into a fold group.
  List<Widget> _claudeBlock(Palette p, List<UpdateDto> items, int si, bool live) {
    final rows = <Widget>[];
    final nodes = <_N>[];
    final byId = <String, _N>{};
    for (final u in items) {
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

    List<_N>? group;
    var gi = 0;
    void flush() {
      if (group == null) return;
      gi += 1;
      final key = 'g:$si:$gi';
      final open = _foldOpen(key, live);
      rows.add(_foldSummary(p, key, group!, open));
      if (open) {
        for (var ni = 0; ni < group!.length; ni++) {
          rows.addAll(_emitNode(p, group![ni], '$key:$ni', live));
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
    return rows;
  }

  Widget _authorDivider(Palette p, {required bool me, bool live = false, bool phone = false}) {
    // Speaker headers, straight from the mockup: ME in the negative (coral)
    // tone, CLAUDE in the positive (green) tone, each over its faint tinted rule.
    final label = me ? 'ME' : 'CLAUDE';
    final color = me ? p.neg : p.pos;
    final lineColor = me ? p.negBg : p.posBg;
    return Padding(
      padding: const EdgeInsets.fromLTRB(15, 12, 15, 8),
      child: Row(
        children: [
          Text(label, style: mono(10, weight: FontWeight.w600, color: color, spacing: 1.4)),
          const SizedBox(width: 9),
          Expanded(
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [lineColor, Colors.transparent]),
              ),
            ),
          ),
          const SizedBox(width: 9),
          if (me && phone) ...[
            Icon(Icons.smartphone, size: 11, color: p.n500),
            const SizedBox(width: 4),
            Text('this phone', style: mono(9.5, color: p.n600, spacing: 0.3)),
          ] else if (live)
            Text('now', style: mono(10, weight: FontWeight.w500, color: color, spacing: 1.1)),
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

  List<Widget> _emitNode(Palette p, _N n, String key, bool live) {
    final out = <Widget>[];
    if (n.isThought) {
      final tk = 'th:$key';
      // Expanded while the turn runs — you watch Claude think in real time — then
      // it folds itself away once the turn is done.
      final open = _foldOpen(tk, live);
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
        return _userRow(p, text);
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

  // Styled identically to an agent message — the author is conveyed by the "ME"
  // separator above, not by the message body.
  Widget _userRow(Palette p, String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(15, 0, 15, 14),
      child: MdText(text, base: ui(14.5, color: p.text, height: 1.6)),
    );
  }

  Widget _planCard(Palette p, List<PlanEntryDto> entries) {
    // Status is authoritative now (from agent-shell), not guessed by position:
    // completed rows strike through, the in-progress row is accented, pending
    // rows stay bright and unchecked.
    ({IconData icon, Color mark, Color text, bool strike}) style(String s) => switch (s) {
          'completed' => (icon: Icons.check_circle, mark: p.pos, text: p.n500, strike: true),
          'in_progress' =>
            (icon: Icons.radio_button_checked, mark: p.a300, text: p.text, strike: false),
          _ => (icon: Icons.circle_outlined, mark: p.n600, text: p.n200, strike: false),
        };
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
          for (final e in entries)
            Builder(builder: (_) {
              final st = style(e.status);
              return Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Icon(st.icon, size: 13, color: st.mark),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(e.content,
                          style: ui(12.5,
                              color: st.text,
                              height: 1.5,
                              decoration: st.strike ? TextDecoration.lineThrough : null)),
                    ),
                  ],
                ),
              );
            }),
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
      padding: const EdgeInsets.fromLTRB(9, 8, 9, 10),
      decoration: BoxDecoration(
        color: p.band,
        border: Border(top: BorderSide(color: p.divider)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (running) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Row(
                children: [
                  Icon(Icons.hourglass_bottom, size: 12, color: p.n500),
                  const SizedBox(width: 7),
                  Text('AGENT IS WORKING · STOP IT TO SEND',
                      style: mono(10, weight: FontWeight.w500, color: p.n500, spacing: 0.7)),
                ],
              ),
            ),
            const SizedBox(height: 7),
          ],
          if (_slash)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: _slashMenu(p),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              NIconButton(
                icon: Icons.attach_file,
                size: 19,
                color: p.n400,
                onTap: () => _showAttachMenu(p),
              ),
              const SizedBox(width: 3),
              Expanded(
                child: ExtendedTextField(
                  controller: _input,
                  // Inserted attachment paths render as atomic pill-chips; the
                  // default strut is wrong for WidgetSpans, so clear it.
                  specialTextSpanBuilder: _AttachSpanBuilder(onChipTap: _showPathToast),
                  strutStyle: const StrutStyle(),
                  style: ui(13.5, color: p.text),
                  cursorColor: p.accent,
                  minLines: 1,
                  maxLines: 5,
                  onChanged: (v) {
                    // Rebuild on every keystroke while a slash is being typed so
                    // the command menu re-filters against the current prefix.
                    final on = v.startsWith('/');
                    if (on || on != _slash) setState(() => _slash = on);
                  },
                  onSubmitted: (_) => _send(s),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: running
                        ? 'Agent is working — stop it to send'
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
              // We know the turn state, so mid-turn the send button *becomes* the
              // interrupt button — you can't send anyway (it'd only be refused),
              // but you can forcefully stop the agent from the same spot.
              if (running)
                _SendButton(
                  color: p.neg,
                  icon: Icons.stop,
                  onTap: () => widget.conn.interrupt(widget.sessionId),
                )
              else
                _SendButton(
                  color: p.accent,
                  icon: Icons.arrow_upward,
                  onTap: () => _send(s),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // The command list is the host's, fetched once as Config and matched from
  // memory against the prefix being typed (`/comp` → `/compact`). Empty when the
  // host advertised none or nothing matches — then the menu simply doesn't show.
  Widget _slashMenu(Palette p) {
    String display(CommandInfoDto c) => c.name.startsWith('/') ? c.name : '/${c.name}';
    final q = _input.text.split(RegExp(r'\s')).first.toLowerCase();
    final matches = [
      for (final c in _s.config?.commands ?? const <CommandInfoDto>[])
        if (display(c).toLowerCase().startsWith(q)) c,
    ];
    if (matches.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 7),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: p.n800),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final c in matches)
            GestureDetector(
              onTap: () {
                _input.text = '${display(c)} ';
                _input.selection = TextSelection.collapsed(offset: _input.text.length);
                setState(() {});
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
                    Text(display(c), style: mono(11.5, weight: FontWeight.w500, color: p.a300)),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(c.description ?? '',
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
    if (s.running) return; // send is blocked mid-turn — stop the agent first
    final text = _expandAttachments(_input.text).trim();
    if (text.isEmpty) return;
    _input.clear();
    setState(() => _slash = false);
    await widget.conn.send(widget.sessionId, text);
  }

  // ── Attachments (item 7) ─────────────────────────────────────────────────
  // Three sources, all resolving to a HOST path we drop into the composer as an
  // `@path` token: browse the host FS directly, or upload a gallery photo / a
  // phone file (base64 over the wire → landed on the host → path returned).
  void _showAttachMenu(Palette p) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: p.band,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _attachTile(p, Icons.folder_open, 'Host file', 'Browse this machine’s files',
                () { Navigator.pop(ctx); _attachHostFile(); }),
            _attachTile(p, Icons.image_outlined, 'Photo', 'Upload from your gallery',
                () { Navigator.pop(ctx); _attachGallery(); }),
            _attachTile(p, Icons.upload_file, 'File', 'Upload a file from this phone',
                () { Navigator.pop(ctx); _attachPhoneFile(); }),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }

  Widget _attachTile(Palette p, IconData icon, String title, String sub, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: p.a300, size: 22),
      title: Text(title, style: ui(14, weight: FontWeight.w600, color: p.text)),
      subtitle: Text(sub, style: ui(11.5, color: p.n500)),
      onTap: onTap,
    );
  }

  Future<void> _attachHostFile() async {
    final path = await showHostBrowser(context, widget.conn);
    if (path != null) _insertAttachment(path);
  }

  Future<void> _attachGallery() async {
    final x = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (x == null) return;
    if (!mounted) return;
    await _uploadPathAndInsert(x.name, x.path);
  }

  Future<void> _attachPhoneFile() async {
    // withData:false → we get a filesystem path and stream it off disk, rather
    // than loading the whole file into memory.
    final res = await FilePicker.platform.pickFiles();
    if (res == null || res.files.isEmpty) return;
    final f = res.files.first;
    final path = f.path;
    if (!mounted) return;
    if (path == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Couldn’t read that file.')),
      );
      return;
    }
    await _uploadPathAndInsert(f.name, path);
  }

  Future<void> _uploadPathAndInsert(String name, String srcPath) async {
    final messenger = ScaffoldMessenger.of(context);
    final progress = ValueNotifier<double>(0);
    final sw = Stopwatch()..start();
    messenger.showSnackBar(SnackBar(
      duration: const Duration(minutes: 30),
      content: ValueListenableBuilder<double>(
        valueListenable: progress,
        builder: (_, v, _) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Uploading $name… ${(v * 100).toStringAsFixed(0)}%'),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(value: v <= 0 ? null : v),
            ),
          ],
        ),
      ),
    ));
    try {
      var total = 0;
      final path = await widget.conn.uploadFile(name, srcPath,
          onProgress: (sent, t) {
        total = t;
        if (t > 0) progress.value = sent / t;
      });
      sw.stop();
      messenger.hideCurrentSnackBar();
      _insertAttachment(path);
      final secs = sw.elapsedMilliseconds / 1000.0;
      final mb = total / (1024 * 1024);
      final rate = secs > 0 ? mb / secs : 0;
      messenger.showSnackBar(SnackBar(
        content: Text('Uploaded $name — ${mb.toStringAsFixed(0)} MB in '
            '${secs.toStringAsFixed(1)}s (${rate.toStringAsFixed(1)} MB/s)'),
        duration: const Duration(seconds: 5),
      ));
    } catch (e) {
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(SnackBar(content: Text('Upload failed: $e')));
    } finally {
      progress.dispose();
    }
  }

  /// Drop an attachment path into the composer at the cursor as an atomic
  /// pill-chip (delimited by control flags that _AttachSpanBuilder renders as a
  /// chip and _send expands to `@path`).
  void _insertAttachment(String path) {
    final token = '$_attachFlag$path$_attachFlag ';
    final text = _input.text;
    final sel = _input.selection;
    final start = sel.start >= 0 ? sel.start : text.length;
    final end = sel.end >= 0 ? sel.end : text.length;
    final next = text.replaceRange(start, end, token);
    _input.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: start + token.length),
    );
    setState(() {});
  }

  void _showPathToast(String path) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(path), duration: const Duration(seconds: 2)),
    );
  }

  // ── Pickers ────────────────────────────────────────────────────────────────
  // All three are backend-driven: options and the current selection come from
  // the session's Config; picking sends the matching slash command and the host
  // echoes a new Config back. When the host hasn't reported a list yet, there's
  // nothing to choose — say so instead of offering stale hardcoded values.
  Future<void> _pickOption(
    String title,
    String command,
    List<ConfigOptionDto>? opts,
    String? current,
    void Function(String id) apply,
  ) async {
    if (opts == null || opts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$title isn’t available — the host hasn’t reported it yet.')),
      );
      return;
    }
    final v = await showNPicker<String>(
      context: context,
      title: title,
      command: command,
      current: current ?? '',
      footnote: 'sent as $command · session ${widget.sessionId.substring(0, 8)}',
      options: [for (final o in opts) (o.id, o.name, o.description ?? '')],
    );
    if (v != null && v != current) apply(v);
  }

  Future<void> _pickModel() => _pickOption('Model', '/model', _s.config?.models,
      _s.config?.currentModel, (id) => widget.conn.setModel(widget.sessionId, id));

  Future<void> _pickThinking() => _pickOption('Thinking level', '/thought',
      _s.config?.thoughtLevels, _s.config?.currentThought,
      (id) => widget.conn.setThinking(widget.sessionId, id));

  Future<void> _pickPerm() => _pickOption('Permission mode', '/mode', _s.config?.modes,
      _s.config?.currentMode, (id) => widget.conn.setPermMode(widget.sessionId, id));
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
  final IconData icon;
  final VoidCallback? onTap;
  const _SendButton({required this.color, required this.onTap, this.icon = Icons.arrow_upward});
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
        child: Icon(icon, size: 19, color: color),
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

/// A modal file browser over the HOST filesystem. Directories navigate in place;
/// tapping a file pops the sheet with its absolute path. Returns null on cancel.
Future<String?> showHostBrowser(BuildContext context, HostConn conn) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _HostBrowser(conn: conn),
  );
}

class _HostBrowser extends StatefulWidget {
  final HostConn conn;
  const _HostBrowser({required this.conn});
  @override
  State<_HostBrowser> createState() => _HostBrowserState();
}

class _HostBrowserState extends State<_HostBrowser> {
  HostListing? _listing;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load(null);
  }

  Future<void> _load(String? path) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final l = await widget.conn.browseHost(path);
      if (!mounted) return;
      setState(() {
        _listing = l;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, scroll) => Container(
        decoration: BoxDecoration(
          color: p.band,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
              child: Row(
                children: [
                  Icon(Icons.dns_outlined, size: 16, color: p.n500),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _listing?.dir ?? 'Host files',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: mono(11.5, weight: FontWeight.w600, color: p.text),
                    ),
                  ),
                  NIconButton(
                    icon: Icons.close,
                    size: 20,
                    color: p.n400,
                    onTap: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: p.divider),
            Expanded(child: _body(p, scroll)),
          ],
        ),
      ),
    );
  }

  Widget _body(Palette p, ScrollController scroll) {
    if (_loading) {
      return const Center(
        child: Padding(padding: EdgeInsets.all(28), child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Couldn’t browse: $_error',
              textAlign: TextAlign.center, style: ui(12.5, color: p.neg)),
        ),
      );
    }
    final l = _listing!;
    final rows = <Widget>[
      if (l.parent != null) _row(p, Icons.arrow_upward, '..', () => _load(l.parent)),
      for (final e in l.entries)
        _row(
          p,
          e.isDir ? Icons.folder : Icons.insert_drive_file_outlined,
          e.name,
          () => e.isDir ? _load(e.path) : Navigator.pop(context, e.path),
          dir: e.isDir,
        ),
    ];
    if (rows.isEmpty) {
      return Center(child: Text('Empty directory', style: ui(12.5, color: p.n500)));
    }
    return ListView(controller: scroll, children: rows);
  }

  Widget _row(Palette p, IconData icon, String name, VoidCallback onTap, {bool dir = false}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 46),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Icon(icon, size: 18, color: dir ? p.a300 : p.n400),
            const SizedBox(width: 12),
            Expanded(
              child: Text(name,
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: ui(13, color: p.text)),
            ),
            if (dir) Icon(Icons.chevron_right, size: 18, color: p.n600),
          ],
        ),
      ),
    );
  }
}

/// Turns each `path` run in the composer's raw text into an atomic
/// pill-chip. `deleteAll` (ExtendedWidgetSpan default) makes one backspace
/// remove the whole token, and the caret can't land inside it.
class _AttachSpanBuilder extends SpecialTextSpanBuilder {
  final void Function(String path)? onChipTap;
  _AttachSpanBuilder({this.onChipTap});

  @override
  SpecialText? createSpecialText(String flag,
      {TextStyle? textStyle, SpecialTextGestureTapCallback? onTap, required int index}) {
    if (flag.isEmpty) return null;
    if (isStart(flag, _attachFlag)) {
      return _AttachText(textStyle,
          start: index - (_attachFlag.length - 1), onChipTap: onChipTap);
    }
    return null;
  }
}

class _AttachText extends SpecialText {
  final int start;
  final void Function(String path)? onChipTap;
  _AttachText(TextStyle? style, {required this.start, this.onChipTap})
      : super(_attachFlag, _attachFlag, style);

  @override
  InlineSpan finishText() {
    final path = getContent();
    return ExtendedWidgetSpan(
      actualText: toString(),
      start: start,
      alignment: PlaceholderAlignment.middle,
      child: _AttachChip(path: path, onTap: () => onChipTap?.call(path)),
    );
  }
}

class _AttachChip extends StatelessWidget {
  final String path;
  final VoidCallback? onTap;
  const _AttachChip({required this.path, this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final parts = path.split('/').where((s) => s.isNotEmpty);
    final name = parts.isEmpty ? path : parts.last;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 1),
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: p.a900,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: p.a700),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.attach_file, size: 12, color: p.a300),
            const SizedBox(width: 3),
            Text(name, style: mono(11.5, weight: FontWeight.w500, color: p.a300)),
          ],
        ),
      ),
    );
  }
}
