import 'package:asb_client/asb_client.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'host_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await RustLib.init();
  final dir = await getApplicationSupportDirectory();
  final client = await RustClient.open(dir: dir.path);
  runApp(AsbApp(client: client));
}

class AsbApp extends StatelessWidget {
  final RustClient client;
  const AsbApp({super.key, required this.client});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'asb',
      theme: ThemeData.dark(useMaterial3: true),
      home: HostsPage(client: client),
    );
  }
}

class HostsPage extends StatefulWidget {
  final RustClient client;
  const HostsPage({super.key, required this.client});

  @override
  State<HostsPage> createState() => _HostsPageState();
}

class _HostsPageState extends State<HostsPage> {
  List<String> _hosts = [];
  String _nodeId = '';

  @override
  void initState() {
    super.initState();
    _nodeId = widget.client.nodeIdHex();
    _refresh();
  }

  Future<void> _refresh() async {
    final hosts = await widget.client.hostsHex();
    if (mounted) setState(() => _hosts = hosts);
  }

  Future<void> _pair() async {
    final result = await showDialog<(String, String)>(
      context: context,
      builder: (_) => const _PairDialog(),
    );
    if (result == null) return;
    final (code, hostId) = result;
    try {
      await widget.client.pair(code: code, hostNodeIdHex: hostId);
      await _refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Pairing failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Hosts')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _pair,
        icon: const Icon(Icons.add_link),
        label: const Text('Pair'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const Icon(Icons.smartphone, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: SelectableText(
                    'This device: $_nodeId',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _hosts.isEmpty
                ? const Center(child: Text('No paired hosts yet. Tap Pair.'))
                : ListView(
                    children: [
                      for (final h in _hosts)
                        ListTile(
                          leading: const Icon(Icons.dns),
                          title: Text('${h.substring(0, 16)}…'),
                          subtitle: const Text('tap to connect'),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  HostPage(client: widget.client, hostId: h),
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _PairDialog extends StatefulWidget {
  const _PairDialog();

  @override
  State<_PairDialog> createState() => _PairDialogState();
}

class _PairDialogState extends State<_PairDialog> {
  final _code = TextEditingController();
  final _host = TextEditingController();

  @override
  void dispose() {
    _code.dispose();
    _host.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Pair with a host'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _code,
            decoration: const InputDecoration(labelText: 'Pairing code'),
            autofocus: true,
          ),
          TextField(
            controller: _host,
            decoration: const InputDecoration(labelText: 'Host node id (hex)'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(
            (_code.text.trim(), _host.text.trim()),
          ),
          child: const Text('Pair'),
        ),
      ],
    );
  }
}
