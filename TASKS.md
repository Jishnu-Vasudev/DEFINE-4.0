# TASKS (do one phase per session, tick boxes, stop)

## P0 Scaffold
- [x] `docker-compose.yml` with livekit (`livekit/livekit-server --dev --node-ip ${NODE_IP}`, ports 7880, 7881, UDP 50000-50100)
- [x] `server/` Fastify + TS project, `npm run dev` starts on 0.0.0.0:3000, SQLite schema from CONTRACT.md auto-created
- [x] Seed: first run creates one admin user and prints an admin invite code
Done when: `curl localhost:3000/health` returns ok.

## P1 Auth + admin CRUD
- [ ] /auth/join, JWT middleware, revoke check
- [ ] /admin/teams, /admin/channels, /admin/invites (returns QR PNG base64 + payload JSON)
- [ ] /me/channels
Done when: curl flow create team -> channel -> invite -> join works.

## P2 Messaging + WS + presence
- [ ] /ws with ping/presence, /messages (idempotent), /channels/:id/messages?after_seq, /ack
- [ ] Broadcast of `message` events to channel members
Done when: two `wscat` clients see each other's messages.

## P3 Floor control + LiveKit
- [ ] floor.ts per CONTRACT, /floor/request, /floor/release, /livekit/token
- [ ] Priority pre-emption + 30 s timeout + disconnect release
Done when: curl script shows grant, deny, pre-empt, timeout.

## P4 Admin dashboard
- [ ] `admin/index.html` served at /admin: login with admin invite code, create team/channel/invite (show QR), live presence table, active channels with talker, broadcast box with emergency toggle, ack tracker (acked vs pending)
- [ ] /admin/presence, /admin/broadcast, /admin/acks/:id
Done when: opening /admin shows live users and a broadcast reaches a wscat client.

## P5 Flutter app core
- [ ] Project in `/app`, Android permissions (mic, camera, internet, cleartext, foreground service)
- [ ] Join screen: scan QR (or paste code), call /auth/join, store JWT + host
- [ ] Channel list, chat screen (text), WS client with auto-reconnect
- [ ] Local sqflite outbox: write first, send, retry, show Queued/Sent/Delivered
Done when: two phones chat; airplane-mode toggle delivers queued text on reconnect.

## P6 PTT in app
- [ ] Hold-to-talk button: POST /floor/request -> on granted unmute LiveKit mic; release -> mute + /floor/release
- [ ] Show "X is talking" from `floor` events; denied = vibrate + toast
- [ ] Android foreground service so PTT works with screen off
- [ ] Emergency broadcast: full-screen alert + Acknowledge button -> /ack
Done when: phone A talks, phone B hears it with <1 s delay; simultaneous press is denied.

## P7 Media + call
- [ ] Photo send (image_picker, resize to 1280 px, /media upload, then message type=image)
- [ ] 1:1 voice call using /call/invite + LiveKit room
Done when: photo appears on the other phone; call connects.

## P8 Nearby fallback (stretch)
- [ ] Detect server unreachable (3 failed pings) -> banner "Server lost: nearby mode", send `offline_mode` when possible
- [ ] Nearby Connections advertise+discover (strategy P2P_CLUSTER), exchange text + SOS per CONTRACT
- [ ] On server return: POST queued items with offline=1
Done when: hotspot off -> two phones still exchange text; hotspot on -> messages appear in admin tagged offline.

## P9 Demo polish
- [ ] `scripts/run-demo.md`: 10-line run steps (start docker, set NODE_IP, start server, open /admin)
- [ ] Fix crashes found while rehearsing. No new features.
