import WebSocket from 'ws';
import { randomBytes, randomUUID } from 'node:crypto';
import Database from 'better-sqlite3';

const db = new Database('data.db');

async function main() {
  console.log('--- Starting P2 WebSocket & Messaging Check ---');

  // 1. Setup Admin, Team, Channel, Invites
  const teamId = randomUUID();
  db.prepare('INSERT INTO teams (id, name) VALUES (?, ?)').run(teamId, 'P2 Team');

  const channelId = randomUUID();
  db.prepare('INSERT INTO channels (id, team_id, name, kind) VALUES (?, ?, ?, ?)').run(channelId, teamId, 'P2 Channel', 'team');

  const codeA = randomBytes(4).toString('hex').toUpperCase();
  const codeB = randomBytes(4).toString('hex').toUpperCase();
  db.prepare('INSERT INTO invites (code, team_id, role, expires_at, used) VALUES (?, ?, ?, NULL, 0)').run(codeA, teamId, 'member');
  db.prepare('INSERT INTO invites (code, team_id, role, expires_at, used) VALUES (?, ?, ?, NULL, 0)').run(codeB, teamId, 'member');

  // Join User A
  const joinA = await fetch('http://localhost:3000/auth/join', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ code: codeA, name: 'Alice' })
  }).then(r => r.json());

  // Join User B
  const joinB = await fetch('http://localhost:3000/auth/join', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ code: codeB, name: 'Bob' })
  }).then(r => r.json());

  if (!joinA.jwt || !joinB.jwt) {
    throw new Error('Failed to join users Alice and Bob');
  }
  console.log('[Step 1: Setup & Join] PASS');

  // 2. Connect WebSockets
  const wsA = new WebSocket(`ws://localhost:3000/ws?token=${joinA.jwt}`);
  const wsB = new WebSocket(`ws://localhost:3000/ws?token=${joinB.jwt}`);

  await Promise.all([
    new Promise(res => wsA.on('open', res)),
    new Promise(res => wsB.on('open', res)),
  ]);
  console.log('[Step 2: WebSocket Connect] PASS');

  // 3. User A sends message -> User B receives
  const msg1Id = randomUUID();
  const bPromise = new Promise<any>((resolve) => {
    wsB.on('message', (raw) => {
      const data = JSON.parse(raw.toString());
      if (data.t === 'message' && data.message.id === msg1Id) {
        resolve(data.message);
      }
    });
  });

  const send1 = await fetch('http://localhost:3000/messages', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${joinA.jwt}`
    },
    body: JSON.stringify({
      id: msg1Id,
      channel_id: channelId,
      type: 'text',
      body: 'Hello Bob from Alice!',
      created_at: Date.now()
    })
  }).then(r => r.json());

  const receivedByB = await Promise.race([
    bPromise,
    new Promise((_, reject) => setTimeout(() => reject(new Error('Timeout waiting for Bob to receive message')), 4000))
  ]);

  if (receivedByB && receivedByB.body === 'Hello Bob from Alice!') {
    console.log('[Step 3: Alice -> Bob message delivery] PASS');
  } else {
    throw new Error('Bob did not receive matching message');
  }

  // 4. User B sends message -> User A receives
  const msg2Id = randomUUID();
  const aPromise = new Promise<any>((resolve) => {
    wsA.on('message', (raw) => {
      const data = JSON.parse(raw.toString());
      if (data.t === 'message' && data.message.id === msg2Id) {
        resolve(data.message);
      }
    });
  });

  const send2 = await fetch('http://localhost:3000/messages', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${joinB.jwt}`
    },
    body: JSON.stringify({
      id: msg2Id,
      channel_id: channelId,
      type: 'text',
      body: 'Hello Alice from Bob!',
      created_at: Date.now()
    })
  }).then(r => r.json());

  const receivedByA = await Promise.race([
    aPromise,
    new Promise((_, reject) => setTimeout(() => reject(new Error('Timeout waiting for Alice to receive message')), 4000))
  ]);

  if (receivedByA && receivedByA.body === 'Hello Alice from Bob!') {
    console.log('[Step 4: Bob -> Alice message delivery] PASS');
  } else {
    throw new Error('Alice did not receive matching message');
  }

  // 5. Test Ack & Fetch Messages
  const ackResp = await fetch('http://localhost:3000/ack', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${joinB.jwt}`
    },
    body: JSON.stringify({ message_id: msg1Id })
  }).then(r => r.json());

  const listResp = await fetch(`http://localhost:3000/channels/${channelId}/messages?after_seq=0`, {
    headers: { 'Authorization': `Bearer ${joinA.jwt}` }
  }).then(r => r.json());

  if (ackResp.ok && Array.isArray(listResp) && listResp.length >= 2) {
    console.log('[Step 5: Ack & Sync History] PASS');
  } else {
    throw new Error('Failed to verify ack or message history sync');
  }

  wsA.close();
  wsB.close();
  console.log('All P2 checks passed successfully!');
}

main().catch(err => {
  console.error('P2 Check Failed:', err.message);
  process.exit(1);
});
