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

  @override
  void dispose() {
    _prompt.dispose();
    super.dispose();
  }

  void _start() {
    if (_prompt.text.trim().isEmpty) return;
    // The protocol mirrors sessions created in Emacs; phone-initiated creation
    // isn't carried yet. Surface that honestly rather than dropping the tap.
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text(
          'Starting a session from the phone isn’t wired to the sidecar yet — '
          'open it in Emacs and it mirrors here.'),
    ));
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
                  const SectionLabel('RECENT'),
                  const SizedBox(height: 8),
                  for (final r in const [
                    'Add pagination to the sessions endpoint',
                    'Why is the relay dropping every 90 seconds?',
                  ]) ...[
                    _RecentChip(text: r, onTap: () => _prompt.text = r),
                    const SizedBox(height: 7),
                  ],
                  const SizedBox(height: 2),
                  NButton(
                    label: 'Start the session',
                    onTap: _start,
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

class _RecentChip extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  const _RecentChip({required this.text, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final p = context.p;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: p.n800),
        ),
        child: Text(text, style: ui(12.5, color: p.n300, height: 1.45)),
      ),
    );
  }
}
