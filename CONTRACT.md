# CONTRACT (single source of truth, do not deviate)

## SQLite tables
- users(id TEXT PK, name, role, revoked INT DEFAULT 0, last_seen INT)
- teams(id TEXT PK, name)
- channels(id TEXT PK, team_id, name, kind)  -- kind: team | zone | dm
- members(user_id, channel_id)
- invites(code TEXT PK, team_id, role, expires_at INT, used INT DEFAULT 0)
- messages(id TEXT PK, channel_id, sender_id, type, body, media TEXT, created_at INT, offline INT DEFAULT 0, seq INTEGER)
  - type: text | image | sos | broadcast | ptt_clip
  - id is a client-generated UUID; inserting an existing id is a no-op (idempotent). `seq` = per-DB autoincrement used for sync.
- acks(message_id, user_id, at INT)

## Auth
`Authorization: Bearer <jwt>` on every route except `/auth/join`. JWT payload `{uid, role}`. Revoked users get 401.

## REST
| Method | Path | Body / Query | Returns |
|---|---|---|---|
| POST | /auth/join | {code, name} | {jwt, user, channels[]} |
| GET | /me/channels | | channels[] |
| GET | /channels/:id/messages | ?after_seq=0 | messages[] |
| POST | /messages | {id, channel_id, type, body, media?, created_at, offline?} | {seq} |
| POST | /media | multipart `file` | {media} (filename) |
| GET | /media/:file | | file |
| POST | /ack | {message_id} | {ok:true} |
| POST | /floor/request | {channel_id, priority?} (1 normal, 2 broadcast, 3 emergency) | {granted:boolean, holder?} |
| POST | /floor/release | {channel_id} | {ok:true} |
| GET | /livekit/token | ?room=<channel_id or call_id> | {token, url} |
| POST | /call/invite | {to_user_id} | {room} (also pushes WS `call_invite`) |
| POST | /admin/teams | {name} | team |
| POST | /admin/channels | {team_id, name, kind} | channel |
| POST | /admin/invites | {team_id, role} | {code, qr_png_base64, payload} |
| GET | /admin/presence | | {users:[{id,name,online,last_seen,offline_mode}], channels:[{id,name,talker?,members_online}]} |
| POST | /admin/broadcast | {text, scope:"all"\|team_id, emergency:boolean} | {message_id} |
| GET | /admin/acks/:message_id | | {acked:[], pending:[]} |
| POST | /admin/users/:id/revoke | | {ok:true} |

## WebSocket `/ws?token=<jwt>`
Server -> client (JSON `{t, ...}`):
- `{t:"message", message}`
- `{t:"floor", channel_id, state:"granted"|"taken"|"released", user_id, name, priority}`
- `{t:"presence", user_id, online}`
- `{t:"broadcast", message, emergency}`
- `{t:"call_invite", room, from}`
Client -> server: `{t:"ping"}` every 10s (updates last_seen; server marks offline after 25s without ping). `{t:"offline_mode", on:boolean}` for admin indicator.

## Floor control (server/src/floor.ts, in-memory)
`Map<channel_id, {user_id, priority, expires_at}>`
- request: free -> grant. Held by lower priority -> pre-empt (emit `released` to old, `granted` to new). Else deny.
- Auto-release after 30 s or when holder's WS disconnects.
- On grant, emit `floor` event to all channel members. Clients unmute the LiveKit mic only after `granted`.

## LiveKit
Each channel_id is a room. Everyone joins with mic muted. Token grants: roomJoin, canPublish, canSubscribe. Identity = user id.

## Nearby fallback payload (JSON over Nearby bytes)
`{id, channel_id, type:"text"|"sos", body, created_at, sender_id, name}`; saved to local outbox with offline=1; synced via POST /messages when server is reachable.
