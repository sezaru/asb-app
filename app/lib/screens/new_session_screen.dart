import 'package:flutter/material.dart';

import '../host_conn.dart';
import '../theme.dart';
import '../widgets.dart';

class NewSessionScreen extends StatefulWidget {
  final HostConn conn;
  final String hostName;
  const NewSessionScreen({super.key, required this.conn, required this.hostName});
  @override
  State<NewSessionScreen> createState() => _NewSessionScreenState();
}

class _NewSessionScreenState extends State<NewSessionScreen> {
  final _prompt = TextEditingController();
  final _cwd = TextEditingController();
  bool _starting = false;

  @override
  void dispose() {
    _prompt.dispose();
    _cwd.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    final text = _prompt.text.trim();
    if (text.isEmpty || _starting) return;
    setState(() => _starting = true);
    final cwd = _cwd.text.trim();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await widget.conn.createSession(text, cwd: cwd.isEmpty ? null : cwd);
      messenger.showSnackBar(SnackBar(
          content: Text('Starting a session on ${widget.hostName}…')));
      navigator.pop();
    } catch (e) {
      if (mounted) setState(() => _starting = false);
      messenger.showSnackBar(SnackBar(content: Text('Could not start: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    return Scaffold(
      backgroundColor: p.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            NavHeader(
              onLeading: () => Navigator.of(context).pop(),
              title: Text('New session',
                  style: ui(16, weight: FontWeight.w500, color: p.text)),
              padding: const EdgeInsets.fromLTRB(15, 4, 15, 12),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                children: [
                  Text(
                      'Opens a session on ${widget.hostName} and sends this as the first prompt.',
                      style: ui(13, color: p.n400, height: 1.6)),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 5),
                    child: Text('First prompt',
                        style: ui(12, color: p.text.withValues(alpha: 0.7))),
                  ),
                  TextField(
                    controller: _prompt,
                    minLines: 1,
                    maxLines: 4,
                    style: ui(14, color: p.text),
                    cursorColor: p.accent,
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: 'Fix the flaky auth test in packages/api',
                      hintStyle: ui(14, color: p.n600),
                      filled: true,
                      fillColor: p.surface,
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: p.divider)),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: p.accent)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 5),
                    child: Text('Working directory (optional)',
                        style: ui(12, color: p.text.withValues(alpha: 0.7))),
                  ),
                  TextField(
                    controller: _cwd,
                    style: ui(14, color: p.text),
                    cursorColor: p.accent,
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: '~/projects/api  (blank = host home)',
                      hintStyle: ui(14, color: p.n600),
                      filled: true,
                      fillColor: p.surface,
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: p.divider)),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: p.accent)),
                    ),
                  ),
                  const SizedBox(height: 18),
                  NButton(
                    label: _starting ? 'Starting…' : 'Start the session',
                    onTap: _starting ? null : _start,
                    kind: BtnKind.primary,
                    block: true,
                    minHeight: 52,
                    fontSize: 14.5,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

