import 'dart:async';

import 'package:asb_client/asb_client.dart';
import 'package:flutter/foundation.dart';

enum ConnStatus { connecting, connected, down }

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

  /// Seqs of locally-echoed prompts (phone-origin). The sidecar never mirrors a
  /// phone-injected prompt back as a `user_message`, so we render it optimistically
  /// and mark it "sent from this phone". Kept high so they sort after real seqs.
  final Set<BigInt> phoneEchoSeqs = {};
  BigInt _nextEcho = BigInt.two.pow(62);

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
        for (final m in field0) {
          final s = _bucket(m.id, m.title);
          s.title = m.title;
          s.running = m.running;
          s.lastSeq = m.lastSeq;
        }
      case HostEventDto_Update(:final field0):
        final s = _bucket(field0.session);
        if (s.seenSeqs.add(field0.seq)) {
          s.updates.add(field0);
          if (field0.seq > s.lastSeq) s.lastSeq = field0.seq;
        }
      case HostEventDto_Status(:final session, :final running):
        _bucket(session).running = running;
      case HostEventDto_Permission(:final field0):
        _bucket(field0.session).pending = field0;
      case HostEventDto_PermissionResolved(:final session, :final id):
        final b = _bucket(session);
        if (b.pending?.id == id) b.pending = null;
      case HostEventDto_Disconnected():
        status = ConnStatus.down;
    }
    notifyListeners();
  }

  Future<void> send(String sessionId, String text) async {
    final t = text.trim();
    if (t.isEmpty) return;
    final bucket = _bucket(sessionId);
    final turn = bucket.updates.isEmpty ? BigInt.zero : bucket.updates.last.turn;
    final seq = _nextEcho;
    _nextEcho += BigInt.one;
    phoneEchoSeqs.add(seq);
    bucket.updates.add(UpdateDto(
      session: sessionId,
      seq: seq,
      turn: turn,
      payload: PayloadDto.userMessage(text: t),
    ));
    notifyListeners();
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
