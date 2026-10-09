import Database from 'better-sqlite3';
import { randomBytes, randomUUID } from 'node:crypto';
import path from 'node:path';

const dbPath = process.env.DB_PATH || path.join(process.cwd(), 'data.db');
export const db = new Database(dbPath);

db.pragma('journal_mode = WAL');
db.pragma('foreign_keys = ON');

export function initDb() {
  db.exec(`
    CREATE TABLE IF NOT EXISTS users (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      role TEXT NOT NULL,
      revoked INTEGER DEFAULT 0,
      last_seen INTEGER
    );

    CREATE TABLE IF NOT EXISTS teams (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL
    );

    CREATE TABLE IF NOT EXISTS channels (
      id TEXT PRIMARY KEY,
      team_id TEXT,
      name TEXT NOT NULL,
      kind TEXT NOT NULL
    );

    CREATE TABLE IF NOT EXISTS members (
      user_id TEXT NOT NULL,
      channel_id TEXT NOT NULL,
      PRIMARY KEY (user_id, channel_id)
    );

    CREATE TABLE IF NOT EXISTS invites (
      code TEXT PRIMARY KEY,
      team_id TEXT,
      role TEXT NOT NULL,
      expires_at INTEGER,
      used INTEGER DEFAULT 0
    );

    CREATE TABLE IF NOT EXISTS messages (
      seq INTEGER PRIMARY KEY AUTOINCREMENT,
      id TEXT UNIQUE NOT NULL,
      channel_id TEXT NOT NULL,
      sender_id TEXT NOT NULL,
      type TEXT NOT NULL,
      body TEXT,
      media TEXT,
      created_at INTEGER NOT NULL,
      offline INTEGER DEFAULT 0
    );

    CREATE TABLE IF NOT EXISTS acks (
      message_id TEXT NOT NULL,
      user_id TEXT NOT NULL,
      at INTEGER NOT NULL,
      PRIMARY KEY (message_id, user_id)
    );
  `);

  seedAdminIfNeeded();
}

function seedAdminIfNeeded() {
  const adminCount = db.prepare("SELECT COUNT(*) as count FROM users WHERE role = 'admin'").get() as { count: number };
  if (adminCount.count === 0) {
    const adminId = randomUUID();
    const now = Date.now();
    db.prepare(`
      INSERT INTO users (id, name, role, revoked, last_seen)
      VALUES (?, ?, ?, 0, ?)
    `).run(adminId, 'Admin', 'admin', now);

    // Create a default team and admin invite
    const defaultTeamId = randomUUID();
    db.prepare(`INSERT INTO teams (id, name) VALUES (?, ?)`).run(defaultTeamId, 'Default');

    const adminInviteCode = randomBytes(4).toString('hex').toUpperCase();
    db.prepare(`
      INSERT INTO invites (code, team_id, role, expires_at, used)
      VALUES (?, ?, 'admin', NULL, 0)
    `).run(adminInviteCode, defaultTeamId);

    console.log(`=========================================`);
    console.log(`[SEED] Admin User Created: ${adminId}`);
    console.log(`[SEED] Admin Invite Code: ${adminInviteCode}`);
    console.log(`=========================================`);
  }
}
