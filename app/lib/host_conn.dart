import 'dart:async';

import 'package:asb_client/asb_client.dart';
import 'package:flutter/foundation.dart';

enum ConnStatus { connecting, connected, down }

// Wire-level tracing for the multi-client fidelity tests. kDebugMode is a const
// `false` in release builds, so these calls tree-shake out entirely there.
void _trace(String msg) {
  if (kDebugMode) debugPrint(msg);
}

/// One mirrored session's live state, accumulated from the event stream.
class SessionData {
  String title;
  bool running;
  BigInt lastSeq;
  final List<UpdateDto> updates = [];
  // Real sidecar seqs already applied — guards against duplicates when a
  // reconnect replays backlog that overlaps what we already have.
  final Set<BigInt> seenSeqs = {};
  PermissionReqDto? pending;
  SessionData({required this.title, this.running = false, BigInt? lastSeq})
      : lastSeq = lastSeq ?? BigInt.zero;
}

/// Owns the connection to one host: the inbound event stream folded into a
/// per-session view, plus the outbound calls (input/interrupt/answer).
class HostConn extends ChangeNotifier {
  final RustClient client;
  final String hostId;

  RustSession? _session;
  StreamSubscription<HostEventDto>? _sub;
  ConnStatus status = ConnStatus.connecting;
  final Map<String, SessionData> sessions = {};
  String? catchup;

  // Auto-reconnect: a phone network is expected to drop, so we never sit in a
  // dead state — we retry with backoff and resync via per-session high-water so
  // nothing is lost or duplicated. Manual reconnect just resets the backoff.
  bool _disposed = false;
  Timer? _retry;
  Duration _backoff = const Duration(seconds: 1);
  static const _maxBackoff = Duration(seconds: 15);

  // Per-connection agent knobs (UI state; sent as slash commands on change).
  String model = 'Opus';
  String thinking = 'think';
  String permMode = 'Default';

  /// The sidecar authoritatively broadcasts every injected prompt back as a
  /// `user_message` (so all clients render it, correctly turn-grouped). We don't
  /// echo optimistically; instead we track prompt text this device sent but
  /// hasn't seen echoed yet, and badge the matching echo "sent from this phone".
  final List<String> _pendingSent = [];
  final Set<BigInt> phoneEchoSeqs = {};

  bool isPhoneEcho(BigInt seq) => phoneEchoSeqs.contains(seq);

  HostConn({required this.client, required this.hostId}) {
    connect();
  }

  /// A non-connecting connection pre-filled with fixed data — used only by the
  /// `ASB_DEMO` debug harness to exercise the stream UI without a live sidecar.
  HostConn.seeded({
    required this.client,
    required this.hostId,
    required Map<String, SessionData> seed,
  }) {
    status = ConnStatus.connected;
    sessions.addAll(seed);
  }

  List<SessionData> get sessionList => sessions.values.toList();

  Future<void> connect() async {
    if (_disposed) return;
    _retry?.cancel();
    status = ConnStatus.connecting;
    notifyListeners();
    try {
      final s = await client.connect(hostNodeIdHex: hostId);
      // Resync from where we left off: the sidecar replays only updates newer
      // than each session's high-water, and the dedup guard drops any overlap.
      final hw = [
        for (final e in sessions.entries)
          if (e.value.lastSeq > BigInt.zero)
            HighWaterDto(session: e.key, lastSeq: e.value.lastSeq),
      ];
      _trace('ASBHELLO host=$hostId hw=${[for (final h in hw) "${h.session}:${h.lastSeq}"]}');
      await s.hello(highWater: hw);
      _sub = s.events().listen(_onEvent, onDone: _onDropped, onError: (_) => _onDropped());
      _session = s;
      status = ConnStatus.connected;
      _backoff = const Duration(seconds: 1);
      notifyListeners();
    } catch (_) {
      _onDropped();
    }
  }

  void _onDropped() {
    if (_disposed) return;
    _session = null;
    status = ConnStatus.down;
    notifyListeners();
    _retry?.cancel();
    _retry = Timer(_backoff, connect);
    final next = _backoff * 2;
    _backoff = next > _maxBackoff ? _maxBackoff : next;
  }

  Future<void> reconnect() async {
    _backoff = const Duration(seconds: 1);
    await _sub?.cancel();
    await connect();
  }

  SessionData _bucket(String id, [String? title]) =>
      sessions.putIfAbsent(id, () => SessionData(title: title ?? id));

  void _onEvent(HostEventDto e) {
    switch (e) {
      case HostEventDto_Sessions(:final field0):
        _trace('ASBRECV sessions ${[for (final m in field0) "${m.id}:last=${m.lastSeq}:run=${m.running}"]}');
        for (final m in field0) {
          final s = _bucket(m.id, m.title);
          s.title = m.title;
          s.running = m.running;
          s.lastSeq = m.lastSeq;
        }
      case HostEventDto_Update(:final field0):
        final s = _bucket(field0.session);
        final fresh = s.seenSeqs.add(field0.seq);
        _trace('ASBRECV update sess=${field0.session} seq=${field0.seq} turn=${field0.turn} pl=${field0.payload.runtimeType} fresh=$fresh');
        if (fresh) {
          final pl = field0.payload;
          if (pl is PayloadDto_UserMessage && _pendingSent.remove(pl.text)) {
            phoneEchoSeqs.add(field0.seq);
          }
          s.updates.add(field0);
          if (field0.seq > s.lastSeq) s.lastSeq = field0.seq;
        }
      case HostEventDto_Status(:final session, :final running):
        _trace('ASBRECV status sess=$session running=$running');
        _bucket(session).running = running;
      case HostEventDto_Permission(:final field0):
        _trace('ASBRECV permission sess=${field0.session} id=${field0.id}');
        _bucket(field0.session).pending = field0;
      case HostEventDto_PermissionResolved(:final session, :final id):
        _trace('ASBRECV perm-resolved sess=$session id=$id');
        final b = _bucket(session);
        if (b.pending?.id == id) b.pending = null;
      case HostEventDto_Disconnected():
        _trace('ASBRECV disconnected');
        status = ConnStatus.down;
    }
    notifyListeners();
  }

  Future<void> send(String sessionId, String text) async {
    final t = text.trim();
    if (t.isEmpty) return;
    _pendingSent.add(t);
    _trace('ASBSEND sess=$sessionId len=${t.length}');
    await _session?.input(session: sessionId, text: t);
  }

  Future<void> interrupt(String sessionId) async =>
      _session?.interrupt(session: sessionId);

  Future<void> answer(PermissionReqDto p, String option) async {
    await _session?.answerPermission(session: p.session, id: p.id, option: option);
    _bucket(p.session).pending = null;
    notifyListeners();
  }

  void setModel(String v) => _setKnob(() => model = v, '/model $v');
  void setThinking(String v) => _setKnob(() => thinking = v, '/thinking $v');
  void setPermMode(String v) => _setKnob(() => permMode = v, '/permissions $v');

  void _setKnob(VoidCallback apply, String _) {
    apply();
    notifyListeners();
    // The knob is a UI convenience; a live sidecar would carry the matching
    // slash command. Left unsent here until the protocol models it.
  }

  @override
  void dispose() {
    _disposed = true;
    _retry?.cancel();
    _sub?.cancel();
    super.dispose();
  }
}
