import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'api.dart';
import 'dtn.dart';
import 'e2ee/audit_seal.dart';
import 'e2ee/e2ee.dart';
import 'nearby.dart';
import 'store.dart';
import 'theme.dart';

String uuid4() {
  final r = Random.secure();
  final b = List<int>.generate(16, (_) => r.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40;
  b[8] = (b[8] & 0x3f) | 0x80;
  final h = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
}

// Invite QR holds {host, port, code}; a typed code is used as is.
String inviteCode(String raw) {
  try {
    final p = jsonDecode(raw);
    if (p is Map && p['code'] != null) return '${p['code']}'.trim().toUpperCase();
  } catch (_) {}
  return raw.trim().toUpperCase();
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

  // Light/Dark: swaps the palette in [C] and rebuilds the app; kept across sign-out.
  bool get darkMode => C.dark;
  Future<void> setDarkMode(bool v) async {
    C.p = v ? darkPalette : lightPalette;
    notifyListeners();
    await store.set('theme', v ? 'dark' : 'light');
  }

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
  String get meshStatus => mesh?.status ?? 'Off';

  // Failover: health ping every 1.5 s (3 s timeout). 2 misses in a row -> nearby mesh; 2 good
  // answers in a row -> back to the server (hysteresis, so one lost packet does not flap modes).
  int _oks = 0;
  bool _checking = false;
  Future<void> _checkHealth() async {
    if (api == null || _checking) return;
    _checking = true;
    try {
      if (await api!.health()) {
        _fails = 0;
        if (nearbyMode && ++_oks >= 2) _setNearby(false);
      } else {
        _oks = 0;
        if (++_fails >= 2 && !nearbyMode) _setNearby(true);
      }
    } finally {
      _checking = false;
    }
  }

  // Bridge mode: keep the mesh running while connected, so this phone is a gateway for
  // nearby phones that lost the server. Costs some battery; switchable in the side menu.
  bool bridgeMode = true;
  Future<void> setBridgeMode(bool v) async {
    bridgeMode = v;
    if (v) {
      mesh?.start();
    } else if (!nearbyMode) {
      mesh?.stop();
    }
    notifyListeners();
    await store.set('bridge', v ? '1' : '0');
  }

  void _setNearby(bool on) {
    nearbyMode = on;
    send({'t': 'offline_mode', 'on': on}); // only lands if the socket is still up
    mesh?.setOffline(on);
    if (on) {
      mesh?.start();
    } else {
      if (!bridgeMode) mesh?.stop();
      _fails = 0;
      _connect(); // re-open the hub socket right away instead of waiting for the backoff
      flush(); // queued offline=1 messages and carried bundles go to the server now
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
    await bundles.open();
    toggleTalk = await store.get('talk_mode') == 'toggle';
    C.p = await store.get('theme') == 'light' ? lightPalette : darkPalette;
    hwPtt = await store.get('hw_ptt') == '1';
    bridgeMode = await store.get('bridge') != '0';
    _pttChannel = await store.get('ptt_channel');
    final jwt = await store.get('jwt');
    if (jwt != null) {
      api = Api((await store.get('host'))!, int.parse((await store.get('port'))!), jwt);
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

  // Channel whose chat is on screen; joined channels live in [channels].
  String? activeChannelId;
  void openedChannel(String id) {
    activeChannelId = id;
    if (pttChannelId != id) {
      pttChannelId = id;
      store.set('ptt_channel', id);
    }
  }

  // Hardware (volume-key) push-to-talk: on/off, and the channel it talks on (last opened).
  bool hwPtt = false;
  String? _pttChannel;
  String? get pttChannelId => channels.any((c) => c['id'] == _pttChannel) ? _pttChannel : channels.firstOrNull?['id'];
  set pttChannelId(String? v) => _pttChannel = v;
  Future<void> setHwPtt(bool v) async {
    hwPtt = v;
    notifyListeners();
    await store.set('hw_ptt', v ? '1' : '0');
  }

  void closedChannel(String id) {
    if (activeChannelId == id) activeChannelId = null;
  }

  // Join another channel with its invite code (or QR payload) on the same server.
  Future<Map<String, dynamic>> joinChannel(String codeOrQr) async {
    final r = await api!.post('/channels/join', {'code': inviteCode(codeOrQr)});
    final ch = Map<String, dynamic>.from(r);
    if (!channels.any((c) => c['id'] == ch['id'])) channels = [...channels, ch];
    notifyListeners();
    await refreshChannels();
    sync(ch['id']);
    return ch;
  }

  // Leave = drop only me; delete = admin purges it for everyone (server sends channel_deleted).
  Future<void> leaveChannel(String id) async {
    await api!.post('/channels/$id/leave', {});
    await _dropChannel(id, 'left');
  }

  Future<void> deleteChannel(String id) async {
    await api!.delete('/admin/channels/$id');
    await _dropChannel(id, 'deleted');
  }

  // Removes a channel locally and tells open screens (chat pops back to the list).
  Future<void> _dropChannel(String id, String reason, {String? name}) async {
    final ch = channels.where((c) => c['id'] == id).firstOrNull;
    if (ch == null) return;
    channels = channels.where((c) => c['id'] != id).toList();
    await store.set('channels', jsonEncode(channels));
    await store.deleteChannel(id);
    _events.add({'t': 'channel_gone', 'channel_id': id, 'name': name ?? ch['name'] ?? 'Channel', 'reason': reason});
    notifyListeners();
  }

  // Server upload limit (GET /config); the app checks file size before uploading.
  int maxUploadBytes = 25 << 20;
  Future<void> _loadConfig() async {
    final saved = await store.get('audit_key');
    auditKey = saved == null || saved.isEmpty ? null : saved;
    try {
      maxUploadBytes = (await api!.get('/config'))['max_upload_bytes'] as int;
      await _setAuditKey((await api!.get('/audit-key'))['public_key'] as String? ?? '');
    } catch (_) {}
  }

  // Organisation audit (moderation): when the control room publishes a key, every encrypted
  // message is also sealed to it. Shown to the user in the chat header.
  String? auditKey;
  bool get monitored => auditKey != null;
  Future<void> _setAuditKey(String k) async {
    auditKey = k.isEmpty ? null : k;
    await store.set('audit_key', k);
    notifyListeners();
  }

  String? _auditFor(Map<String, dynamic> inner, Map<String, dynamic> m) {
    final k = auditKey;
    if (k == null) return null;
    try {
      return sealForAudit(k, {...inner, 'sender_id': m['sender_id'], 'sender_name': userName, 'created_at': m['created_at']});
    } catch (_) {
      return null;
    }
  }

  Future<void> logout() async {
    _stop();
    await e2ee?.wipe(); // a new sign-in gets a new identity
    await bundles.clear();
    e2ee = null;
    await store.clear();
    await store.set('theme', darkMode ? 'dark' : 'light');
    api = null;
    channels = [];
    notifyListeners();
  }

  void _startSession() {
    _connect();
    _flushTimer = Timer.periodic(const Duration(seconds: 5), (_) => flush());
    _health = Timer.periodic(const Duration(milliseconds: 1500), (_) => _checkHealth());
    mesh = NearbyMesh(
      name: userName ?? 'Bunny Hop',
      onMessage: _onNearby,
      onPeersChanged: notifyListeners,
      carried: bundles.all,
      onBundle: _onBundle,
      onForward: _onForward,
      onAck: _onAck,
    );
    if (bridgeMode) mesh!.start();
    refreshChannels();
    _loadConfig();
    e2ee = E2ee(store.db, api!, userId!);
    e2ee!.init().then((_) => _keySync()).catchError((Object e) => debugPrint('e2ee init: $e'));
  }

  // ---- Store-and-forward bundles (see dtn.dart) ----
  late final bundles = BundleStore(store.db);

  // Offline send: wrap the message as a signed bundle any phone can carry to the server.
  // SOS travels readable; everything else only if it can be end-to-end sealed offline.
  Future<void> _makeBundle(Map<String, dynamic> m) async {
    final e = e2ee;
    if (e == null) return;
    final ch = m['channel_id'] as String;
    String type = 'sos', body = m['body'];
    final audit = m['type'] == 'sos' ? '' : _auditFor({'type': m['type'], 'body': m['body']}, m) ?? '';
    if (m['type'] != 'sos') {
      final sealed = await e.sealOffline(ch, _isDirect(ch), {'type': m['type'], 'body': m['body']});
      if (sealed == null) return; // my own outbox still delivers it once I am back online
      type = 'enc';
      body = sealed;
    }
    final at = m['created_at'] as int;
    final b = Bundle(
      id: m['id'],
      origin: userId!,
      originName: userName ?? '',
      channelId: ch,
      type: type,
      body: body,
      createdAt: at,
      hops: 0,
      sig: await e.sign(Bundle.signedBytes(m['id'], ch, userId!, type, body, at, audit)),
      audit: audit,
    );
    if (await bundles.add(b)) mesh?.pushBundle(b);
  }

  // A bundle arrived over the mesh: keep carrying it, and read it here if it is for me.
  Future<bool> _onBundle(Bundle b) async {
    if (!await bundles.add(b)) return false;
    if (b.origin != userId && channels.any((c) => c['id'] == b.channelId)) {
      final m = {
        'id': b.id,
        'channel_id': b.channelId,
        'sender_id': b.origin,
        'sender_name': b.originName,
        'type': b.type,
        'body': b.body,
        'media': '',
        'created_at': b.createdAt,
        'offline': 1,
      };
      await _ingest(m);
      if (b.type == 'sos') _events.add({'t': 'sos', 'message': m});
      notifyListeners();
    }
    if (!nearbyMode) _uploadBundles(); // gateway: hand it to the server right away
    return true;
  }

  // Gateway passed down a server message (still end-to-end encrypted): open it if it is mine.
  Future<void> _onForward(Map<String, dynamic> m) async {
    if (m['type'] == 'broadcast') {
      _events.add({'t': 'broadcast', 'message': m, 'emergency': m['emergency'] == true});
      return;
    }
    if (!channels.any((c) => c['id'] == m['channel_id']) || m['sender_id'] == userId) return;
    await _ingest(m);
    if (m['type'] == 'sos') _events.add({'t': 'sos', 'message': m});
    notifyListeners();
  }

  // A gateway delivered my bundles: they are on the server, stop treating them as queued.
  Future<void> _onAck(List<String> ids) async {
    var changed = false;
    for (final id in ids) {
      final cur = await store.db.query('messages', columns: ['status', 'sender_id'], where: 'id=?', whereArgs: [id]);
      if (cur.isNotEmpty && cur.first['status'] == 'queued' && cur.first['sender_id'] == userId) {
        await store.setStatus(id, 'sent');
        changed = true;
      }
    }
    if (changed) notifyListeners();
  }

  // Back at the base station: hand in everything this phone carried.
  bool _uploading = false;
  Future<void> _uploadBundles() async {
    if (_uploading || api == null || nearbyMode) return;
    _uploading = true;
    try {
      final list = await bundles.toUpload();
      if (list.isEmpty) return;
      final res = Map<String, dynamic>.from(
        await api!.post('/bundles', {
          'list': [for (final b in list) b.toJson()],
        }),
      );
      // keep only those the server could not check yet (origin has no keys on file)
      await bundles.markUploaded(res.entries.where((e) => e.value != 'no_key' && e.value != 'error').map((e) => e.key));
      // tell the senders (who may still be offline) that their messages arrived
      mesh?.ack([
        for (final e in res.entries)
          if (e.value == 'stored' || e.value == 'duplicate') e.key,
      ]);
    } catch (_) {
    } finally {
      _uploading = false;
    }
  }

  // ---- End-to-end encryption glue (see e2ee/e2ee.dart) ----
  E2ee? e2ee;
  bool _isDirect(String channelId) => channels.any((c) => c['id'] == channelId && c['kind'] == 'dm');

  // Upload/top-up keys and collect sender keys that arrived while offline.
  Future<void> _keySync() async {
    final e = e2ee;
    if (e == null) return;
    try {
      await e.publishKeys();
      for (final k in await api!.get('/keys/inbox') as List) {
        await _onKey(Map<String, dynamic>.from(k));
      }
      for (final c in channels) {
        await _retryPending(c['id']);
      }
    } catch (_) {}
  }

  Future<void> _onKey(Map<String, dynamic> k) async {
    final ch = await e2ee?.onKeyMessage(k);
    if (ch != null) await _retryPending(ch);
  }

  Map<String, dynamic> _opened(Map<String, dynamic> m, Map<String, dynamic> inner) => {
    ...m,
    'type': inner['type'] ?? 'text',
    'body': inner['body'] ?? '',
    'media': inner['media_key'] != null ? 'e2e:${m['media']}|${inner['media_key']}' : '',
  };

  // Every incoming message passes through here; "enc" ones are opened before they are stored.
  Future<void> _ingest(Map<String, dynamic> m) async {
    if (m['type'] != 'enc' || await store.exists(m['id'])) return store.upsert(m, 'delivered');
    if (m['sender_id'] == userId) return store.upsert({...m, 'type': 'undecryptable', 'body': ''}, 'delivered');
    final inner = await e2ee?.open(m);
    // no key yet: keep the ciphertext and retry when the sender's key arrives
    await store.upsert(inner == null ? {...m, 'type': 'pending'} : _opened(m, inner), 'delivered');
  }

  Future<void> _retryPending(String channelId) async {
    final e = e2ee;
    if (e == null) return;
    var changed = false;
    for (final r in await store.pending(channelId)) {
      final inner = await e.open({...r, 'type': 'enc'});
      if (inner == null) continue;
      final o = _opened(Map<String, dynamic>.from(r), inner);
      await store.setContent(r['id'] as String, o['type'], o['body'], o['media']);
      changed = true;
    }
    if (changed) notifyListeners();
  }

  void _stop() {
    _ping?.cancel();
    _retry?.cancel();
    _flushTimer?.cancel();
    _health?.cancel();
    mesh?.stop();
    nearbyMode = false;
    _ws?.sink.close();
    _ws = null;
    connected = false;
  }

  Future<void> refreshChannels() async {
    try {
      final fresh = List<Map<String, dynamic>>.from(await api!.get('/me/channels'));
      final gone = channels.where((c) => !fresh.any((f) => f['id'] == c['id'])).toList();
      channels = fresh;
      await store.set('channels', jsonEncode(channels));
      for (final c in gone) {
        await store.deleteChannel(c['id']);
        _events.add({'t': 'channel_gone', 'channel_id': c['id'], 'name': c['name'], 'reason': 'removed'});
      }
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
            _keySync();
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
    final e = jsonDecode(raw as String) as Map<String, dynamic>;
    if (e['t'] == 'message') {
      await _ingest(Map<String, dynamic>.from(e['message']));
      notifyListeners();
      if (!nearbyMode) mesh?.forward(Map<String, dynamic>.from(e['message'])); // gateway: pass it down
    } else if (e['t'] == 'broadcast' && !nearbyMode) {
      // admin broadcasts / emergency alerts must reach offline phones too
      mesh?.forward({...Map<String, dynamic>.from(e['message']), 'emergency': e['emergency'] == true});
    } else if (e['t'] == 'key') {
      await _onKey(e);
    } else if (e['t'] == 'audit_key') {
      await _setAuditKey(e['public_key'] as String? ?? '');
    } else if (e['t'] == 'channel_added') {
      await refreshChannels();
    } else if (e['t'] == 'channel_deleted') {
      await _dropChannel(e['channel_id'], 'deleted', name: e['name']);
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
      await _makeBundle(m);
    }
    notifyListeners();
    flush();
  }

  // SOS goes to the first channel (the team's main channel).
  Future<void> sendSos() async {
    if (channels.isEmpty) return;
    await sendText(channels.first['id'], 'SOS — ${userName ?? 'teammate'} needs help', type: 'sos');
  }

  // Media is queued with its local path; flush uploads it before posting the message.
  // type: image | video | audio | file; body keeps the original file name.
  Future<void> sendImage(String channelId, String path) => sendMedia(channelId, path, 'image', '');

  Future<void> sendMedia(String channelId, String path, String type, String name) async {
    await store.upsert({
      'id': uuid4(),
      'channel_id': channelId,
      'sender_id': userId,
      'sender_name': userName,
      'type': type,
      'body': name,
      'media': 'local:$path',
      'created_at': DateTime.now().millisecondsSinceEpoch,
    }, 'queued');
    notifyListeners();
    flush();
  }

  Future<void> flush() async {
    _uploadBundles();
    if (_flushing || api == null) return;
    _flushing = true;
    try {
      for (final m in await store.queued()) {
        // everything except SOS is end-to-end encrypted; SOS stays readable for the control room
        final secure = m['type'] != 'sos' && e2ee != null;
        var media = m['media'] as String? ?? '';
        String? mediaKey;
        if (media.startsWith('e2e:')) {
          // uploaded on an earlier attempt; only the post failed
          final p = media.substring(4).split('|');
          media = p[0];
          mediaKey = p[1];
        } else if (media.startsWith('local:')) {
          try {
            if (secure) {
              final (blob, key) = await e2ee!.sealFile(media.substring(6));
              media = await api!.upload(blob);
              mediaKey = key;
              File(blob).delete().ignore();
            } else {
              media = await api!.upload(media.substring(6));
            }
          } on ApiError catch (e) {
            // too big / type refused / file gone: retrying won't help, mark it failed
            if (e.status != 413 && e.status != 400) rethrow;
            await store.setStatus(m['id'], 'failed');
            notifyListeners();
            continue;
          } on FileSystemException {
            await store.setStatus(m['id'], 'failed');
            notifyListeners();
            continue;
          }
          await store.db.update(
            'messages',
            {'media': mediaKey == null ? media : 'e2e:$media|$mediaKey'},
            where: 'id=?',
            whereArgs: [m['id']],
          );
        }
        var type = m['type'] as String, body = m['body'] as String? ?? '';
        String? audit;
        if (secure) {
          try {
            final inner = {'type': type, 'body': body, 'media_key': ?mediaKey};
            body = await e2ee!.seal(m['channel_id'], _isDirect(m['channel_id']), inner);
            audit = _auditFor({...inner, 'media': media}, m);
            type = 'enc';
          } on ApiError catch (e) {
            if (e.status == 401) rethrow;
            continue; // e.g. the other person has not set up keys yet: keep it queued
          }
        }
        final r = await api!.post('/messages', {
          'id': m['id'],
          'channel_id': m['channel_id'],
          'type': type,
          'body': body,
          'media': media,
          'created_at': m['created_at'],
          'offline': m['offline'],
          'audit': ?audit,
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
        await _ingest(Map<String, dynamic>.from(m));
      }
      if (list.isNotEmpty) notifyListeners();
    } catch (_) {}
  }
}
