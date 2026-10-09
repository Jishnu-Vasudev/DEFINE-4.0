import WebSocket from 'ws';
import { randomBytes, randomUUID } from 'node:crypto';
import Database from 'better-sqlite3';

const db = new Database('data.db');

async function main() {
  console.log('--- Starting P6 PTT in App Check ---');

  // 1. Setup Team, Channel, and 2 phone users
  const teamId = randomUUID();
  db.prepare('INSERT INTO teams (id, name) VALUES (?, ?)').run(teamId, 'PTT Team');

  const channelId = randomUUID();
  db.prepare('INSERT INTO channels (id, team_id, name, kind) VALUES (?, ?, ?, ?)').run(channelId, teamId, 'PTT Channel', 'team');

  const codeA = randomBytes(4).toString('hex').toUpperCase();
  const codeB = randomBytes(4).toString('hex').toUpperCase();
  db.prepare('INSERT INTO invites (code, team_id, role, expires_at, used) VALUES (?, ?, ?, NULL, 0)').run(codeA, teamId, 'member');
  db.prepare('INSERT INTO invites (code, team_id, role, expires_at, used) VALUES (?, ?, ?, NULL, 0)').run(codeB, teamId, 'member');

  const joinA = await fetch('http://localhost:3000/auth/join', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ code: codeA, name: 'Phone Alpha' })
  }).then(r => r.json());

  const joinB = await fetch('http://localhost:3000/auth/join', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ code: codeB, name: 'Phone Bravo' })
  }).then(r => r.json());

  // 2. Connect WebSockets for both phones
  const wsA = new WebSocket(`ws://localhost:3000/ws?token=${joinA.jwt}`);
  const wsB = new WebSocket(`ws://localhost:3000/ws?token=${joinB.jwt}`);

  await Promise.all([
    new Promise(res => wsA.on('open', res)),
    new Promise(res => wsB.on('open', res)),
  ]);

  // 3. Phone A requests floor -> granted; Phone B receives talker update
  const floorGrantedPromise = new Promise<any>((resolve) => {
    wsB.on('message', (raw) => {
      const data = JSON.parse(raw.toString());
      if (data.t === 'floor' && data.channel_id === channelId && data.state === 'granted') {
        resolve(data);
      }
    });
  });

  const reqA = await fetch('http://localhost:3000/floor/request', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${joinA.jwt}`
    },
    body: JSON.stringify({ channel_id: channelId, priority: 1 })
  }).then(r => r.json());

  const bFloorEvent = await Promise.race([
    floorGrantedPromise,
    new Promise((_, reject) => setTimeout(() => reject(new Error('Timeout waiting for Phone B floor event')), 3000))
  ]);

  if (reqA.granted === true && bFloorEvent.name === 'Phone Alpha') {
    console.log('[Step 1: Phone A Floor Granted & Broadcast to Phone B] PASS');
  } else {
    throw new Error('Floor grant failed');
  }

  // 4. Simultaneous press: Phone B tries to request floor -> DENIED
  const reqB = await fetch('http://localhost:3000/floor/request', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${joinB.jwt}`
    },
    body: JSON.stringify({ channel_id: channelId, priority: 1 })
  }).then(r => r.json());

  if (reqB.granted === false && reqB.holder === joinA.user.id) {
    console.log('[Step 2: Simultaneous PTT Press Denied to Phone B] PASS');
  } else {
    throw new Error('Simultaneous press was not denied');
  }

  // 5. Phone A releases floor -> Phone B receives released event
  const floorReleasePromise = new Promise<any>((resolve) => {
    wsB.on('message', (raw) => {
      const data = JSON.parse(raw.toString());
      if (data.t === 'floor' && data.channel_id === channelId && data.state === 'released') {
        resolve(data);
      }
    });
  });

  await fetch('http://localhost:3000/floor/release', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${joinA.jwt}`
    },
    body: JSON.stringify({ channel_id: channelId })
  });

  const bReleaseEvent = await Promise.race([
    floorReleasePromise,
    new Promise((_, reject) => setTimeout(() => reject(new Error('Timeout waiting for Phone B floor release')), 3000))
  ]);

  if (bReleaseEvent) {
    console.log('[Step 3: Floor Release Notified] PASS');
  } else {
    throw new Error('Floor release failed');
  }

  // 6. Emergency broadcast with full-screen alert & Ack flow
  const alertPromise = new Promise<any>((resolve) => {
    wsA.on('message', (raw) => {
      const data = JSON.parse(raw.toString());
      if (data.t === 'broadcast' && data.emergency === true) {
        resolve(data);
      }
    });
  });

  // Admin sends emergency broadcast
  const adminCode = randomBytes(4).toString('hex').toUpperCase();
  db.prepare('INSERT INTO invites (code, team_id, role, expires_at, used) VALUES (?, NULL, \'admin\', NULL, 0)').run(adminCode);
  const adminJoin = await fetch('http://localhost:3000/auth/join', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ code: adminCode, name: 'Admin Commander' })
  }).then(r => r.json());

  const bcastRes = await fetch('http://localhost:3000/admin/broadcast', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${adminJoin.jwt}`
    },
    body: JSON.stringify({ text: 'EMERGENCY: Code Red', scope: 'all', emergency: true })
  }).then(r => r.json());

  const receivedAlert = await Promise.race([
    alertPromise,
    new Promise((_, reject) => setTimeout(() => reject(new Error('Timeout waiting for alert')), 3000))
  ]);

  // Phone A Acknowledges
  const ackRes = await fetch('http://localhost:3000/ack', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${joinA.jwt}`
    },
    body: JSON.stringify({ message_id: bcastRes.message_id })
  }).then(r => r.json());

  if (receivedAlert && ackRes.ok) {
    console.log('[Step 4: Emergency Broadcast & Phone A Ack] PASS');
  } else {
    throw new Error('Emergency broadcast ack flow failed');
  }

  wsA.close();
  wsB.close();
  console.log('All P6 checks passed successfully!');
}

main().catch(err => {
  console.error('P6 Check Failed:', err.message);
  process.exit(1);
});
