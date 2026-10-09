import WebSocket from 'ws';
import { randomBytes, randomUUID } from 'node:crypto';
import Database from 'better-sqlite3';

const db = new Database('data.db');

async function main() {
  console.log('--- Starting P4 Admin Dashboard Check ---');

  // 1. Verify GET /admin returns static HTML
  const adminHtml = await fetch('http://localhost:3000/admin').then(r => r.text());
  if (adminHtml.includes('PTT Admin Console')) {
    console.log('[Step 1: Admin HTML Served] PASS');
  } else {
    throw new Error('Admin HTML not served at /admin');
  }

  // 2. Setup Admin and Member
  const adminCode = randomBytes(4).toString('hex').toUpperCase();
  db.prepare('INSERT INTO invites (code, team_id, role, expires_at, used) VALUES (?, NULL, \'admin\', NULL, 0)').run(adminCode);

  const adminJoin = await fetch('http://localhost:3000/auth/join', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ code: adminCode, name: 'Admin Boss' })
  }).then(r => r.json());

  const teamId = randomUUID();
  db.prepare('INSERT INTO teams (id, name) VALUES (?, ?)').run(teamId, 'Ops Team');

  const channelId = randomUUID();
  db.prepare('INSERT INTO channels (id, team_id, name, kind) VALUES (?, ?, ?, ?)').run(channelId, teamId, 'Ops Channel', 'team');

  const memberCode = randomBytes(4).toString('hex').toUpperCase();
  db.prepare('INSERT INTO invites (code, team_id, role, expires_at, used) VALUES (?, ?, ?, NULL, 0)').run(memberCode, teamId, 'member');

  const memberJoin = await fetch('http://localhost:3000/auth/join', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ code: memberCode, name: 'Field Agent' })
  }).then(r => r.json());

  // 3. Connect member to WebSocket
  const memberWs = new WebSocket(`ws://localhost:3000/ws?token=${memberJoin.jwt}`);
  await new Promise(res => memberWs.on('open', res));

  // 4. Admin Presence check
  const presence = await fetch('http://localhost:3000/admin/presence', {
    headers: { 'Authorization': `Bearer ${adminJoin.jwt}` }
  }).then(r => r.json());

  const onlineMember = presence.users.find((u: any) => u.id === memberJoin.user.id && u.online === true);
  if (onlineMember) {
    console.log('[Step 2: Admin Live Presence] PASS');
  } else {
    throw new Error('Member not listed as online in /admin/presence');
  }

  // 5. Admin Broadcast -> Member receives
  let broadcastMsgId = '';
  const broadcastPromise = new Promise<any>((resolve) => {
    memberWs.on('message', (raw) => {
      const data = JSON.parse(raw.toString());
      if (data.t === 'broadcast' && data.emergency === true) {
        resolve(data);
      }
    });
  });

  const bcastRes = await fetch('http://localhost:3000/admin/broadcast', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${adminJoin.jwt}`
    },
    body: JSON.stringify({
      text: 'Evacuate Sector 4 Immediately',
      scope: 'all',
      emergency: true
    })
  }).then(r => r.json());

  broadcastMsgId = bcastRes.message_id;

  const receivedBcast = await Promise.race([
    broadcastPromise,
    new Promise((_, reject) => setTimeout(() => reject(new Error('Timeout waiting for broadcast on WebSocket')), 4000))
  ]);

  if (receivedBcast && receivedBcast.message.body === 'Evacuate Sector 4 Immediately') {
    console.log('[Step 3: Emergency Broadcast delivery] PASS');
  } else {
    throw new Error('Broadcast delivery mismatch');
  }

  // 6. Member Acknowledges Broadcast
  await fetch('http://localhost:3000/ack', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${memberJoin.jwt}`
    },
    body: JSON.stringify({ message_id: broadcastMsgId })
  });

  // 7. Admin Checks Ack Tracker
  const acksRes = await fetch(`http://localhost:3000/admin/acks/${broadcastMsgId}`, {
    headers: { 'Authorization': `Bearer ${adminJoin.jwt}` }
  }).then(r => r.json());

  const isAcked = acksRes.acked.some((u: any) => u.id === memberJoin.user.id);
  if (isAcked) {
    console.log('[Step 4: Ack Tracker Verification] PASS');
  } else {
    throw new Error('Ack tracking failed');
  }

  memberWs.close();
  console.log('All P4 checks passed successfully!');
}

main().catch(err => {
  console.error('P4 Check Failed:', err.message);
  process.exit(1);
});
