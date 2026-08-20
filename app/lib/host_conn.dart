import 'dart:async';
import 'dart:io';

import 'package:asb_client/asb_client.dart';
import 'package:flutter/foundation.dart';

enum ConnStatus { connecting, connected, down }

/// A resolved host directory: the entries plus where they live, so the browser
/// can show the path and a parent (".." ) affordance.
class HostListing {
  final String dir;
  final String? parent;
  final List<FsEntryDto> entries;
  HostListing(this.dir, this.parent, this.entries);
}

// Wire-level tracing for the multi-client fidelity tests. kDebugMode is a const
// `false` in release builds, so these calls tree-shake out entirely there.
void _trace(String msg) {
  if (kDebugMode) debugPrint(msg);
}

/// One mirrored session's live state, accumulated from the event stream.
class SessionData {
  String title;
  bool running;
  // False for a session the host still has a log for but which is closed in
  // Emacs. Listed as resumable; reopened via `HostConn.openSession`.
  bool open;
  BigInt lastSeq;
  final List<UpdateDto> updates = [];
  // Real sidecar seqs already applied — guards against duplicates when a
  // reconnect replays backlog that overlaps what we already have.
  final Set<BigInt> seenSeqs = {};
  PermissionReqDto? pending;
  // Backend-authoritative knobs (models/modes/thought + slash commands). Null
  // until the host sends its first Config for this session; the header pickers
  // and the composer's command autocomplete read straight off it.
  SessionConfigDto? config;
  SessionData(
      {required this.title,
      this.running = false,
      this.open = true,
      BigInt? lastSeq})
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
  // `connected` flips as soon as `hello` returns, but the first session snapshot
  // arrives a beat later over the event stream. Until it does, we don't yet know
  // whether the host is empty — the UI shows a loading state, not "nothing here".
  bool sessionsLoaded = false;

  // Auto-reconnect: a phone network is expected to drop, so we never sit in a
  // dead state — we retry with backoff and resync via per-session high-water so
  // nothing is lost or duplicated. Manual reconnect just resets the backoff.
  bool _disposed = false;
  Timer? _retry;
  Duration _backoff = const Duration(seconds: 1);
  static const _maxBackoff = Duration(seconds: 15);


  /// The sidecar authoritatively broadcasts every injected prompt back as a
  /// `user_message` (so all clients render it, correctly turn-grouped). We don't
  /// echo optimistically; instead we track prompt text this device sent but
  /// hasn't seen echoed yet, and badge the matching echo "sent from this phone".
  final List<String> _pendingSent = [];
  final Set<BigInt> phoneEchoSeqs = {};

  // Host FS browse / upload are request/reply over the same event stream: each
  // request carries a monotonic `req` id and its reply (FsEntries/UploadDone/
  // FsError) completes the matching waiter. No global state, so concurrent
  // browses never cross.
  BigInt _nextReq = BigInt.zero;
  final Map<BigInt, Completer<HostEventDto>> _fsWaiters = {};

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

  /// Live (mirrored) sessions — the main list.
  List<SessionData> get openSessions =>
      sessions.values.where((s) => s.open).toList();

  /// Closed sessions the host can still reopen, newest-seq first. `key` is the
  /// session id to pass to [openSession].
  List<MapEntry<String, SessionData>> get closedSessions {
    final cs = sessions.entries.where((e) => !e.value.open).toList();
    cs.sort((a, b) => b.value.lastSeq.compareTo(a.value.lastSeq));
    return cs;
  }

