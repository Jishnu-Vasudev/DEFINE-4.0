import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import '../models/message.dart';
import '../models/channel.dart';

class DbService {
  static final DbService instance = DbService._();
  DbService._();

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'ptt_local.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execSQL('''
          CREATE TABLE channels (
            id TEXT PRIMARY KEY,
            team_id TEXT,
            name TEXT NOT NULL,
            kind TEXT NOT NULL
          );
        ''');

        await db.execSQL('''
          CREATE TABLE messages (
            id TEXT PRIMARY KEY,
            channel_id TEXT NOT NULL,
            sender_id TEXT NOT NULL,
            type TEXT NOT NULL,
            body TEXT,
            media TEXT,
            created_at INTEGER NOT NULL,
            offline INTEGER DEFAULT 0,
            seq INTEGER,
            status TEXT NOT NULL
          );
        ''');
      },
    );
  }

  Future<void> saveChannels(List<Channel> channels) async {
    final db = await database;
    final batch = db.batch();
    for (final ch in channels) {
      batch.insert(
        'channels',
        ch.toJson(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<Channel>> getChannels() async {
    final db = await database;
    final maps = await db.query('channels');
    return maps.map((m) => Channel.fromJson(m)).toList();
  }

  Future<void> saveMessage(Message message) async {
    final db = await database;
    await db.insert(
      'messages',
      message.toDbMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateMessageStatus(String id, OutboxStatus status, {int? seq}) async {
    final db = await database;
    final Map<String, dynamic> updates = {'status': status.name};
    if (seq != null) updates['seq'] = seq;
    await db.update('messages', updates, where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Message>> getMessagesForChannel(String channelId) async {
    final db = await database;
    final maps = await db.query(
      'messages',
      where: 'channel_id = ?',
      whereArgs: [channelId],
      orderBy: 'created_at ASC, seq ASC',
    );
    return maps.map((m) => Message.fromDbMap(m)).toList();
  }

  Future<List<Message>> getQueuedMessages() async {
    final db = await database;
    final maps = await db.query(
      'messages',
      where: 'status = ?',
      whereArgs: [OutboxStatus.queued.name],
      orderBy: 'created_at ASC',
    );
    return maps.map((m) => Message.fromDbMap(m)).toList();
  }

  Future<int> getMaxSeqForChannel(String channelId) async {
    final db = await database;
    final res = await db.rawQuery(
      'SELECT MAX(seq) as max_seq FROM messages WHERE channel_id = ? AND seq IS NOT NULL',
      [channelId],
    );
    return (res.first['max_seq'] as num?)?.toInt() ?? 0;
  }
}

extension on Database {
  Future<void> execSQL(String sql) => execute(sql);
}
