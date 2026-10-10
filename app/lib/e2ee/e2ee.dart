import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../api.dart';
import 'media_crypt.dart';
import 'signal_store.dart';

// End-to-end encryption on the Signal Protocol.
//  * 1:1 (dm) channels: every message goes through the Double Ratchet session set up by X3DH.
//  * Team/zone channels: Signal "sender keys". Each member's sender key is delivered to every
//    other member over their pairwise Double Ratchet session, then messages are encrypted once.
// Wire body: "g:<b64>" sender-key message, "p:<b64>" pre-key message, "w:<b64>" ratchet message.
class E2ee {
  final Api api;
  final String me;
  final SignalStore store;
  final _ready = Completer<void>();
  Future<void> _lock = Future.value();
  final Map<String, (DateTime, List<String>)> _members = {};

  E2ee(Database db, this.api, this.me) : store = SignalStore(db);

  Future<void> get ready => _ready.future;
  SignalProtocolAddress _addr(String uid) => SignalProtocolAddress(uid, 1);

  // Signal state is not safe to mutate concurrently: run every operation in order.
  Future<T> _serial<T>(Future<T> Function() f) {
    final run = _lock.then((_) => f());
    _lock = run.then((_) {}, onError: (_) {});
    return run;
  }

  Future<void> init() async {
    if (!await store.load()) await store.createIdentity();
    if (!_ready.isCompleted) _ready.complete();
    await publishKeys();
  }

  Future<void> wipe() => store.wipe();

  // Uploads the public bundle and keeps at least 20 one-time pre-keys on the server.
  Future<void> publishKeys() => _serial(() async {
    final have = (await api.get('/keys/count'))['prekeys'] as int;
    final first = store.get('published') == null;
    if (!first && have >= 20) return;
    final id = await store.getIdentityKeyPair();
    var signed = store.getInt('spk_id');
    if (signed == 0) {
      signed = 1;
      await store.storeSignedPreKey(signed, generateSignedPreKey(id, signed));
      await store.putInt('spk_id', signed);
    }
    final spk = await store.loadSignedPreKey(signed);
    final next = store.getInt('pk_next') + 1;
    final pre = generatePreKeys(next, 60);
    for (final p in pre) {
      await store.storePreKey(p.id, p);
    }
    await store.putInt('pk_next', next + 59);
    await api.put('/keys', {
      'registration_id': await store.getLocalRegistrationId(),
      'identity_key': base64.encode(id.getPublicKey().serialize()),
      'signed_prekey': {'id': signed, 'pub': base64.encode(spk.getKeyPair().publicKey.serialize()), 'sig': base64.encode(spk.signature)},
      'prekeys': [
        for (final p in pre) {'id': p.id, 'pub': base64.encode(p.getKeyPair().publicKey.serialize())},
      ],
    });
    await store.put('published', Uint8List(1));
  });

  Future<List<String>> _memberIds(String channelId, {bool fresh = false}) async {
    final c = _members[channelId];
    if (!fresh && c != null && DateTime.now().difference(c.$1).inSeconds < 3) return c.$2;
    final list = [for (final m in await api.get('/channels/$channelId/members') as List) m['id'] as String];
    _members[channelId] = (DateTime.now(), list);
    return list;
  }

  // X3DH: fetch the peer's bundle once and build a Double Ratchet session.
  Future<SessionCipher> _session(String uid) async {
    final a = _addr(uid);
    if (!await store.containsSession(a)) {
      final b = await api.get('/keys/user/$uid');
      Uint8List d(String s) => base64.decode(s);
      final pk = b['prekey'];
      await SessionBuilder.fromSignalStore(store, a).processPreKeyBundle(
        PreKeyBundle(
          b['registration_id'],
          1,
          pk?['id'],
          pk == null ? null : Curve.decodePoint(d(pk['pub']), 0),
          b['signed_prekey']['id'],
          Curve.decodePoint(d(b['signed_prekey']['pub']), 0),
          d(b['signed_prekey']['sig']),
          IdentityKey.fromBytes(d(b['identity_key']), 0),
        ),
      );
    }
    return SessionCipher.fromStore(store, a);
  }

  Future<String> _pairwise(String uid, Uint8List plain) async {
    final c = await (await _session(uid)).encrypt(plain);
    return '${c.getType() == CiphertextMessage.prekeyType ? 'p' : 'w'}:${base64.encode(c.serialize())}';
  }

  Future<Uint8List> _unpair(String uid, String body) async {
    final c = SessionCipher.fromStore(store, _addr(uid));
    final raw = base64.decode(body.substring(2));
    return body.startsWith('p:') ? c.decrypt(PreKeySignalMessage(raw)) : c.decryptFromSignal(SignalMessage.fromSerialized(raw));
  }

  // Make sure every current member holds my sender key for this channel.
  Future<void> _distribute(String channelId) async {
    final name = SenderKeyName(channelId, _addr(me));
    final skdm = await GroupSessionBuilder(store).create(name);
    await store.put('skdist:$channelId', Uint8List(1)); // my sender key has been handed out at least once
    for (final uid in await _memberIds(channelId)) {
      if (uid == me || store.get('skd:$channelId:$uid') != null) continue;
      final String body;
      try {
        body = await _pairwise(uid, skdm.serialize());
      } on ApiError catch (e) {
        // no keys yet (e.g. an admin who only uses the web console): they cannot read this
        // channel until they sign in on a phone; retried on every later message
        if (e.status == 404) continue;
        rethrow;
      }
      await api.post('/keys/send', {'to': uid, 'channel_id': channelId, 'type': 5, 'body': body});
      await store.put('skd:$channelId:$uid', Uint8List(1));
    }
  }

