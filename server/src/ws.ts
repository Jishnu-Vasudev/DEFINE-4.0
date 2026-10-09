import { FastifyInstance } from 'fastify';
import { WebSocket } from 'ws';
import { verifyJwt } from './auth.js';
import { db } from './db.js';

export interface ClientConnection {
  ws: WebSocket;
  userId: string;
  lastPing: number;
  offlineMode: boolean;
}

const connections = new Map<WebSocket, ClientConnection>();
const userSockets = new Map<string, Set<WebSocket>>();

export function isUserOnline(userId: string): boolean {
  const sockets = userSockets.get(userId);
  return !!sockets && sockets.size > 0;
}

export function getUserOfflineMode(userId: string): boolean {
  const sockets = userSockets.get(userId);
  if (!sockets || sockets.size === 0) return false;
  for (const ws of sockets) {
    const conn = connections.get(ws);
    if (conn?.offlineMode) return true;
  }
  return false;
}

export function broadcastToAll(payload: object) {
  const msg = JSON.stringify(payload);
  for (const [ws] of connections) {
    if (ws.readyState === WebSocket.OPEN) {
      ws.send(msg);
    }
  }
}

export function broadcastToChannel(channelId: string, payload: object) {
  const members = db.prepare('SELECT user_id FROM members WHERE channel_id = ?').all(channelId) as { user_id: string }[];
  const memberSet = new Set(members.map(m => m.user_id));
  const msg = JSON.stringify(payload);

  for (const [ws, conn] of connections) {
    if (memberSet.has(conn.userId) && ws.readyState === WebSocket.OPEN) {
      ws.send(msg);
    }
  }
}

export function sendToUser(userId: string, payload: object) {
  const sockets = userSockets.get(userId);
  if (!sockets) return;
  const msg = JSON.stringify(payload);
  for (const ws of sockets) {
    if (ws.readyState === WebSocket.OPEN) {
      ws.send(msg);
    }
  }
}

export function registerWs(fastify: FastifyInstance) {
  fastify.get('/ws', { websocket: true }, (socket, req) => {
    const url = new URL(req.url, `http://${req.headers.host || 'localhost'}`);
    const token = url.searchParams.get('token');

    if (!token) {
      socket.close(4001, 'Unauthorized: missing token');
      return;
    }

    const payload = verifyJwt(token);
    if (!payload || !payload.uid) {
      socket.close(4001, 'Unauthorized: invalid token');
      return;
    }

    const user = db.prepare('SELECT id, name, role, revoked FROM users WHERE id = ?').get(payload.uid) as {
      id: string;
      name: string;
      role: string;
      revoked: number;
    } | undefined;

    if (!user || user.revoked === 1) {
      socket.close(4001, 'Unauthorized: revoked');
      return;
    }

    const userId = user.id;
    const now = Date.now();

    // Update last seen
    db.prepare('UPDATE users SET last_seen = ? WHERE id = ?').run(now, userId);

    const conn: ClientConnection = {
      ws: socket,
      userId,
      lastPing: now,
      offlineMode: false,
    };

    connections.set(socket, conn);
    if (!userSockets.has(userId)) {
      userSockets.set(userId, new Set());
      // First connection for this user -> emit online presence
      broadcastToAll({ t: 'presence', user_id: userId, online: true });
    }
    userSockets.get(userId)!.add(socket);

    socket.on('message', (raw) => {
      try {
        const data = JSON.parse(raw.toString());
        if (data.t === 'ping') {
          conn.lastPing = Date.now();
          db.prepare('UPDATE users SET last_seen = ? WHERE id = ?').run(conn.lastPing, userId);
        } else if (data.t === 'offline_mode') {
          conn.offlineMode = !!data.on;
        }
      } catch {
        // Ignore malformed client frames
      }
    });

    const cleanup = () => {
      connections.delete(socket);
      const sockets = userSockets.get(userId);
      if (sockets) {
        sockets.delete(socket);
        if (sockets.size === 0) {
          userSockets.delete(userId);
          broadcastToAll({ t: 'presence', user_id: userId, online: false });
        }
      }
    };

    socket.on('close', cleanup);
    socket.on('error', cleanup);
  });

  // Background ping timeout checker (every 5s, timeout after 25s)
  setInterval(() => {
    const now = Date.now();
    for (const [ws, conn] of connections) {
      if (now - conn.lastPing > 25000) {
        ws.close(4000, 'Ping timeout');
      }
    }
  }, 5000);
}