  Future<void> connect() async {
    if (_disposed) return;
    _retry?.cancel();
    status = ConnStatus.connecting;
    sessionsLoaded = false;
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
        sessionsLoaded = true;
        for (final m in field0) {
          final s = _bucket(m.id, m.title);
          s.title = m.title;
          s.running = m.running;
          s.open = m.open;
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
      case HostEventDto_Config(:final session, :final config):
        _trace('ASBRECV config sess=$session models=${config.models.length} cmds=${config.commands.length}');
        _bucket(session).config = config;
      case HostEventDto_FsEntries(:final req):
        _fsWaiters.remove(req)?.complete(e);
      case HostEventDto_UploadDone(:final req):
        _fsWaiters.remove(req)?.complete(e);
      case HostEventDto_FsError(:final req):
        _fsWaiters.remove(req)?.complete(e);
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

  /// Start a brand-new session on the host from `prompt` (its first message and
  /// title). `cwd` is an optional host directory; null runs in the host default.
  /// The session mirrors back — a fresh Sessions list with the new open entry,
  /// then its updates.
  Future<void> createSession(String prompt, {String? cwd}) async {
    final t = prompt.trim();
    if (t.isEmpty) return;
    final req = (_nextReq += BigInt.one);
    // Badge our own first prompt when its mirror echoes back, like `send`.
    _pendingSent.add(t);
    _trace('ASBNEW len=${t.length} cwd=$cwd');
    await _session?.newSession(req: req, prompt: t, cwd: cwd);
  }

  /// Reopen a closed session (from [closedSessions]) by id; it resumes on the
  /// host and mirrors back like any live session.
  Future<void> openSession(String sessionId) async {
    _trace('ASBOPEN sess=$sessionId');
    await _session?.openSession(session: sessionId);
  }

  Future<void> answer(PermissionReqDto p, String option) async {
    await _session?.answerPermission(session: p.session, id: p.id, option: option);
    _bucket(p.session).pending = null;
    notifyListeners();
  }

  // The knobs are backend-owned: we send the change as a slash command and let
  // the host echo the new Config back, rather than mutating local state
  // optimistically. Names match the bridge's command table (/model /mode
  // /thought); the arg is the option *id*, not its display name.
  void setModel(String sessionId, String id) => command(sessionId, '/model', id);
  void setThinking(String sessionId, String id) => command(sessionId, '/thought', id);
  void setPermMode(String sessionId, String id) => command(sessionId, '/mode', id);

  Future<void> command(String sessionId, String name, [String? arg]) async {
    _trace('ASBCMD sess=$sessionId name=$name arg=$arg');
    await _session?.command(session: sessionId, name: name, arg: arg);
  }

  /// Browse a directory on the HOST machine (the sidecar's own FS). `path` null
  /// starts at the host user's home. Throws on a host-side error or timeout.
  Future<HostListing> browseHost(String? path) async {
    final sess = _session;
    if (sess == null) throw StateError('not connected');
    final req = (_nextReq += BigInt.one);
    final c = Completer<HostEventDto>();
    _fsWaiters[req] = c;
    try {
      await sess.fsList(req: req, path: path);
      final ev = await c.future.timeout(const Duration(seconds: 20));
      return switch (ev) {
        HostEventDto_FsEntries(:final dir, :final parent, :final entries) =>
          HostListing(dir, parent, entries),
        HostEventDto_FsError(:final message) => throw Exception(message),
        _ => throw Exception('unexpected reply'),
      };
    } finally {
      _fsWaiters.remove(req);
    }
  }

  // Raw bytes on the wire (no base64), so a 4MiB slice is a ~4MiB frame, well
  // under the 8MB cap. Bigger chunks = far fewer per-chunk wire round-trips (4×
  // fewer than 1MiB), and the phone still holds only one slice.
  static const int _uploadChunk = 4 << 20;

  /// Upload the file at `srcPath` to the host as `name`, streaming it in bounded
  /// raw-byte chunks off disk, and return the absolute path where it landed.
  /// Peak memory is ~one chunk regardless of file size.
  /// `onProgress` fires after each chunk with (bytesSent, totalBytes).
  Future<String> uploadFile(String name, String srcPath,
      {void Function(int sent, int total)? onProgress}) async {
    final sess = _session;
    if (sess == null) throw StateError('not connected');
    final req = (_nextReq += BigInt.one);
    final c = Completer<HostEventDto>();
    _fsWaiters[req] = c;
    final raf = await File(srcPath).open();
    try {
      await sess.uploadStart(req: req, name: name);
      final len = await raf.length();
      onProgress?.call(0, len);
      var off = 0;
      while (off < len) {
        final n = (len - off) < _uploadChunk ? (len - off) : _uploadChunk;
        final bytes = await raf.read(n);
        await sess.uploadChunk(req: req, data: bytes);
        off += n;
        onProgress?.call(off, len);
        // A mid-stream host error (e.g. decode failure) short-circuits the loop.
        if (c.isCompleted) break;
      }
      await sess.uploadFinish(req: req);
      final ev = await c.future.timeout(const Duration(minutes: 5));
      return switch (ev) {
        HostEventDto_UploadDone(:final path) => path,
        HostEventDto_FsError(:final message) => throw Exception(message),
        _ => throw Exception('unexpected reply'),
      };
    } finally {
      await raf.close();
      _fsWaiters.remove(req);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _retry?.cancel();
    _sub?.cancel();
    super.dispose();
  }
}
