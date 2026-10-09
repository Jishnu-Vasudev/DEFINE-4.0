import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'api.dart';
import 'nearby.dart';
import 'store.dart';

String uuid4() {
  final r = Random.secure();
  final b = List<int>.generate(16, (_) => r.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40;
  b[8] = (b[8] & 0x3f) | 0x80;
  final h = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
}

class AppState extends ChangeNotifier {
  final store = Store();
  Api? api;
  String? userId, userName, role;
  List<Map<String, dynamic>> channels = [];
  bool connected = false;
  bool ready = false;

  WebSocketChannel? _ws;
  Timer? _ping, _retry, _flushTimer;
  int _backoff = 1;
  bool _flushing = false;
  final _events = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get events => _events.stream;

  bool get loggedIn => api?.jwt != null;

  // Talk mode: false = hold to talk, true = tap to start / tap to stop.
  bool toggleTalk = false;
  Future<void> setToggleTalk(bool v) async {
    toggleTalk = v;
    notifyListeners();
    await store.set('talk_mode', v ? 'toggle' : 'hold');
  }

  // ---- Nearby fallback: 3 failed health pings -> phone-to-phone mesh ----
  bool nearbyMode = false;
  NearbyMesh? mesh;
  Timer? _health;
  int _fails = 0;
  int get nearbyPeers => mesh?.peers.length ?? 0;

  Future<void> _checkHealth() async {
    if (api == null) return;
    if (await api!.health()) {
      _fails = 0;
      if (nearbyMode) _setNearby(false);
    } else if (++_fails >= 3 && !nearbyMode) {
      _setNearby(true);
    }
  }

  void _setNearby(bool on) {
    nearbyMode = on;
    send({'t': 'offline_mode', 'on': on}); // only lands if the socket is still up
    if (on) {
      mesh?.start();
    } else {
      mesh?.stop();
      flush(); // queued offline=1 messages go to the server now
    }
    notifyListeners();
  }

  Future<void> _onNearby(Map<String, dynamic> p) async {
    final m = {...p, 'sender_name': p['name'], 'offline': 1};
    await store.upsert(m, 'delivered');
    if (m['type'] == 'sos') _events.add({'t': 'sos', 'message': m});
    notifyListeners();
  }

  Future<void> init() async {
    await store.open();
    toggleTalk = await store.get('talk_mode') == 'toggle';
    final jwt = await store.get('jwt');
    final host = await store.get('host'), port = int.tryParse(await store.get('port') ?? '');
    if (jwt != null && host != null && port != null) {
      api = Api(host, port, jwt);
      userId = await store.get('uid');
      userName = await store.get('name');
      role = await store.get('role');
      channels = List<Map<String, dynamic>>.from(jsonDecode(await store.get('channels') ?? '[]'));
      _startSession();
    }
    ready = true;
    notifyListeners();
  }

  Future<void> join(String host, int port, String code, String name) async {
    final a = Api(host, port);
    final r = await a.post('/auth/join', {'code': code.trim().toUpperCase(), 'name': name.trim()});
    a.jwt = r['jwt'];
    api = a;
    userId = r['user']['id'];
    userName = r['user']['name'];
    role = r['user']['role'];
    channels = List<Map<String, dynamic>>.from(r['channels']);
    for (final e in {'jwt': a.jwt!, 'host': host, 'port': '$port', 'uid': userId!, 'name': userName!, 'role': role!}.entries) {
      await store.set(e.key, e.value);
    }
    await store.set('channels', jsonEncode(channels));
    _startSession();
    notifyListeners();
  }

  Future<void> logout() async {
    _stop();
    await store.clear();
    api = null;
    channels = [];
    notifyListeners();
  }

  void _startSession() {
    _stop(); // a second join without logout must not stack timers
    _connect();
    _flushTimer = Timer.periodic(const Duration(seconds: 5), (_) => flush());
    _health = Timer.periodic(const Duration(seconds: 4), (_) => _checkHealth());
    mesh = NearbyMesh(name: userName ?? 'BunnyHop', onMessage: _onNearby, onPeersChanged: notifyListeners);
    mesh!.ensurePermissions(); // ask now, not mid-outage
    refreshChannels();
  }

  void _stop() {
    _ping?.cancel();
    _retry?.cancel();
    _flushTimer?.cancel();
    _health?.cancel();
    mesh?.stop();
    nearbyMode = false;
    _fails = 0;
    _ws?.sink.close();
    _ws = null;
    connected = false;
  }

  Future<void> refreshChannels() async {
    try {
      channels = List<Map<String, dynamic>>.from(await api!.get('/me/channels'));
      await store.set('channels', jsonEncode(channels));
      notifyListeners();
    } on ApiError catch (e) {
      if (e.status == 401) logout();
    } catch (_) {}
  }

  // ---- WebSocket with auto-reconnect ----
  void _connect() {
    if (api == null) return;
    try {
      final ws = WebSocketChannel.connect(Uri.parse(api!.wsUrl));
      _ws = ws;
      ws.ready
          .then((_) {
            if (_ws != ws) return;
            connected = true;
            _backoff = 1;
            notifyListeners();
            _ping?.cancel();
            _ping = Timer.periodic(const Duration(seconds: 10), (_) => send({'t': 'ping'}));
            send({'t': 'offline_mode', 'on': nearbyMode});
            flush();
            for (final c in channels) {
              sync(c['id']);
            }
          })
          .catchError((_) => _onDrop(ws));
      ws.stream.listen(_onEvent, onDone: () => _onDrop(ws), onError: (_) => _onDrop(ws));
    } catch (_) {
      _scheduleRetry();
    }
  }

  void _onDrop(WebSocketChannel ws) {
    if (_ws != ws) return;
    _ws = null;
    _ping?.cancel();
    if (connected) {
      connected = false;
      notifyListeners();
    }
    _scheduleRetry();
  }

  void _scheduleRetry() {
    if (api == null) return;
    _retry?.cancel();
    _retry = Timer(Duration(seconds: _backoff), _connect);
    _backoff = min(_backoff * 2, 10);
  }

  void send(Map<String, dynamic> m) => _ws?.sink.add(jsonEncode(m));

  Future<void> _onEvent(dynamic raw) async {
    final Map<String, dynamic> e;
    try {
      e = jsonDecode(raw as String) as Map<String, dynamic>;
    } catch (_) {
      return; // ignore malformed frame instead of killing the stream
    }
    if (e['t'] == 'message') {
      final m = e['message'] as Map<String, dynamic>;
      await store.upsert(m, 'delivered');
      notifyListeners();
    }
    _events.add(e);
  }

  // ---- Messages: write locally first, then send ----
  Future<void> sendText(String channelId, String text, {String type = 'text'}) async {
    final m = {
      'id': uuid4(),
      'channel_id': channelId,
      'sender_id': userId,
      'sender_name': userName,
      'type': type,
      'body': text,
      'created_at': DateTime.now().millisecondsSinceEpoch,
      'offline': nearbyMode ? 1 : 0,
    };
    await store.upsert(m, 'queued');
    if (nearbyMode) {
      mesh?.send({
        for (final k in ['id', 'channel_id', 'type', 'body', 'created_at', 'sender_id']) k: m[k],
        'name': userName,
      });
    }
    notifyListeners();
    flush();
  }

  // SOS goes to the first channel (the team's main channel).
  Future<void> sendSos() async {
    if (channels.isEmpty) return;
    await sendText(channels.first['id'], 'SOS — ${userName ?? 'teammate'} needs help', type: 'sos');
  }

  // Image is queued with its local path; flush uploads it before posting the message.
  Future<void> sendImage(String channelId, String path) async {
    await store.upsert({
      'id': uuid4(),
      'channel_id': channelId,
      'sender_id': userId,
      'sender_name': userName,
      'type': 'image',
      'body': '',
      'media': 'local:$path',
      'created_at': DateTime.now().millisecondsSinceEpoch,
    }, 'queued');
    notifyListeners();
    flush();
  }

  Future<void> flush() async {
    if (_flushing || api == null) return;
    _flushing = true;
    try {
      for (final m in await store.queued()) {
        var media = m['media'] as String? ?? '';
        if (media.startsWith('local:')) {
          media = await api!.upload(media.substring(6));
          await store.db.update('messages', {'media': media}, where: 'id=?', whereArgs: [m['id']]);
        }
        final r = await api!.post('/messages', {
          'id': m['id'],
          'channel_id': m['channel_id'],
          'type': m['type'],
          'body': m['body'],
          'media': media,
          'created_at': m['created_at'],
          'offline': m['offline'],
        });
        // WS echo may already have marked it delivered; don't downgrade
        final cur = await store.db.query('messages', columns: ['status'], where: 'id=?', whereArgs: [m['id']]);
        if (cur.isNotEmpty && cur.first['status'] == 'queued') await store.setStatus(m['id'], 'sent', seq: r['seq']);
        notifyListeners();
      }
    } on ApiError catch (e) {
      if (e.status == 401) logout();
    } catch (_) {
      // offline: stays queued, retried by timer / on reconnect
    } finally {
      _flushing = false;
    }
  }

  Future<void> sync(String channelId) async {
    try {
      final after = await store.maxSeq(channelId);
      final list = await api!.get('/channels/$channelId/messages?after_seq=$after') as List;
      for (final m in list) {
        await store.upsert(Map<String, dynamic>.from(m), 'delivered');
      }
      if (list.isNotEmpty) notifyListeners();
    } catch (_) {}
  }
}
