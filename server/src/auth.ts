import { FastifyRequest, FastifyReply } from 'fastify';
import jwt from 'jsonwebtoken';
import { db } from './db.js';

const JWT_SECRET = process.env.JWT_SECRET || 'dev-secret-ptt-key-2026';

export interface TokenPayload {
  uid: string;
  role: string;
}

export interface UserRow {
  id: string;
  name: string;
  role: string;
  revoked: number;
  last_seen: number | null;
}

declare module 'fastify' {
  interface FastifyRequest {
    user?: UserRow;
  }
}

export function signJwt(payload: TokenPayload): string {
  return jwt.sign(payload, JWT_SECRET, { expiresIn: '7d' });
}

export function verifyJwt(token: string): TokenPayload | null {
  try {
    return jwt.verify(token, JWT_SECRET) as TokenPayload;
  } catch {
    return null;
  }
}

export async function requireAuth(request: FastifyRequest, reply: FastifyReply) {
  const authHeader = request.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return reply.status(401).send({ error: 'Missing or invalid Authorization header' });
  }

  const token = authHeader.slice(7).trim();
  const payload = verifyJwt(token);
  if (!payload || !payload.uid) {
    return reply.status(401).send({ error: 'Invalid token' });
  }

  const user = db.prepare('SELECT id, name, role, revoked, last_seen FROM users WHERE id = ?').get(payload.uid) as UserRow | undefined;
  if (!user || user.revoked === 1) {
    return reply.status(401).send({ error: 'Unauthorized or revoked' });
  }

  request.user = user;
}

export async function requireAdmin(request: FastifyRequest, reply: FastifyReply) {
  await requireAuth(request, reply);
  if (reply.sent) return;

  if (request.user?.role !== 'admin') {
    return reply.status(403).send({ error: 'Admin access required' });
  }
}
