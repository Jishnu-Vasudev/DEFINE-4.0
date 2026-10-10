import 'dart:convert';
import 'dart:typed_data';

import 'package:sqflite/sqflite.dart';

// Delay-tolerant store-and-forward ("muling"). While the server is unreachable every phone keeps
// the bundles it has seen, swaps them with phones it meets on the nearby mesh, and hands them in
// to the server as soon as any carrier gets back in range. Bundles are signed by their origin.
class Bundle {
  final String id, origin, originName, channelId, type, body, sig;
  final String audit; // envelope for the org audit key ('' if auditing is off); covered by sig
  final int createdAt, hops;
  const Bundle({
    required this.id,
    required this.origin,
    required this.originName,
    required this.channelId,
    required this.type,
    required this.body,
    required this.createdAt,
    required this.hops,
    required this.sig,
    this.audit = '',
  });

  // Exactly what the origin signs; the server rebuilds the same string to verify (bundles.go).
  static Uint8List signedBytes(String id, String channelId, String origin, String type, String body, int createdAt, [String audit = '']) =>
      Uint8List.fromList(utf8.encode('relay-bundle\n$id\n$channelId\n$origin\n$type\n$body\n$createdAt\n$audit'));

  Map<String, dynamic> toJson() => {
    'bundle_id': id,
    'origin': origin,
    'origin_name': originName,
    'channel_id': channelId,
    'type': type,
    'body': body,
    'created_at': createdAt,
    'hops': hops,
    'sig': sig,
    if (audit.isNotEmpty) 'audit': audit,
  };

  factory Bundle.fromJson(Map<String, dynamic> j) => Bundle(
    id: j['bundle_id'],
    origin: j['origin'],
    originName: j['origin_name'] ?? '',
    channelId: j['channel_id'],
    type: j['type'],
    body: j['body'],
    createdAt: j['created_at'],
    hops: j['hops'] ?? 0,
    sig: j['sig'],
    audit: j['audit'] ?? '',
  );
}

class BundleStore {
  final Database db;
  BundleStore(this.db);
  static const maxHops = 8;
  static const ttl = Duration(hours: 48);

  Future<void> open() async {
    await db.execute(
      '''CREATE TABLE IF NOT EXISTS bundles(bundle_id TEXT PRIMARY KEY, origin TEXT, origin_name TEXT,
      channel_id TEXT, type TEXT, body TEXT, created_at INTEGER, hops INTEGER, sig TEXT, uploaded INTEGER DEFAULT 0, received_at INTEGER, audit TEXT DEFAULT '')''',
    );
    // installs from before auditing
    await db.execute("ALTER TABLE bundles ADD COLUMN audit TEXT DEFAULT ''").catchError((_) {});
  }

  // Returns true if the bundle was new to this phone.
  Future<bool> add(Bundle b) async {
    if (b.hops > maxHops || DateTime.now().millisecondsSinceEpoch - b.createdAt > ttl.inMilliseconds) return false;
    final row = {...b.toJson(), 'received_at': DateTime.now().millisecondsSinceEpoch}..remove('bundle_id');
    final n = await db.insert('bundles', {'bundle_id': b.id, ...row}, conflictAlgorithm: ConflictAlgorithm.ignore);
    return n > 0;
  }

  Future<List<Bundle>> all() async {
    await db.delete('bundles', where: 'created_at < ?', whereArgs: [DateTime.now().subtract(ttl).millisecondsSinceEpoch]);
    return [for (final r in await db.query('bundles', orderBy: 'created_at')) Bundle.fromJson(r)];
  }

  Future<List<Bundle>> toUpload() async => [for (final r in await db.query('bundles', where: 'uploaded=0', limit: 500)) Bundle.fromJson(r)];

  Future<void> markUploaded(Iterable<String> ids) async {
    for (final id in ids) {
      await db.update('bundles', {'uploaded': 1}, where: 'bundle_id=?', whereArgs: [id]);
    }
  }

  Future<void> clear() => db.delete('bundles');
}

// Fixed-size Bloom filter summary (8192 bits = 1 KB, 5 hashes): ~2% false positives at 1000
// bundles and always fits one Nearby bytes payload, unlike a raw id list.
class BundleBloom {
  static const bits = 8192, k = 5;
  final Uint8List data;
  BundleBloom([Uint8List? d]) : data = d ?? Uint8List(bits ~/ 8);

  static int _fnv(String s, int seed) {
    var h = 0x811c9dc5 ^ seed;
    for (final c in utf8.encode(s)) {
      h = ((h ^ c) * 0x01000193) & 0xffffffff;
    }
    return h;
  }

  Iterable<int> _idx(String id) sync* {
    final a = _fnv(id, 0), b = _fnv(id, 0x5bd1e995) | 1;
    for (var i = 0; i < k; i++) {
      yield (a + i * b) % bits;
    }
  }

  void add(String id) {
    for (final i in _idx(id)) {
      data[i >> 3] |= 1 << (i & 7);
    }
  }

  bool mightContain(String id) => _idx(id).every((i) => data[i >> 3] & (1 << (i & 7)) != 0);
  String encode() => base64.encode(data);
  factory BundleBloom.decode(String s) => BundleBloom(base64.decode(s));
}
