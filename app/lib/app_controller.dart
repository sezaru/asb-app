import 'dart:convert';
import 'dart:io';

import 'package:asb_client/asb_client.dart';
import 'package:flutter/widgets.dart';

import 'theme.dart';

/// App-wide state: the Rust client, this device's node id, host nicknames
/// (stored on-phone only, per the design), and the chosen theme.
class AppController extends ChangeNotifier {
  final RustClient client;
  final String nodeId;
  final File _nickFile;
  Map<String, String> _nicknames;
  ThemeChoice theme = ThemeChoice.system;

  AppController({
    required this.client,
    required this.nodeId,
    required File nickFile,
    required Map<String, String> nicknames,
  })  : _nickFile = nickFile,
        _nicknames = nicknames;

  static Future<AppController> load({
    required RustClient client,
    required String supportDir,
  }) async {
    final f = File('$supportDir/nicknames.json');
    Map<String, String> nicks = {};
    try {
      if (await f.exists()) {
        final raw = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
        nicks = raw.map((k, v) => MapEntry(k, v as String));
      }
    } catch (_) {}
    return AppController(
      client: client,
      nodeId: client.nodeIdHex(),
      nickFile: f,
      nicknames: nicks,
    );
  }

  String nicknameFor(String hostId) =>
      _nicknames[hostId] ?? shortHex(hostId);

  bool hasNickname(String hostId) => _nicknames.containsKey(hostId);

  Future<void> setNickname(String hostId, String name) async {
    _nicknames = {..._nicknames, hostId: name};
    notifyListeners();
    try {
      await _nickFile.writeAsString(jsonEncode(_nicknames));
    } catch (_) {}
  }

  void setTheme(ThemeChoice t) {
    theme = t;
    notifyListeners();
  }
}

class AppScope extends InheritedNotifier<AppController> {
  const AppScope({super.key, required AppController controller, required super.child})
      : super(notifier: controller);

  static AppController of(BuildContext c) =>
      c.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;
}
