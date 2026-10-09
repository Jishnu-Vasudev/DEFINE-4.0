import Fastify from 'fastify';
import cors from '@fastify/cors';
import websocket from '@fastify/websocket';
import fastifyStatic from '@fastify/static';
import multipart from '@fastify/multipart';
import path from 'node:path';
import fs from 'node:fs';
import { initDb } from './db.js';
import { registerRoutes } from './routes.js';
import { registerWs } from './ws.js';

const fastify = Fastify({
  logger: true,
});

async function main() {
  initDb();

  await fastify.register(cors, {
    origin: true,
  });

  await fastify.register(multipart, {
    limits: {
      fileSize: 10 * 1024 * 1024, // 10MB
    },
  });

  await fastify.register(websocket);

  const adminDir = fs.existsSync(path.join(process.cwd(), 'admin'))
    ? path.join(process.cwd(), 'admin')
    : path.resolve(process.cwd(), '../admin');

  await fastify.register(fastifyStatic, {
    root: adminDir,
    prefix: '/admin/',
    decorateReply: true,
  });

  fastify.get('/admin', async (_req, reply) => {
    return reply.sendFile('index.html');
  });

  registerWs(fastify);
  await registerRoutes(fastify);

  fastify.get('/health', async () => {
    return { status: 'ok' };
  });

  const PORT = Number(process.env.PORT) || 3000;
  const HOST = process.env.HOST || '0.0.0.0';

  try {
    await fastify.listen({ port: PORT, host: HOST });
    console.log(`Server listening on http://${HOST}:${PORT}`);
  } catch (err) {
    fastify.log.error(err);
    process.exit(1);
  }
}

main();
