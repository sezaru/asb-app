import 'dart:async';

import 'package:asb_client/asb_client.dart';
import 'package:flutter/material.dart';

/// One mirrored session's live state.
class _SessionState {
  String title;
  bool running = false;
  final List<UpdateDto> updates = [];
  PermissionReqDto? pending;
  _SessionState({required this.title});
}

class HostPage extends StatefulWidget {
  final RustClient client;
  final String hostId;
  const HostPage({super.key, required this.client, required this.hostId});

  @override
  State<HostPage> createState() => _HostPageState();
}

class _HostPageState extends State<HostPage> {
  RustSession? _session;
  StreamSubscription<HostEventDto>? _sub;
  final Map<String, _SessionState> _sessions = {};
  String _status = 'connecting…';

  @override
  void initState() {
    super.initState();
    _connect();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _connect() async {
    try {
      final session = await widget.client.connect(hostNodeIdHex: widget.hostId);
      await session.hello(highWater: []);
      _sub = session.events().listen(_onEvent, onDone: () {
        if (mounted) setState(() => _status = 'disconnected');
      });
      if (mounted) {
        setState(() {
          _session = session;
          _status = 'connected';
        });
      }
    } catch (e) {
      if (mounted) setState(() => _status = 'connect failed: $e');
    }
  }

  _SessionState _bucket(String id, [String? title]) =>
      _sessions.putIfAbsent(id, () => _SessionState(title: title ?? id));

  void _onEvent(HostEventDto event) {
    setState(() {
      switch (event) {
        case HostEventDto_Sessions(:final field0):
          for (final m in field0) {
            final s = _bucket(m.id, m.title);
            s.title = m.title;
            s.running = m.running;
          }
        case HostEventDto_Update(:final field0):
          _bucket(field0.session).updates.add(field0);
        case HostEventDto_Status(:final session, :final running):
          _bucket(session).running = running;
        case HostEventDto_Permission(:final field0):
          _bucket(field0.session).pending = field0;
        case HostEventDto_PermissionResolved(:final session, :final id):
          final b = _bucket(session);
          if (b.pending?.id == id) b.pending = null;
        case HostEventDto_Disconnected():
          _status = 'disconnected';
      }
    });
  }

  Future<void> _send(String sessionId, String text) async {
    final s = _session;
    if (s == null || text.trim().isEmpty) return;
    await s.input(session: sessionId, text: text.trim());
  }

  Future<void> _answer(PermissionReqDto p, String option) async {
    final s = _session;
    if (s == null) return;
    await s.answerPermission(session: p.session, id: p.id, option: option);
    setState(() => _bucket(p.session).pending = null);
  }

  Future<void> _interrupt(String sessionId) async {
    await _session?.interrupt(session: sessionId);
  }

  @override
  Widget build(BuildContext context) {
    final ids = _sessions.keys.toList();
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.hostId.substring(0, 12)}…'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(20),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(_status,
                style: Theme.of(context).textTheme.bodySmall),
          ),
        ),
      ),
      body: ids.isEmpty
          ? const Center(child: Text('No sessions yet.'))
          : ListView(
              padding: const EdgeInsets.all(8),
              children: [
                for (final id in ids) _SessionCard(
                  state: _sessions[id]!,
                  onSend: (t) => _send(id, t),
                  onInterrupt: () => _interrupt(id),
                  onAnswer: _answer,
                ),
              ],
            ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  final _SessionState state;
  final void Function(String) onSend;
  final VoidCallback onInterrupt;
  final Future<void> Function(PermissionReqDto, String) onAnswer;
  const _SessionCard({
    required this.state,
    required this.onSend,
    required this.onInterrupt,
    required this.onAnswer,
  });

  @override
  Widget build(BuildContext context) {
    final turns = _groupTurns(state.updates);
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            title: Text(state.title),
            subtitle: Text(state.running ? 'running…' : 'idle'),
            trailing: state.running
                ? IconButton(
                    icon: const Icon(Icons.stop_circle),
                    tooltip: 'Interrupt',
                    onPressed: onInterrupt,
                  )
                : null,
          ),
          for (final turn in turns) _TurnTile(turn: turn),
          if (state.pending != null) _PermissionBar(
            request: state.pending!,
            onAnswer: onAnswer,
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: _InputBar(onSend: onSend, enabled: !state.running),
          ),
        ],
      ),
    );
  }
}

/// A turn: contiguous updates sharing a `turn` id. `turn` is a Rust u64, which
/// frb surfaces to Dart as `BigInt`.
class _Turn {
  final BigInt id;
  final List<UpdateDto> items = [];
  _Turn(this.id);
}

List<_Turn> _groupTurns(List<UpdateDto> updates) {
  final turns = <_Turn>[];
  for (final u in updates) {
    if (turns.isEmpty || turns.last.id != u.turn) {
      turns.add(_Turn(u.turn));
    }
    turns.last.items.add(u);
  }
  return turns;
}

/// Level 1: a turn collapses to one line; expand to see its items.
class _TurnTile extends StatelessWidget {
  final _Turn turn;
  const _TurnTile({required this.turn});

