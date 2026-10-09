import WebSocket from 'ws';
import { randomBytes, randomUUID } from 'node:crypto';
import Database from 'better-sqlite3';

const db = new Database('data.db');

async function main() {
  console.log('--- Starting P8 Nearby Fallback Check ---');

  // 1. Setup Admin, Team, Channel, and Member
  const adminCode = randomBytes(4).toString('hex').toUpperCase();
  db.prepare('INSERT INTO invites (code, team_id, role, expires_at, used) VALUES (?, NULL, \'admin\', NULL, 0)').run(adminCode);
  const adminJoin = await fetch('http://localhost:3000/auth/join', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ code: adminCode, name: 'Admin Base' })
  }).then(r => r.json());

  const teamId = randomUUID();
  db.prepare('INSERT INTO teams (id, name) VALUES (?, ?)').run(teamId, 'Nearby Team');

  const channelId = randomUUID();
  db.prepare('INSERT INTO channels (id, team_id, name, kind) VALUES (?, ?, ?, ?)').run(channelId, teamId, 'Nearby Channel', 'team');

  const memberCode = randomBytes(4).toString('hex').toUpperCase();
  db.prepare('INSERT INTO invites (code, team_id, role, expires_at, used) VALUES (?, ?, ?, NULL, 0)').run(memberCode, teamId, 'member');
  const memberJoin = await fetch('http://localhost:3000/auth/join', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ code: memberCode, name: 'Scout 1' })
  }).then(r => r.json());

  // Connect WebSocket
  const ws = new WebSocket(`ws://localhost:3000/ws?token=${memberJoin.jwt}`);
  await new Promise(res => ws.on('open', res));

  // 2. Member signals offline_mode
  ws.send(JSON.stringify({ t: 'offline_mode', on: true }));
  await new Promise(res => setTimeout(res, 200));

  // Admin checks presence for offline_mode indicator
  const presence1 = await fetch('http://localhost:3000/admin/presence', {
    headers: { 'Authorization': `Bearer ${adminJoin.jwt}` }
  }).then(r => r.json());

  const scoutPres = presence1.users.find((u: any) => u.id === memberJoin.user.id);
  if (scoutPres && scoutPres.offline_mode === true) {
    console.log('[Step 1: Admin Offline Mode / Nearby Indicator] PASS');
  } else {
    throw new Error('Offline mode indicator not reflected in admin presence');
  }

  // 3. Simulate Nearby Exchange & Resync upon Server Return
  const nearbyTextId = randomUUID();
  const nearbySosId = randomUUID();
  const now = Date.now();

  // Reconnect / send offline_mode: false
  ws.send(JSON.stringify({ t: 'offline_mode', on: false }));

  // Post synced nearby text
  await fetch('http://localhost:3000/messages', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${memberJoin.jwt}`
    },
    body: JSON.stringify({
      id: nearbyTextId,
      channel_id: channelId,
      type: 'text',
      body: 'Mesh exchange message while out of server range',
      created_at: now - 5000,
      offline: 1
    })
  });

  // Post synced nearby SOS
  await fetch('http://localhost:3000/messages', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${memberJoin.jwt}`
    },
    body: JSON.stringify({
      id: nearbySosId,
      channel_id: channelId,
      type: 'sos',
      body: '🚨 SOS: Vehicle immobilized at coordinate grid 44',
      created_at: now - 3000,
      offline: 1
    })
  });

  // 4. Verify messages are persisted in DB tagged offline=1
  const messages = await fetch(`http://localhost:3000/channels/${channelId}/messages`, {
    headers: { 'Authorization': `Bearer ${memberJoin.jwt}` }
  }).then(r => r.json());

  const textMsg = messages.find((m: any) => m.id === nearbyTextId);
  const sosMsg = messages.find((m: any) => m.id === nearbySosId);

  if (textMsg && textMsg.offline === 1 && sosMsg && sosMsg.offline === 1 && sosMsg.type === 'sos') {
    console.log('[Step 2: Sync Back Messages Tagged offline=1] PASS');
  } else {
    throw new Error('Synced messages not properly tagged with offline=1');
  }

  ws.close();
  console.log('All P8 checks passed successfully!');
}

main().catch(err => {
  console.error('P8 Check Failed:', err.message);
  process.exit(1);
});
