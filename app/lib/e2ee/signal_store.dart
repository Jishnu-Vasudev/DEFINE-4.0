import 'dart:typed_data';

import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';
import 'package:sqflite/sqflite.dart';

// Signal protocol state (identity, pre-keys, sessions, sender keys) persisted in the app DB.
// Everything is cached in memory and written through on change.
class SignalStore extends SignalProtocolStore implements SenderKeyStore {
  final Database db;
  final Map<String, Uint8List> _m = {};
  late IdentityKeyPair _identity;
  late int _registrationId;

  SignalStore(this.db);

  static const _table = 'sig';

  Future<bool> load() async {
    await db.execute('CREATE TABLE IF NOT EXISTS $_table(k TEXT PRIMARY KEY, v BLOB)');
    for (final r in await db.query(_table)) {
      _m[r['k'] as String] = Uint8List.fromList(r['v'] as List<int>);
    }
    final id = _m['identity'], reg = _m['reg'];
    if (id == null || reg == null) return false;
    _identity = IdentityKeyPair.fromSerialized(id);
    _registrationId = ByteData.sublistView(reg).getInt32(0);
    return true;
  }

  // First run on this phone: a fresh identity (X3DH long-term key) and registration id.
  Future<void> createIdentity() async {
    _identity = generateIdentityKeyPair();
    _registrationId = generateRegistrationId(false);
    await put('identity', _identity.serialize());
    await put('reg', (ByteData(4)..setInt32(0, _registrationId)).buffer.asUint8List());
  }

  Future<void> wipe() async {
    _m.clear();
    await db.execute('CREATE TABLE IF NOT EXISTS $_table(k TEXT PRIMARY KEY, v BLOB)');
    await db.delete(_table);
  }

  Uint8List? get(String k) => _m[k];
  Future<void> put(String k, Uint8List v) async {
    _m[k] = v;
    await db.insert(_table, {'k': k, 'v': v}, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> del(String k) async {
    _m.remove(k);
    await db.delete(_table, where: 'k=?', whereArgs: [k]);
  }

  int getInt(String k) => _m[k] == null ? 0 : ByteData.sublistView(_m[k]!).getInt32(0);
  Future<void> putInt(String k, int v) => put(k, (ByteData(4)..setInt32(0, v)).buffer.asUint8List());

  String _addr(SignalProtocolAddress a) => '${a.getName()}:${a.getDeviceId()}';

  // ---- identity ----
  @override
  Future<IdentityKeyPair> getIdentityKeyPair() async => _identity;
  @override
  Future<int> getLocalRegistrationId() async => _registrationId;
  @override
  Future<bool> saveIdentity(SignalProtocolAddress address, IdentityKey? identityKey) async {
    if (identityKey == null) return false;
    final k = 'tid:${_addr(address)}', old = _m[k];
    await put(k, identityKey.serialize());
    return old != null;
  }

  // Trust on first use; a changed key (reinstalled phone) is accepted and replaces the old one.
  @override
  Future<bool> isTrustedIdentity(SignalProtocolAddress address, IdentityKey? identityKey, Direction direction) async => true;
  @override
  Future<IdentityKey?> getIdentity(SignalProtocolAddress address) async {
    final v = _m['tid:${_addr(address)}'];
    return v == null ? null : IdentityKey.fromBytes(v, 0);
  }

  // ---- one-time pre-keys ----
  @override
  Future<PreKeyRecord> loadPreKey(int preKeyId) async {
    final v = _m['pk:$preKeyId'];
    if (v == null) throw InvalidKeyIdException('No such prekey: $preKeyId');
    return PreKeyRecord.fromBuffer(v);
  }

  @override
  Future<void> storePreKey(int preKeyId, PreKeyRecord record) => put('pk:$preKeyId', record.serialize());
  @override
  Future<bool> containsPreKey(int preKeyId) async => _m.containsKey('pk:$preKeyId');
  @override
  Future<void> removePreKey(int preKeyId) => del('pk:$preKeyId');

  // ---- signed pre-keys ----
  @override
  Future<SignedPreKeyRecord> loadSignedPreKey(int signedPreKeyId) async {
    final v = _m['spk:$signedPreKeyId'];
    if (v == null) throw InvalidKeyIdException('No such signed prekey: $signedPreKeyId');
    return SignedPreKeyRecord.fromSerialized(v);
  }

  @override
  Future<List<SignedPreKeyRecord>> loadSignedPreKeys() async => [
    for (final e in _m.entries)
      if (e.key.startsWith('spk:')) SignedPreKeyRecord.fromSerialized(e.value),
  ];
  @override
  Future<void> storeSignedPreKey(int signedPreKeyId, SignedPreKeyRecord record) => put('spk:$signedPreKeyId', record.serialize());
  @override
  Future<bool> containsSignedPreKey(int signedPreKeyId) async => _m.containsKey('spk:$signedPreKeyId');
  @override
  Future<void> removeSignedPreKey(int signedPreKeyId) => del('spk:$signedPreKeyId');

  // ---- Double Ratchet sessions ----
  @override
  Future<SessionRecord> loadSession(SignalProtocolAddress address) async {
    final v = _m['ss:${_addr(address)}'];
    return v == null ? SessionRecord() : SessionRecord.fromSerialized(v);
  }

  @override
  Future<List<int>> getSubDeviceSessions(String name) async => [];
  @override
  Future<void> storeSession(SignalProtocolAddress address, SessionRecord record) => put('ss:${_addr(address)}', record.serialize());
  @override
  Future<bool> containsSession(SignalProtocolAddress address) async => _m.containsKey('ss:${_addr(address)}');
  @override
  Future<void> deleteSession(SignalProtocolAddress address) => del('ss:${_addr(address)}');
  @override
  Future<void> deleteAllSessions(String name) async {
    for (final k in _m.keys.where((k) => k.startsWith('ss:$name:')).toList()) {
      await del(k);
    }
  }

  // ---- channel sender keys ----
  @override
  Future<void> storeSenderKey(SenderKeyName senderKeyName, SenderKeyRecord record) =>
      put('sk:${senderKeyName.serialize()}', record.serialize());
  @override
  Future<SenderKeyRecord> loadSenderKey(SenderKeyName senderKeyName) async {
    final v = _m['sk:${senderKeyName.serialize()}'];
    return v == null ? SenderKeyRecord() : SenderKeyRecord.fromSerialized(v);
  }
}