  String get _summary {
    for (final u in turn.items.reversed) {
      final p = u.payload;
      if (p is PayloadDto_AgentMessage) return p.text;
      if (p is PayloadDto_UserMessage) return p.text;
    }
    return '${turn.items.length} step(s)';
  }

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      dense: true,
      leading: const Icon(Icons.chat_bubble_outline, size: 18),
      title: Text(
        _summary,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      children: [for (final n in _mergeNodes(turn.items)) _nodeTile(n)],
    );
  }
}

/// A rendered element within a turn: a standalone payload, or a tool call with
/// its `tool_call_update`s folded in by id (agent-shell shows them as one line).
sealed class _Node {}

class _PayloadNode extends _Node {
  final PayloadDto payload;
  _PayloadNode(this.payload);
}

class _ToolNode extends _Node {
  final String id;
  final String label;
  String status;
  List<ContentDto> content;
  _ToolNode({
    required this.id,
    required this.label,
    required this.status,
    required this.content,
  });
}

/// Fold each `tool_call_update` into the `tool_call` it belongs to (same id),
/// keeping the latest status and content, instead of listing them separately.
List<_Node> _mergeNodes(List<UpdateDto> items) {
  final nodes = <_Node>[];
  final tools = <String, _ToolNode>{};
  for (final u in items) {
    switch (u.payload) {
      case PayloadDto_ToolCall(
          :final id,
          :final kind,
          :final title,
          :final command,
          :final status,
          :final content,
        ):
        final node = _ToolNode(
          id: id,
          label: '$kind · ${command ?? title}',
          status: status,
          content: content,
        );
        tools[id] = node;
        nodes.add(node);
      case PayloadDto_ToolCallUpdate(:final id, :final status, :final content):
        final existing = tools[id];
        if (existing != null) {
          existing.status = status;
          if (content.isNotEmpty) existing.content = content;
        } else {
          // Update before its call (shouldn't happen) — show it standalone.
          final node =
              _ToolNode(id: id, label: 'tool update', status: status, content: content);
          tools[id] = node;
          nodes.add(node);
        }
      default:
        nodes.add(_PayloadNode(u.payload));
    }
  }
  return nodes;
}

Widget _nodeTile(_Node n) {
  if (n is _ToolNode) return _toolItem(n.label, n.status, n.content);
  return _itemTile((n as _PayloadNode).payload);
}

/// Level 2/3: each item collapsed, expandable to its detail.
Widget _itemTile(PayloadDto p) {
  switch (p) {
    case PayloadDto_AgentMessage(:final text):
      return _textItem(Icons.smart_toy, 'agent', text);
    case PayloadDto_Thought(:final text):
      return _textItem(Icons.psychology_alt, 'thinking', text);
    case PayloadDto_UserMessage(:final text):
      return _textItem(Icons.person, 'you', text);
    case PayloadDto_Plan(:final entries):
      return _textItem(Icons.checklist, 'plan', entries.join('\n'));
    case PayloadDto_Usage(:final input, :final output):
      return _textItem(Icons.data_usage, 'usage', 'in $input / out $output');
    case PayloadDto_ToolCall(
        :final kind,
        :final title,
        :final command,
        :final status,
        :final content,
      ):
      return _toolItem('$kind · ${command ?? title}', status, content);
    case PayloadDto_ToolCallUpdate(:final status, :final content):
      return _toolItem('tool update', status, content);
  }
}

Widget _textItem(IconData icon, String label, String text) {
  return ListTile(
    dense: true,
    leading: Icon(icon, size: 16),
    title: Text(label, style: const TextStyle(fontSize: 12)),
    subtitle: Text(text),
  );
}

Widget _toolItem(String title, String status, List<ContentDto> content) {
  return ExpansionTile(
    dense: true,
    leading: const Icon(Icons.build, size: 16),
    title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
    subtitle: Text(status, style: const TextStyle(fontSize: 11)),
    children: [
      for (final c in content)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: SelectableText(
              _contentText(c),
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
        ),
    ],
  );
}

String _contentText(ContentDto c) {
  switch (c.kind) {
    case 'diff':
      return '${c.path ?? ''}\n${c.diff ?? ''}';
    case 'file_ref':
      return c.path ?? '';
    default:
      return c.text ?? '';
  }
}

class _PermissionBar extends StatelessWidget {
  final PermissionReqDto request;
  final Future<void> Function(PermissionReqDto, String) onAnswer;
  const _PermissionBar({required this.request, required this.onAnswer});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.errorContainer,
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Permission: ${request.command}'),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            children: [
              for (final o in request.options)
                FilledButton(
                  onPressed: () => onAnswer(request, o.id),
                  child: Text(o.label),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InputBar extends StatefulWidget {
  final void Function(String) onSend;

  /// The sidecar rejects prompts unless the session is idle, so grey the bar
  /// out while it's running rather than let a tap silently drop.
  final bool enabled;
  const _InputBar({required this.onSend, required this.enabled});

  @override
  State<_InputBar> createState() => _InputBarState();
}

class _InputBarState extends State<_InputBar> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    widget.onSend(_controller.text);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _controller,
            enabled: widget.enabled,
            decoration: InputDecoration(
              hintText: widget.enabled
                  ? 'Send a prompt or /command…'
                  : 'Busy — wait for idle to send…',
              isDense: true,
            ),
            onSubmitted: widget.enabled ? (_) => _submit() : null,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.send),
          onPressed: widget.enabled ? _submit : null,
        ),
      ],
    );
  }
}