  // Encrypts an inner payload {type, body, media_key?} for a channel.
  Future<String> seal(String channelId, bool direct, Map<String, dynamic> inner) => _serial(() async {
    await ready;
    final plain = Uint8List.fromList(utf8.encode(jsonEncode(inner)));
    if (direct) {
      final peer = (await _memberIds(channelId)).firstWhere((u) => u != me, orElse: () => throw StateError('no peer'));
      await store.put('dmpeer:$channelId', Uint8List.fromList(utf8.encode(peer)));
      return _pairwise(peer, plain);
    }
    await _distribute(channelId);
    final c = await GroupCipher(store, SenderKeyName(channelId, _addr(me))).encrypt(plain);
    return 'g:${base64.encode(c)}';
  });

  // Offline variant for store-and-forward bundles: never touches the network. Only seals when
  // recipients can already open it later (sender key handed out before / ratchet session exists).
  Future<String?> sealOffline(String channelId, bool direct, Map<String, dynamic> inner) => _serial(() async {
    if (!_ready.isCompleted) return null;
    final plain = Uint8List.fromList(utf8.encode(jsonEncode(inner)));
    try {
      if (direct) {
        final p = store.get('dmpeer:$channelId');
        if (p == null || !await store.containsSession(_addr(utf8.decode(p)))) return null;
        final c = await SessionCipher.fromStore(store, _addr(utf8.decode(p))).encrypt(plain);
        return '${c.getType() == CiphertextMessage.prekeyType ? 'p' : 'w'}:${base64.encode(c.serialize())}';
      }
      if (store.get('skdist:$channelId') == null) return null;
      return 'g:${base64.encode(await GroupCipher(store, SenderKeyName(channelId, _addr(me))).encrypt(plain))}';
    } catch (_) {
      return null;
    }
  });

  // Signs a store-and-forward bundle with my identity key; the server verifies it (bundles.go).
  Future<String> sign(Uint8List bytes) async {
    await ready;
    final id = await store.getIdentityKeyPair();
    return base64.encode(Curve.calculateSignature(id.getPrivateKey(), bytes));
  }

  // Decrypts a received "enc" message; null while the sender's key has not arrived yet.
  Future<Map<String, dynamic>?> open(Map<String, dynamic> m) => _serial(() async {
    await ready;
    final body = m['body'] as String, from = m['sender_id'] as String;
    try {
      final plain = body.startsWith('g:')
          ? await GroupCipher(store, SenderKeyName(m['channel_id'], _addr(from))).decrypt(base64.decode(body.substring(2)))
          : await _unpair(from, body);
      return Map<String, dynamic>.from(jsonDecode(utf8.decode(plain)));
    } on NoSessionException {
      return null;
    } on DuplicateMessageException {
      return {'type': 'undecryptable', 'body': ''};
    } catch (e) {
      // sender rotated to a key we have not received yet: wait for it; anything else is unreadable
      return '$e'.contains('No key state') ? null : {'type': 'undecryptable', 'body': ''};
    }
  });

  // A sealed key message: a member's sender key for one channel. Returns the channel id.
  Future<String?> onKeyMessage(Map<String, dynamic> k) => _serial(() async {
    await ready;
    final from = k['from'] as String, ch = k['channel_id'] as String;
    try {
      final skdm = SenderKeyDistributionMessageWrapper.fromSerialized(await _unpair(from, k['body']));
      await GroupSessionBuilder(store).process(SenderKeyName(ch, _addr(from)), skdm);
      // they may have reinstalled: resend my key to them on my next message
      await store.del('skd:$ch:$from');
      return ch;
    } catch (_) {
      return null;
    } finally {
      try {
        await api.post('/keys/ack', {
          'ids': [k['id']],
        });
      } catch (_) {}
    }
  });

  // ---- media ----
  Future<(String path, String key)> sealFile(String path) async {
    final mk = MediaKey.random();
    final out = File('${(await getTemporaryDirectory()).path}/${DateTime.now().microsecondsSinceEpoch}.enc');
    await out.writeAsBytes(mk.encrypt(await File(path).readAsBytes()));
    return (out.path, base64.encode(mk.bytes));
  }

  // ref = "e2e:<server file>|<b64 key>" -> decrypted file in the app cache (downloaded once).
  Future<File> openFile(String ref, String name) async {
    final parts = ref.substring(4).split('|');
    final dir = Directory('${(await getApplicationCacheDirectory()).path}/e2e/${parts[0].split('.').first}');
    final safe = name.isEmpty ? 'file' : name.replaceAll(RegExp(r'[\\/]'), '_');
    final f = File('${dir.path}/$safe');
    if (await f.exists()) return f;
    final blob = await api.download(parts[0]);
    await dir.create(recursive: true);
    return f.writeAsBytes(MediaKey.fromBytes(base64.decode(parts[1])).decrypt(Uint8List.fromList(blob)));
  }
}
