# 10-Line Demo Run Guide

1. Find your laptop's LAN IP (e.g. `192.168.1.100` via `ipconfig`).
2. Set environment: `$env:NODE_IP="192.168.1.100"` (or `export NODE_IP=192.168.1.100`).
3. Start LiveKit server: `docker compose up -d`.
4. Install backend dependencies: `cd server; npm install`.
5. Start Fastify backend: `npm run dev` (listens on `http://0.0.0.0:3000`).
6. Note the Admin Invite Code printed in the server startup seed log.
7. Open browser at `http://localhost:3000/admin` and log in with the admin invite code.
8. In Admin Console: Create a Team, a Channel (`team`), and click Generate QR Invite.
9. On Android phones: Open PTT App, scan or paste invite QR payload, and tap Connect.
10. Operate Demo: Hold-to-Talk PTT voice, text chat, photo sharing, 1:1 voice call, and emergency broadcast.
