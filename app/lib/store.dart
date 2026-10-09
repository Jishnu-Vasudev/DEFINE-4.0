import 'package:sqflite/sqflite.dart';

// Local DB: session key/values + every message (incl. the outbox, status='queued').
class Store {
  late Database db;

  Future<void> open() async {
    db = await openDatabase(
      '${await getDatabasesPath()}/ptt.db',
      version: 1,
      onCreate: (d, _) async {
        await d.execute('CREATE TABLE kv(k TEXT PRIMARY KEY, v TEXT)');
        await d.execute('''CREATE TABLE messages(id TEXT PRIMARY KEY, channel_id TEXT, sender_id TEXT, sender_name TEXT,
        type TEXT, body TEXT, media TEXT, created_at INTEGER, seq INTEGER, status TEXT, offline INTEGER DEFAULT 0)''');
        await d.execute('CREATE INDEX msg_ch ON messages(channel_id, created_at)');
      },
    );
  }

  Future<String?> get(String k) async {
    final r = await db.query('kv', where: 'k=?', whereArgs: [k]);
    return r.isEmpty ? null : r.first['v'] as String?;
  }

  Future<void> set(String k, String v) => db.insert('kv', {'k': k, 'v': v}, conflictAlgorithm: ConflictAlgorithm.replace);

  Future<void> clear() async {
    await db.delete('kv');
    await db.delete('messages');
  }

  Future<void> upsert(Map<String, dynamic> m, String status) async {
    final row = {
      'id': m['id'],
      'channel_id': m['channel_id'],
      'sender_id': m['sender_id'],
      'sender_name': m['sender_name'] ?? '',
      'type': m['type'],
      'body': m['body'] ?? '',
      'media': m['media'] ?? '',
      'created_at': m['created_at'],
      'seq': m['seq'],
      'status': status,
      'offline': m['offline'] ?? 0,
    };
    // a duplicate (e.g. mesh copy) must not wipe the server seq
    final n = await db.update('messages', {'status': status, 'seq': ?row['seq']}, where: 'id=?', whereArgs: [row['id']]);
    if (n == 0) await db.insert('messages', row, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<void> setStatus(String id, String status, {int? seq}) =>
      db.update('messages', {'status': status, 'seq': ?seq}, where: 'id=?', whereArgs: [id]);

  Future<List<Map<String, dynamic>>> messages(String channelId) =>
      db.query('messages', where: 'channel_id=?', whereArgs: [channelId], orderBy: 'created_at');

  Future<List<Map<String, dynamic>>> queued() => db.query('messages', where: "status='queued'", orderBy: 'created_at');

  Future<int> maxSeq(String channelId) async {
    final r = await db.rawQuery('SELECT MAX(seq) s FROM messages WHERE channel_id=?', [channelId]);
    return (r.first['s'] as int?) ?? 0;
  }

  Future<Map<String, dynamic>?> last(String channelId) async {
    final r = await db.query('messages', where: 'channel_id=?', whereArgs: [channelId], orderBy: 'created_at DESC', limit: 1);
    return r.isEmpty ? null : r.first;
  }
}
