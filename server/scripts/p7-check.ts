import WebSocket from 'ws';
import { randomBytes, randomUUID } from 'node:crypto';
import Database from 'better-sqlite3';

const db = new Database('data.db');

async function main() {
  console.log('--- Starting P7 Media + Call Check ---');

  // 1. Setup Team, Channel, and 2 Users (User A & User B)
  const teamId = randomUUID();
  db.prepare('INSERT INTO teams (id, name) VALUES (?, ?)').run(teamId, 'Media Team');

  const channelId = randomUUID();
  db.prepare('INSERT INTO channels (id, team_id, name, kind) VALUES (?, ?, ?, ?)').run(channelId, teamId, 'Media Channel', 'team');

  const codeA = randomBytes(4).toString('hex').toUpperCase();
  const codeB = randomBytes(4).toString('hex').toUpperCase();
  db.prepare('INSERT INTO invites (code, team_id, role, expires_at, used) VALUES (?, ?, ?, NULL, 0)').run(codeA, teamId, 'member');
  db.prepare('INSERT INTO invites (code, team_id, role, expires_at, used) VALUES (?, ?, ?, NULL, 0)').run(codeB, teamId, 'member');

  const joinA = await fetch('http://localhost:3000/auth/join', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ code: codeA, name: 'Alice Media' })
  }).then(r => r.json());

  const joinB = await fetch('http://localhost:3000/auth/join', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ code: codeB, name: 'Bob Media' })
  }).then(r => r.json());

  // Connect WebSockets
  const wsA = new WebSocket(`ws://localhost:3000/ws?token=${joinA.jwt}`);
  const wsB = new WebSocket(`ws://localhost:3000/ws?token=${joinB.jwt}`);

  await Promise.all([
    new Promise(res => wsA.on('open', res)),
    new Promise(res => wsB.on('open', res)),
  ]);

  // 2. Photo Upload: Alice uploads a dummy JPEG buffer
  const samplePhoto = Buffer.from('FakeJPEGImageContentData1234567890');
  const formData = new FormData();
  formData.append('file', new Blob([samplePhoto], { type: 'image/jpeg' }), 'photo.jpg');

  const uploadRes = await fetch('http://localhost:3000/media', {
    method: 'POST',
    headers: { 'Authorization': `Bearer ${joinA.jwt}` },
    body: formData
  }).then(r => r.json());

  if (uploadRes.media) {
    console.log('[Step 1: Media Photo Upload] PASS');
  } else {
    throw new Error('Media upload failed');
  }

  // 3. Photo Download / Fetch: Verify GET /media/:file works with auth
  const downloadRes = await fetch(`http://localhost:3000/media/${uploadRes.media}?token=${joinB.jwt}`);
  const downloadedBytes = await downloadRes.arrayBuffer();

  if (downloadRes.status === 200 && downloadedBytes.byteLength === samplePhoto.length) {
    console.log('[Step 2: Media Photo Retrieval] PASS');
  } else {
    throw new Error('Media retrieval failed');
  }

  // 4. Send Image Message: Alice sends message with type=image -> Bob receives
  const imageMsgId = randomUUID();
  const bobImagePromise = new Promise<any>((resolve) => {
    wsB.on('message', (raw) => {
      const data = JSON.parse(raw.toString());
      if (data.t === 'message' && data.message.id === imageMsgId) {
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
      id: imageMsgId,
      channel_id: channelId,
      type: 'image',
      body: 'Check this tactical photo',
      media: uploadRes.media,
      created_at: Date.now()
    })
  });

  const receivedImageMsg = await Promise.race([
    bobImagePromise,
    new Promise((_, reject) => setTimeout(() => reject(new Error('Timeout waiting for Bob to receive image message')), 3000))
  ]);

  if (receivedImageMsg.type === 'image' && receivedImageMsg.media === uploadRes.media) {
    console.log('[Step 3: Image Message Delivery] PASS');
  } else {
    throw new Error('Image message delivery failed');
  }

  // 5. 1:1 Voice Call Invite: Alice calls Bob
  const callInvitePromise = new Promise<any>((resolve) => {
    wsB.on('message', (raw) => {
      const data = JSON.parse(raw.toString());
      if (data.t === 'call_invite' && data.from === joinA.user.id) {
        resolve(data);
      }
    });
  });

  const callRes = await fetch('http://localhost:3000/call/invite', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${joinA.jwt}`
    },
    body: JSON.stringify({ to_user_id: joinB.user.id })
  }).then(r => r.json());

  const receivedCallInvite = await Promise.race([
    callInvitePromise,
    new Promise((_, reject) => setTimeout(() => reject(new Error('Timeout waiting for Bob call invite')), 3000))
  ]);

  if (callRes.room && receivedCallInvite.room === callRes.room) {
    console.log('[Step 4: 1:1 Voice Call Invite & Notification] PASS');
  } else {
    throw new Error('Call invite failed');
  }

  // 6. LiveKit Token generation for 1:1 call room
  const [tokenA, tokenB] = await Promise.all([
    fetch(`http://localhost:3000/livekit/token?room=${callRes.room}`, { headers: { 'Authorization': `Bearer ${joinA.jwt}` } }).then(r => r.json()),
    fetch(`http://localhost:3000/livekit/token?room=${callRes.room}`, { headers: { 'Authorization': `Bearer ${joinB.jwt}` } }).then(r => r.json()),
  ]);

  if (tokenA.token && tokenB.token && tokenA.url === tokenB.url) {
    console.log('[Step 5: Call Room LiveKit Token Generation] PASS');
  } else {
    throw new Error('Call token generation failed');
  }

  wsA.close();
  wsB.close();
  console.log('All P7 checks passed successfully!');
}

main().catch(err => {
  console.error('P7 Check Failed:', err.message);
  process.exit(1);
});
