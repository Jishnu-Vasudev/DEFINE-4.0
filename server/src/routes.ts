import { FastifyInstance, FastifyRequest, FastifyReply } from 'fastify';
import { randomBytes, randomUUID } from 'node:crypto';
import QRCode from 'qrcode';
import { db } from './db.js';
import { signJwt, requireAuth, requireAdmin } from './auth.js';
import { broadcastToChannel, broadcastToAll, sendToUser, isUserOnline, getUserOfflineMode } from './ws.js';
import { requestFloor, releaseFloor, getFloorHolder } from './floor.js';
import { generateLiveKitToken } from './livekit.js';

interface JoinBody {
  code: string;
  name: string;
}

interface CreateTeamBody {
  name: string;
}

interface CreateChannelBody {
  team_id: string;
  name: string;
  kind: 'team' | 'zone' | 'dm';
}

interface CreateInviteBody {
  team_id: string;
  role: 'admin' | 'member';
}

interface PostMessageBody {
  id: string;
  channel_id: string;
  type: 'text' | 'image' | 'sos' | 'broadcast' | 'ptt_clip';
  body: string;
  media?: string;
  created_at: number;
  offline?: number;
}

interface AckBody {
  message_id: string;
}

export async function registerRoutes(fastify: FastifyInstance) {
  // Public join route
  fastify.post('/auth/join', async (request: FastifyRequest<{ Body: JoinBody }>, reply: FastifyReply) => {
    const { code, name } = request.body || {};
    if (!code || !name) {
      return reply.status(400).send({ error: 'code and name are required' });
    }

    const invite = db.prepare('SELECT * FROM invites WHERE code = ?').get(code.trim().toUpperCase()) as {
      code: string;
      team_id: string | null;
      role: string;
      expires_at: number | null;
      used: number;
    } | undefined;

    if (!invite) {
      return reply.status(400).send({ error: 'Invalid invite code' });
    }

    if (invite.used === 1) {
      return reply.status(400).send({ error: 'Invite code has already been used' });
    }

    if (invite.expires_at && invite.expires_at < Date.now()) {
      return reply.status(400).send({ error: 'Invite code has expired' });
    }

    const userId = randomUUID();
    const now = Date.now();

    const insertUser = db.transaction(() => {
      db.prepare(`
        INSERT INTO users (id, name, role, revoked, last_seen)
        VALUES (?, ?, ?, 0, ?)
      `).run(userId, name.trim(), invite.role, now);

      db.prepare('UPDATE invites SET used = 1 WHERE code = ?').run(invite.code);

      if (invite.team_id) {
        const teamChannels = db.prepare('SELECT id FROM channels WHERE team_id = ?').all(invite.team_id) as { id: string }[];
        const insertMember = db.prepare('INSERT OR IGNORE INTO members (user_id, channel_id) VALUES (?, ?)');
        for (const ch of teamChannels) {
          insertMember.run(userId, ch.id);
        }
      }
    });

    insertUser();

    const channels = db.prepare(`
      SELECT c.id, c.team_id, c.name, c.kind
      FROM channels c
      JOIN members m ON c.id = m.channel_id
      WHERE m.user_id = ?
    `).all(userId);

    const token = signJwt({ uid: userId, role: invite.role });

    return reply.send({
      jwt: token,
      user: {
        id: userId,
        name: name.trim(),
        role: invite.role,
      },
      channels,
    });
  });

  // User's channels
  fastify.get('/me/channels', { preHandler: requireAuth }, async (request: FastifyRequest, reply: FastifyReply) => {
    const userId = request.user!.id;
    const channels = db.prepare(`
      SELECT c.id, c.team_id, c.name, c.kind
      FROM channels c
      JOIN members m ON c.id = m.channel_id
      WHERE m.user_id = ?
    `).all(userId);

    return reply.send(channels);
  });

  // Messages in channel
  fastify.get('/channels/:id/messages', { preHandler: requireAuth }, async (request: FastifyRequest<{ Params: { id: string }; Querystring: { after_seq?: string } }>, reply: FastifyReply) => {
    const channelId = request.params.id;
    const afterSeq = Number(request.query.after_seq) || 0;

    const messages = db.prepare(`
      SELECT seq, id, channel_id, sender_id, type, body, media, created_at, offline
      FROM messages
      WHERE channel_id = ? AND seq > ?
      ORDER BY seq ASC
    `).all(channelId, afterSeq);

    return reply.send(messages);
  });

  // Post message (idempotent)
  fastify.post('/messages', { preHandler: requireAuth }, async (request: FastifyRequest<{ Body: PostMessageBody }>, reply: FastifyReply) => {
    const { id, channel_id, type, body, media, created_at, offline } = request.body || {};
    if (!id || !channel_id || !type) {
      return reply.status(400).send({ error: 'id, channel_id, and type are required' });
    }

    const senderId = request.user!.id;
    const existing = db.prepare('SELECT seq FROM messages WHERE id = ?').get(id) as { seq: number } | undefined;
    if (existing) {
      return reply.send({ seq: existing.seq });
    }

    const now = created_at || Date.now();
    const isOffline = offline ? 1 : 0;

    const result = db.prepare(`
      INSERT INTO messages (id, channel_id, sender_id, type, body, media, created_at, offline)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    `).run(id, channel_id, senderId, type, body || '', media || null, now, isOffline);

    const seq = Number(result.lastInsertRowid);
    const messagePayload = {
      seq,
      id,
      channel_id,
      sender_id: senderId,
      type,
      body: body || '',
      media: media || null,
      created_at: now,
      offline: isOffline,
    };

    broadcastToChannel(channel_id, {
      t: 'message',
      message: messagePayload,
    });

    return reply.send({ seq });
  });

  // Acknowledge message
  fastify.post('/ack', { preHandler: requireAuth }, async (request: FastifyRequest<{ Body: AckBody }>, reply: FastifyReply) => {
    const { message_id } = request.body || {};
    if (!message_id) {
      return reply.status(400).send({ error: 'message_id is required' });
    }

    const userId = request.user!.id;
    const now = Date.now();

    db.prepare(`
      INSERT OR REPLACE INTO acks (message_id, user_id, at)
      VALUES (?, ?, ?)
    `).run(message_id, userId, now);

    return reply.send({ ok: true });
  });

  // Floor Request
  fastify.post('/floor/request', { preHandler: requireAuth }, async (request: FastifyRequest<{ Body: { channel_id: string; priority?: number; timeout_ms?: number } }>, reply: FastifyReply) => {
    const { channel_id, priority, timeout_ms } = request.body || {};
    if (!channel_id) {
      return reply.status(400).send({ error: 'channel_id is required' });
    }

    const userId = request.user!.id;
    const result = requestFloor(channel_id, userId, priority || 1, timeout_ms || 30000);
    return reply.send(result);
  });

  // Floor Release
  fastify.post('/floor/release', { preHandler: requireAuth }, async (request: FastifyRequest<{ Body: { channel_id: string } }>, reply: FastifyReply) => {
    const { channel_id } = request.body || {};
    if (!channel_id) {
      return reply.status(400).send({ error: 'channel_id is required' });
    }

    const userId = request.user!.id;
    releaseFloor(channel_id, userId);
    return reply.send({ ok: true });
  });

  // LiveKit Token
  fastify.get('/livekit/token', { preHandler: requireAuth }, async (request: FastifyRequest<{ Querystring: { room?: string } }>, reply: FastifyReply) => {
    const room = request.query.room;
    if (!room) {
      return reply.status(400).send({ error: 'room query param is required' });
    }

    const userId = request.user!.id;
    const userName = request.user!.name;
    const result = await generateLiveKitToken(userId, userName, room);
    return reply.send(result);
  });

  // Admin: Presence
  fastify.get('/admin/presence', { preHandler: requireAdmin }, async (_request, reply: FastifyReply) => {
    const users = db.prepare('SELECT id, name, last_seen, revoked FROM users WHERE revoked = 0').all() as { id: string; name: string; last_seen: number | null }[];
    const channels = db.prepare('SELECT id, team_id, name, kind FROM channels').all() as { id: string; team_id: string | null; name: string; kind: string }[];

    const userList = users.map(u => ({
      id: u.id,
      name: u.name,
      online: isUserOnline(u.id),
      last_seen: u.last_seen,
      offline_mode: getUserOfflineMode(u.id),
    }));

    const channelList = channels.map(c => {
      const holder = getFloorHolder(c.id);
      const members = db.prepare('SELECT user_id FROM members WHERE channel_id = ?').all(c.id) as { user_id: string }[];
      const membersOnline = members.filter(m => isUserOnline(m.user_id)).length;
      return {
        id: c.id,
        team_id: c.team_id,
        name: c.name,
        kind: c.kind,
        talker: holder ? holder.name : null,
        members_online: membersOnline,
      };
    });

    return reply.send({ users: userList, channels: channelList });
  });

  // Admin: Broadcast
  fastify.post('/admin/broadcast', { preHandler: requireAdmin }, async (request: FastifyRequest<{ Body: { text: string; scope?: string; emergency?: boolean } }>, reply: FastifyReply) => {
    const { text, scope, emergency } = request.body || {};
    if (!text) {
      return reply.status(400).send({ error: 'text is required' });
    }

    const messageId = randomUUID();
    const senderId = request.user!.id;
    const now = Date.now();
    const isEmergency = !!emergency;

    db.prepare(`
      INSERT INTO messages (id, channel_id, sender_id, type, body, media, created_at, offline)
      VALUES (?, ?, ?, 'broadcast', ?, NULL, ?, 0)
    `).run(messageId, scope || 'all', senderId, text, now);

    const broadcastEvent = {
      t: 'broadcast',
      message: {
        id: messageId,
        channel_id: scope || 'all',
        sender_id: senderId,
        type: 'broadcast',
        body: text,
        created_at: now,
      },
      emergency: isEmergency,
    };

    if (scope && scope !== 'all') {
      const teamUsers = db.prepare(`
        SELECT DISTINCT m.user_id
        FROM members m
        JOIN channels c ON m.channel_id = c.id
        WHERE c.team_id = ?
      `).all(scope) as { user_id: string }[];

      for (const u of teamUsers) {
        sendToUser(u.user_id, broadcastEvent);
      }
    } else {
      broadcastToAll(broadcastEvent);
    }

    return reply.send({ message_id: messageId });
  });

  // Admin: Acks tracker
  fastify.get('/admin/acks/:message_id', { preHandler: requireAdmin }, async (request: FastifyRequest<{ Params: { message_id: string } }>, reply: FastifyReply) => {
    const { message_id } = request.params;

    const message = db.prepare('SELECT channel_id FROM messages WHERE id = ?').get(message_id) as { channel_id: string } | undefined;

    const acked = db.prepare(`
      SELECT u.id, u.name, a.at
      FROM acks a
      JOIN users u ON a.user_id = u.id
      WHERE a.message_id = ?
    `).all(message_id) as { id: string; name: string; at: number }[];

    const ackedIds = new Set(acked.map(a => a.id));

    let targetUsers: { id: string; name: string }[] = [];
    if (message && message.channel_id !== 'all') {
      targetUsers = db.prepare(`
        SELECT DISTINCT u.id, u.name
        FROM users u
        JOIN members m ON u.id = m.user_id
        JOIN channels c ON m.channel_id = c.id
        WHERE c.team_id = ? AND u.revoked = 0
      `).all(message.channel_id) as { id: string; name: string }[];
    } else {
      targetUsers = db.prepare('SELECT id, name FROM users WHERE revoked = 0').all() as { id: string; name: string }[];
    }

    const pending = targetUsers.filter(u => !ackedIds.has(u.id));

    return reply.send({ acked, pending });
  });

  // Admin: Create team
  fastify.post('/admin/teams', { preHandler: requireAdmin }, async (request: FastifyRequest<{ Body: CreateTeamBody }>, reply: FastifyReply) => {
    const { name } = request.body || {};
    if (!name) {
      return reply.status(400).send({ error: 'Team name is required' });
    }

    const teamId = randomUUID();
    db.prepare('INSERT INTO teams (id, name) VALUES (?, ?)').run(teamId, name.trim());

    return reply.send({
      id: teamId,
      name: name.trim(),
    });
  });

  // Admin: List teams
  fastify.get('/admin/teams', { preHandler: requireAdmin }, async (_request, reply: FastifyReply) => {
    const teams = db.prepare('SELECT id, name FROM teams').all();
    return reply.send(teams);
  });

  // Admin: Create channel
  fastify.post('/admin/channels', { preHandler: requireAdmin }, async (request: FastifyRequest<{ Body: CreateChannelBody }>, reply: FastifyReply) => {
    const { team_id, name, kind } = request.body || {};
    if (!name || !kind) {
      return reply.status(400).send({ error: 'name and kind are required' });
    }

    const channelId = randomUUID();
    db.prepare('INSERT INTO channels (id, team_id, name, kind) VALUES (?, ?, ?, ?)').run(channelId, team_id || null, name.trim(), kind);

    // Auto-assign channel to all members of this team
    if (team_id) {
      db.prepare(`
        INSERT OR IGNORE INTO members (user_id, channel_id)
        SELECT DISTINCT m.user_id, ? as channel_id
        FROM members m
        JOIN channels c ON m.channel_id = c.id
        WHERE c.team_id = ?
      `).run(channelId, team_id);
    }

    return reply.send({
      id: channelId,
      team_id: team_id || null,
      name: name.trim(),
      kind,
    });
  });

  // Admin: List channels
  fastify.get('/admin/channels', { preHandler: requireAdmin }, async (_request, reply: FastifyReply) => {
    const channels = db.prepare('SELECT id, team_id, name, kind FROM channels').all();
    return reply.send(channels);
  });

  // Admin: Create invite
  fastify.post('/admin/invites', { preHandler: requireAdmin }, async (request: FastifyRequest<{ Body: CreateInviteBody }>, reply: FastifyReply) => {
    const { team_id, role } = request.body || {};
    if (!role || (role !== 'admin' && role !== 'member')) {
      return reply.status(400).send({ error: 'Valid role (admin | member) is required' });
    }

    const code = randomBytes(4).toString('hex').toUpperCase();
    db.prepare('INSERT INTO invites (code, team_id, role, expires_at, used) VALUES (?, ?, ?, NULL, 0)').run(code, team_id || null, role);

    const hostHeader = request.headers.host || '127.0.0.1:3000';
    const [rawHost, rawPort] = hostHeader.split(':');
    const port = Number(rawPort) || 3000;
    const host = rawHost || '127.0.0.1';

    const payload = { host, port, code };
    const qr_png_base64 = await QRCode.toDataURL(JSON.stringify(payload));

    return reply.send({
      code,
      qr_png_base64,
      payload,
    });
  });

  // Admin: Revoke user
  fastify.post('/admin/users/:id/revoke', { preHandler: requireAdmin }, async (request: FastifyRequest<{ Params: { id: string } }>, reply: FastifyReply) => {
    const { id } = request.params;
    db.prepare('UPDATE users SET revoked = 1 WHERE id = ?').run(id);
    return reply.send({ ok: true });
  });
}
