import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../host_conn.dart';
import '../theme.dart';
import '../widgets.dart';
import 'new_session_screen.dart';
import 'session_screen.dart';

class SessionsScreen extends StatefulWidget {
  final String hostId;
  const SessionsScreen({super.key, required this.hostId});
  @override
  State<SessionsScreen> createState() => _SessionsScreenState();
}

class _SessionsScreenState extends State<SessionsScreen> {
  HostConn? _conn;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Inherited widgets (AppScope) are only reachable from here on, not
    // initState. Build the connection once.
    _conn ??= HostConn(client: AppScope.of(context).client, hostId: widget.hostId);
  }

  @override
  void dispose() {
    _conn?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final app = AppScope.of(context);
    final name = app.nicknameFor(widget.hostId);

    return Scaffold(
      backgroundColor: p.bg,
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _conn!,
          builder: (context, _) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _header(p, name),
                Expanded(child: _body(p, name)),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _header(Palette p, String name) {
    final (dot, label, anim) = switch (_conn!.status) {
      ConnStatus.connected => (p.a500, 'connected', false),
      ConnStatus.connecting => (p.n500, 'connecting', true),
      ConnStatus.down => (p.neg, 'disconnected', false),
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(9, 4, 15, 12),
      child: Row(
        children: [
          NIconButton(
            icon: Icons.arrow_back,
            onTap: () => Navigator.of(context).pop(),
            color: p.n300,
          ),
          const SizedBox(width: 3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: ui(16, weight: FontWeight.w500, color: p.text)),
                const SizedBox(height: 3),
                Row(
                  children: [
                    _Dot(color: dot, pulse: anim),
                    const SizedBox(width: 6),
                    Text(label, style: mono(10.5, weight: FontWeight.w500, color: p.n500)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _body(Palette p, String name) {
    switch (_conn!.status) {
      case ConnStatus.connecting:
        return _connecting(p, name);
      case ConnStatus.down:
        return _down(p, name);
      case ConnStatus.connected:
        final list = _conn!.sessionList;
        if (list.isEmpty) {
          return Center(
            child: EmptyState(
              icon: Icons.terminal,
              title: 'Nothing running here',
              body:
                  '$name is connected but has no agent sessions. Start one in Emacs, or open one from here with a first prompt.',
              cta: 'Start a session',
              onCta: _newSession,
            ),
          );
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(11, 0, 11, 14),
          children: [
            for (final s in list) ...[
              _SessionCard(
                data: s,
                id: _idOf(s),
                onOpen: () => _open(s),
                onInterrupt: () => _conn!.interrupt(_idOf(s)),
              ),
              const SizedBox(height: 9),
            ],
            const SizedBox(height: 2),
            NButton(
              label: 'New session',
              leading: Icons.add,
              onTap: _newSession,
              block: true,
              minHeight: 46,
              dashed: true,
            ),
          ],
        );
    }
  }

  String _idOf(SessionData s) =>
      _conn!.sessions.entries.firstWhere((e) => e.value == s).key;

  void _open(SessionData s) => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => SessionScreen(conn: _conn!, sessionId: _idOf(s)),
      ));

  void _newSession() => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => NewSessionScreen(conn: _conn!, hostName: AppScope.of(context).nicknameFor(widget.hostId)),
      ));

  Widget _connecting(Palette p, String name) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(26, 0, 26, 22),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 2,
            decoration: BoxDecoration(
                color: p.n900, borderRadius: BorderRadius.circular(2)),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: 0.38,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                      colors: [Colors.transparent, p.accent]),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text('Reaching $name',
              style: ui(20, weight: FontWeight.w500, color: p.text, height: 1.3, spacing: -0.4)),
          const SizedBox(height: 8),
          Text(
              'Finding a direct route over iroh. This usually takes a few seconds.',
              style: ui(13.5, color: p.n400, height: 1.65)),
          const SizedBox(height: 14),
          _check(p, 'roster verified', true),
          const SizedBox(height: 8),
          _check(p, 'hole punch', true),
          const SizedBox(height: 8),
          _check(p, 'hello · last_seq', false),
          const SizedBox(height: 18),
          NButton(
            label: 'Cancel',
            onTap: () => Navigator.of(context).pop(),
            block: true,
            minHeight: 46,
          ),
        ],
      ),
    );
  }

  Widget _check(Palette p, String label, bool done) {
    return Row(
      children: [
        if (done)
          Icon(Icons.check, size: 13, color: p.a400)
        else
          SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(strokeWidth: 1.5, color: p.accent),
          ),
        const SizedBox(width: 9),
        Text(label, style: mono(11.5, color: done ? p.n500 : p.n300)),
      ],
    );
  }

  Widget _down(Palette p, String name) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(26, 0, 26, 22),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.cloud_off, size: 34, color: p.neg),
          const SizedBox(height: 13),
          Text('Lost the connection',
              style: ui(21, weight: FontWeight.w500, color: p.text, height: 1.3, spacing: -0.4)),
          const SizedBox(height: 13),
          Text(
              'The stream to $name dropped. Anything the agent did meanwhile is kept in the replay log and arrives when you reconnect.',
              style: ui(13.5, color: p.n400, height: 1.65)),
          const SizedBox(height: 17),
          NButton(
            label: 'Reconnect',
            onTap: _conn!.reconnect,
            kind: BtnKind.primary,
            block: true,
            minHeight: 50,
          ),
        ],
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  final SessionData data;
  final String id;
  final VoidCallback onOpen, onInterrupt;
  const _SessionCard(
      {required this.data,
      required this.id,
      required this.onOpen,
      required this.onInterrupt});

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final running = data.running;
    final perm = data.pending != null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: perm ? p.accent : p.n800),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _Dot(color: running ? p.accent : p.n600, pulse: running),
                  const SizedBox(width: 8),
                  Text(running ? 'RUNNING' : 'IDLE',
                      style: mono(10,
                          weight: FontWeight.w500,
                          color: running ? p.a300 : p.n600,
                          spacing: 1.0)),
                  const Spacer(),
                  if (running)
                    NButton(
                      label: 'STOP',
                      leading: Icons.stop,
                      onTap: onInterrupt,
                      minHeight: 30,
                      fontSize: 10,
                      gap: 5,
                      tint: p.neg,
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(data.title,
                  style: ui(15, weight: FontWeight.w500, color: p.text, height: 1.4)),
              if (perm) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: p.a900,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: p.a700),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.pan_tool_outlined, size: 14, color: p.a300),
                      const SizedBox(width: 8),
                      Text('Waiting on you — permission',
                          style: ui(11.5, weight: FontWeight.w500, color: p.a300)),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Text('seq ${data.lastSeq} · ${id.length >= 8 ? id.substring(0, 8) : id}',
                  style: mono(10, color: p.n600)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Dot extends StatefulWidget {
  final Color color;
  final bool pulse;
  const _Dot({required this.color, this.pulse = false});
  @override
  State<_Dot> createState() => _DotState();
}

class _DotState extends State<_Dot> with SingleTickerProviderStateMixin {
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
      width: 7,
      height: 7,
      decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
    );
    if (!widget.pulse) return dot;
    return FadeTransition(
      opacity: Tween(begin: 1.0, end: 0.28).animate(
          CurvedAnimation(parent: _c, curve: Curves.easeInOut)),
      child: dot,
    );
  }
}
