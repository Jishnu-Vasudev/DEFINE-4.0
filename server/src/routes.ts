import { FastifyInstance, FastifyRequest, FastifyReply } from 'fastify';
import { randomBytes, randomUUID } from 'node:crypto';
import QRCode from 'qrcode';
import { db } from './db.js';
import { signJwt, requireAuth, requireAdmin } from './auth.js';
import { broadcastToChannel } from './ws.js';

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
