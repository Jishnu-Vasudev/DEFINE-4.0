import Fastify from 'fastify';
import cors from '@fastify/cors';
import websocket from '@fastify/websocket';
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

  await fastify.register(websocket);

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
