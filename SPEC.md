# SPEC (read once)

## Goal
Replace walkie-talkies with a phone app on a closed LAN: push-to-talk (PTT), chat, photos, 1:1 voice call, admin dashboard + emergency broadcast. All data stays on one laptop server. Fallback: phone-to-phone via Android Nearby Connections when server is unreachable.

## Stack (fixed)
- Server: Go 1.22+, `gin-gonic/gin`, `gorilla/websocket`, `mattn/go-sqlite3`, `golang-jwt/jwt/v5`, `livekit/server-sdk-go`, `skip2/go-qrcode`
- Voice: LiveKit server in Docker (`--dev` keys `devkey` / `secret`)
- App: Flutter (Android), `livekit_client`, `provider`, `sqflite`, `nearby_connections`, `mobile_scanner`, `image_picker`, `http`, `web_socket_channel`, `permission_handler`, `flutter_foreground_task`
- Admin: static HTML + vanilla JS served by the server at `/admin`
- Media: saved to `server/uploads/`, served at `/media/:file` (JWT required)

## Layout
```
/server   main.go, db.go, auth.go, routes.go, ws.go, floor.go, livekit.go
/admin    index.html
/app      Flutter project
/docker-compose.yml   (livekit only)
```

## Roles
`admin`, `member`. Admin creates teams, channels, invites. Join only via invite code (QR). No public sign-up.

## Must-have demo features (priority order)
1. Invite join + JWT, teams, channels
2. Text chat with offline outbox (idempotent by client UUID)
3. PTT with server-side floor control (half-duplex, priority, 30s timeout)
4. Admin dashboard: online users, active channels + talker, broadcast with acknowledgement
5. Photo sharing
6. 1:1 voice call
7. Nearby fallback (text + SOS), sync back tagged `offline=1`

## Out of scope (do NOT build)
iOS, mTLS, E2EE, retention, HA, video calls, push notifications, LoRa, accounts/passwords, tests.

## Network notes
- Server binds `0.0.0.0:3000`. LiveKit on `7880` (ws), UDP `50000-50100`, `--node-ip <laptop LAN IP>`.
- App reads server address from the invite QR: `{"host":"192.168.x.x","port":3000,"code":"ABC123"}`.
- Plain HTTP/WS is fine on the LAN for the demo (Android `usesCleartextTraffic=true`).
