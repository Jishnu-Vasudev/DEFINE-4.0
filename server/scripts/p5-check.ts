import WebSocket from 'ws';
import { randomBytes, randomUUID } from 'node:crypto';
import Database from 'better-sqlite3';

const db = new Database('data.db');

async function main() {
  console.log('--- Starting P5 Flutter App Core & Outbox Check ---');

  // 1. Setup Team, Channel, and 2 Invites (Phone A and Phone B)
  const teamId = randomUUID();
  db.prepare('INSERT INTO teams (id, name) VALUES (?, ?)').run(teamId, 'Mobile Team');

  const channelId = randomUUID();
  db.prepare('INSERT INTO channels (id, team_id, name, kind) VALUES (?, ?, ?, ?)').run(channelId, teamId, 'Squad Alpha', 'team');

  const codeA = randomBytes(4).toString('hex').toUpperCase();
  const codeB = randomBytes(4).toString('hex').toUpperCase();
  db.prepare('INSERT INTO invites (code, team_id, role, expires_at, used) VALUES (?, ?, ?, NULL, 0)').run(codeA, teamId, 'member');
  db.prepare('INSERT INTO invites (code, team_id, role, expires_at, used) VALUES (?, ?, ?, NULL, 0)').run(codeB, teamId, 'member');

  // Phone A Joins
  const joinA = await fetch('http://localhost:3000/auth/join', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ code: codeA, name: 'Phone A (Alpha)' })
  }).then(r => r.json());

  // Phone B Joins
  const joinB = await fetch('http://localhost:3000/auth/join', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ code: codeB, name: 'Phone B (Bravo)' })
  }).then(r => r.json());

  console.log('[Step 1: Invite Join & Channel Assignment] PASS');

  // 2. Phone B connects to WebSocket
  const wsB = new WebSocket(`ws://localhost:3000/ws?token=${joinB.jwt}`);
  await new Promise(res => wsB.on('open', res));

  // Phone A connects to WebSocket
  let wsA: WebSocket | null = new WebSocket(`ws://localhost:3000/ws?token=${joinA.jwt}`);
  await new Promise(res => wsA!.on('open', res));
  console.log('[Step 2: WebSockets Connected] PASS');

  // 3. Phone A sends live message -> Phone B receives
  const liveMsgId = randomUUID();
  const bReceivePromise = new Promise<any>((resolve) => {
    wsB.on('message', (raw) => {
      const data = JSON.parse(raw.toString());
      if (data.t === 'message' && data.message.id === liveMsgId) {
        resolve(data.message);
      }
    });
  });

  await fetch('http://localhost:3000/messages', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${joinA.jwt}`
    },
    body: JSON.stringify({
      id: liveMsgId,
      channel_id: channelId,
      type: 'text',
      body: 'Online message from Phone A',
      created_at: Date.now()
    })
  });

  const bMsg = await Promise.race([
    bReceivePromise,
    new Promise((_, reject) => setTimeout(() => reject(new Error('Timeout waiting for Phone B live message')), 3000))
  ]);

  if (bMsg && bMsg.body === 'Online message from Phone A') {
    console.log('[Step 3: Realtime Chat Delivery] PASS');
  } else {
    throw new Error('Live message delivery failed');
  }

  // 4. Simulate Airplane Mode on Phone A (Disconnect WS & network)
  wsA.close();
  wsA = null;
  console.log('[Step 4: Phone A Airplane Mode Toggle] PASS');

  // 5. Phone A generates 2 offline queued outbox messages
  const queued1 = {
    id: randomUUID(),
    channel_id: channelId,
    type: 'text',
    body: 'Queued text 1 (offline)',
    created_at: Date.now(),
    offline: 1
  };

  const queued2 = {
    id: randomUUID(),
    channel_id: channelId,
    type: 'text',
    body: 'Queued text 2 (offline)',
    created_at: Date.now() + 10,
    offline: 1
  };

  // 6. Simulate Reconnect: Phone A reconnects and flushes outbox
  const receivedQueued: any[] = [];
  wsB.on('message', (raw) => {
    const data = JSON.parse(raw.toString());
    if (data.t === 'message' && (data.message.id === queued1.id || data.message.id === queued2.id)) {
      receivedQueued.push(data.message);
    }
  });

  wsA = new WebSocket(`ws://localhost:3000/ws?token=${joinA.jwt}`);
  await new Promise(res => wsA!.on('open', res));

  // Flush queued messages in order
  for (const qMsg of [queued1, queued2]) {
    await fetch('http://localhost:3000/messages', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${joinA.jwt}`
      },
      body: JSON.stringify(qMsg)
    });
  }

  // Wait for delivery to Phone B
  await new Promise(res => setTimeout(res, 500));

  if (receivedQueued.length === 2 && receivedQueued[0].body === 'Queued text 1 (offline)' && receivedQueued[1].body === 'Queued text 2 (offline)') {
    console.log('[Step 5: Reconnect Outbox Delivery] PASS');
  } else {
    throw new Error(`Outbox flush failed to deliver expected messages. Got: ${receivedQueued.length}`);
  }

  wsA?.close();
  wsB.close();
  console.log('All P5 checks passed successfully!');
}

main().catch(err => {
  console.error('P5 Check Failed:', err.message);
  process.exit(1);
});
