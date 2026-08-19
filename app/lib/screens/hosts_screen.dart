import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../theme.dart';
import '../widgets.dart';
import 'pair_screen.dart';
import 'sessions_screen.dart';
import 'settings_screen.dart';

class HostsScreen extends StatefulWidget {
  const HostsScreen({super.key});
  @override
  State<HostsScreen> createState() => _HostsScreenState();
}

class _HostsScreenState extends State<HostsScreen> {
  List<String> _hosts = [];
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // AppScope (an inherited widget) is reachable here but not in initState.
    if (!_loaded) {
      _loaded = true;
      _refresh();
    }
  }

  Future<void> _refresh() async {
    final app = AppScope.of(context);
    final hosts = await app.client.hostsHex();
    if (mounted) setState(() => _hosts = hosts);
  }

  Future<void> _pair() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const PairScreen()),
    );
    if (mounted) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final app = AppScope.of(context);
    final empty = _hosts.isEmpty;

    return Scaffold(
      backgroundColor: p.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Machines',
                            style: ui(27,
                                weight: FontWeight.w500,
                                color: p.text,
                                height: 1.1,
                                spacing: -0.75)),
                        const SizedBox(height: 6),
                        Text(
                          empty
                              ? 'direct, encrypted'
                              : '${_hosts.length} paired · direct, encrypted',
                          style: ui(12, color: p.n500),
                        ),
                      ],
                    ),
                  ),
                  NIconButton(
                    icon: Icons.tune,
                    size: 19,
                    color: p.n300,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SettingsScreen()),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: empty
                  ? Center(
                      child: EmptyState(
                        icon: Icons.desktop_windows_outlined,
                        title: 'No machines yet',
                        body:
                            'Pair the desktop your agent runs on. Your phone talks to it directly over an encrypted connection — no account, and nothing stored in between.',
                        cta: 'Scan a pairing code',
                        onCta: _pair,
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(11, 0, 11, 14),
                      children: [
                        for (final h in _hosts) ...[
                          _HostCard(
                            nickname: app.nicknameFor(h),
                            short: shortHex(h),
                            onOpen: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                  builder: (_) => SessionsScreen(hostId: h)),
                            ),
                          ),
                          const SizedBox(height: 9),
                        ],
                        const SizedBox(height: 2),
                        NButton(
                          label: 'Pair a machine',
                          leading: Icons.add,
                          onTap: _pair,
                          kind: BtnKind.secondary,
                          block: true,
                          minHeight: 46,
                          dashed: true,
                        ),
                      ],
                    ),
            ),
            PhoneFooter(nodeShort: shortHex(app.nodeId)),
          ],
        ),
      ),
    );
  }
}

class _HostCard extends StatelessWidget {
  final String nickname, short;
  final VoidCallback onOpen;
  const _HostCard(
      {required this.nickname, required this.short, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: p.n800),
          ),
          child: Row(
            children: [
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                    color: p.n600, borderRadius: BorderRadius.circular(9)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Flexible(
                          child: Text(nickname,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: ui(15.5,
                                  weight: FontWeight.w500, color: p.text)),
                        ),
                        const SizedBox(width: 9),
                        Text(short, style: mono(10.5, color: p.n600)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('Paired · tap to connect',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: ui(12.5, color: p.n500)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, size: 18, color: p.n600),
            ],
          ),
        ),
      ),
    );
  }
}
