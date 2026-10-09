import WebSocket from 'ws';
import { randomBytes, randomUUID } from 'node:crypto';
import Database from 'better-sqlite3';

const db = new Database('data.db');

async function main() {
  console.log('--- Starting P3 Floor Control & LiveKit Check ---');

  // Setup team & channel
  const teamId = randomUUID();
  db.prepare('INSERT INTO teams (id, name) VALUES (?, ?)').run(teamId, 'P3 Team');

  const channelId = randomUUID();
  db.prepare('INSERT INTO channels (id, team_id, name, kind) VALUES (?, ?, ?, ?)').run(channelId, teamId, 'P3 Channel', 'team');

  const codeA = randomBytes(4).toString('hex').toUpperCase();
  const codeB = randomBytes(4).toString('hex').toUpperCase();
  db.prepare('INSERT INTO invites (code, team_id, role, expires_at, used) VALUES (?, ?, ?, NULL, 0)').run(codeA, teamId, 'member');
  db.prepare('INSERT INTO invites (code, team_id, role, expires_at, used) VALUES (?, ?, ?, NULL, 0)').run(codeB, teamId, 'member');

  const joinA = await fetch('http://localhost:3000/auth/join', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ code: codeA, name: 'Alice' })
  }).then(r => r.json());

  const joinB = await fetch('http://localhost:3000/auth/join', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ code: codeB, name: 'Bob' })
  }).then(r => r.json());

  // Connect WebSockets to listen for floor events
  const wsA = new WebSocket(`ws://localhost:3000/ws?token=${joinA.jwt}`);
  const wsB = new WebSocket(`ws://localhost:3000/ws?token=${joinB.jwt}`);

  await Promise.all([
    new Promise(res => wsA.on('open', res)),
    new Promise(res => wsB.on('open', res)),
  ]);

  // 1. Grant: Alice requests floor (priority 1)
  const req1 = await fetch('http://localhost:3000/floor/request', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${joinA.jwt}`
    },
    body: JSON.stringify({ channel_id: channelId, priority: 1 })
  }).then(r => r.json());

  if (req1.granted === true && req1.holder === joinA.user.id) {
    console.log('[Step 1: Floor Grant] PASS');
  } else {
    throw new Error('Step 1 Failed: Floor was not granted to Alice');
  }

  // 2. Deny: Bob requests floor (priority 1, same priority)
  const req2 = await fetch('http://localhost:3000/floor/request', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${joinB.jwt}`
    },
    body: JSON.stringify({ channel_id: channelId, priority: 1 })
  }).then(r => r.json());

  if (req2.granted === false && req2.holder === joinA.user.id) {
    console.log('[Step 2: Floor Deny] PASS');
  } else {
    throw new Error('Step 2 Failed: Floor was not denied to Bob');
  }

  // 3. Pre-empt: Bob requests floor with priority 3 (Emergency)
  const preEmptPromise = new Promise<any>((resolve) => {
    wsA.on('message', (raw) => {
      const data = JSON.parse(raw.toString());
      if (data.t === 'floor' && data.channel_id === channelId && data.state === 'released' && data.user_id === joinA.user.id) {
        resolve(data);
      }
    });
  });

  const req3 = await fetch('http://localhost:3000/floor/request', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${joinB.jwt}`
    },
    body: JSON.stringify({ channel_id: channelId, priority: 3 })
  }).then(r => r.json());

  const preEmptEvent = await Promise.race([
    preEmptPromise,
    new Promise((_, reject) => setTimeout(() => reject(new Error('Timeout waiting for Alice pre-emption event')), 3000))
  ]);

  if (req3.granted === true && req3.holder === joinB.user.id && preEmptEvent) {
    console.log('[Step 3: Priority Pre-emption] PASS');
  } else {
    throw new Error('Step 3 Failed: Priority pre-emption did not work properly');
  }

  // Release Bob's floor
  await fetch('http://localhost:3000/floor/release', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${joinB.jwt}`
    },
    body: JSON.stringify({ channel_id: channelId })
  });

  // 4. Timeout: Alice acquires with short timeout 800ms
  const timeoutReleasePromise = new Promise<any>((resolve) => {
    wsB.on('message', (raw) => {
      const data = JSON.parse(raw.toString());
      if (data.t === 'floor' && data.channel_id === channelId && data.state === 'released' && data.user_id === joinA.user.id) {
        resolve(data);
      }
    });
  });

  const req4 = await fetch('http://localhost:3000/floor/request', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${joinA.jwt}`
    },
    body: JSON.stringify({ channel_id: channelId, priority: 1, timeout_ms: 800 })
  }).then(r => r.json());

  const autoReleased = await Promise.race([
    timeoutReleasePromise,
    new Promise((_, reject) => setTimeout(() => reject(new Error('Timeout waiting for auto-release')), 3000))
  ]);

  if (req4.granted && autoReleased) {
    console.log('[Step 4: Auto-release Timeout] PASS');
  } else {
    throw new Error('Step 4 Failed: Floor did not auto-release on timeout');
  }

  // 5. LiveKit Token
  const lkTokenResp = await fetch(`http://localhost:3000/livekit/token?room=${channelId}`, {
    headers: { 'Authorization': `Bearer ${joinA.jwt}` }
  }).then(r => r.json());

  if (lkTokenResp.token && lkTokenResp.url) {
    console.log('[Step 5: LiveKit Token Generation] PASS');
  } else {
    throw new Error('Step 5 Failed: LiveKit token not generated');
  }

  wsA.close();
  wsB.close();
  console.log('All P3 checks passed successfully!');
}

main().catch(err => {
  console.error('P3 Check Failed:', err.message);
  process.exit(1);
});
