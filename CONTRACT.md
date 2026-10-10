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

- Message objects in REST/WS responses also carry `sender_name` (joined from users) for display.
- GET /admin/teams -> [{id,name,channels[]}] (admin dashboard dropdowns). Broadcast messages store scope (`all` or team_id) in channel_id.
- GET /channels/:id/members -> [{id,name,role,online}] (member list for calling). Call rooms are named `call_<id>`; only the two parties get a LiveKit token. `call_invite.from` = {id,name}.
- GET /admin/messages -> last 40 messages [{...message, channel}] newest first (dashboard activity feed, shows offline tag).
- channels.invite_code TEXT UNIQUE: permanent per-channel code, set once at creation (backfilled on startup), never regenerated. /auth/join accepts it (unlimited uses, role member, joins only that channel); QR payload format is the same as invites.
- GET /admin/channels/:id -> {id,name,kind,team,invite_code,payload,qr_png_base64,total,online,members:[{id,name,role,online,last_seen}]}. POST /admin/channels also returns invite_code.
- POST /channels/join {code} (auth) -> channel: adds the signed-in user to the channel with that permanent invite_code (404 if unknown). Used by the app to join more channels without a new account.
- DELETE /admin/channels/:id -> {ok}: purges channel, members, messages, acks and their upload files; sends WS `{t:"channel_deleted", channel_id, name}` to every former member. POST /channels/:id/leave -> {ok}: removes only the caller's membership.
- Message types also include video | audio | file (media = uploaded filename, body = original file name). POST /media accepts photos, video, audio and common documents up to MAX_UPLOAD_MB (default 25) -> {media, size}; over the limit -> 413 {error:"file too large", max_bytes}. GET /config -> {max_upload_bytes} (app pre-checks size before upload).
- E2EE (Signal Protocol, app side in app/lib/e2ee/): every user message except `sos` and admin `broadcast` is sent as type `enc` with body `g:<b64>` (channel sender-key message), `p:<b64>` (pre-key message) or `w:<b64>` (Double Ratchet message); media is uploaded as an AES-256-GCM `.enc` blob whose key travels inside the encrypted body. The server stores and relays ciphertext only.
- Keys: PUT /keys {registration_id, identity_key, signed_prekey:{id,pub,sig}, prekeys:[{id,pub}]} -> {prekeys}; GET /keys/count -> {prekeys}; GET /keys/user/:uid -> bundle (consumes one prekey, 404 if none); POST /keys/send {to, channel_id, type, body} relays a sealed sender key (both must share channel_id) and pushes WS `{t:"key", id, from, channel_id, type, body}`; GET /keys/inbox -> pending key messages; POST /keys/ack {ids}. Tables: keys, prekeys, key_msgs.
- POST /dm {user_id} -> channel (kind dm, name "A & B", created once per pair, only those two members); the other user gets WS `{t:"channel_added", channel}`.
- Floor priorities: 1 routine, 2 ops (admin broadcast), 3 emergency (2/3 admins only). On pre-emption the old talker gets WS `{t:"force_mute", channel_id, by, priority}` and the server mutes their LiveKit audio track (RoomService twirp API); priority 3 also sends `{t:"emergency_override", channel_id, user_id, name}` to the channel.
- Store-and-forward: POST /bundles {list:[{bundle_id, origin, channel_id, type:"enc"|"sos", body, created_at, hops, sig}]} -> {bundle_id: stored|duplicate|bad_signature|not_member|no_key|invalid}. sig = origin's Signal identity-key signature over "relay-bundle\n{bundle_id}\n{channel_id}\n{origin}\n{type}\n{body}\n{created_at}". Stored as a message from origin with offline=1, messages.relayed_by = carrier; GET /admin/messages adds relayed_via (carrier name).
- Nearby mesh frames (besides the message payload above): `{k:"sum", bloom:<b64 1 KB Bloom filter of carried bundle_ids>}` on connect, answered with `{k:"b", b:<bundle>}` for each bundle the peer lacks.
- Org audit (moderation): GET /audit-key -> {public_key} ("" = off; 33-byte 0x05-prefixed X25519, base64); PUT /admin/audit-key {public_key} (audit service registers; WS `{t:"audit_key", public_key}` to all). POST /messages and bundles accept `audit` = base64(eph_pub32|nonce12|AES-GCM ct) sealed to that key (HKDF-SHA256 info/AAD "relay-audit-v1"); bundle signatures cover it. Server stores it opaque in messages.audit and never returns it to members.
- GET /admin/audit/queue?after_seq&limit -> envelopes for the audit service; POST /admin/audit/flags {list:[{message_id, kind, flags[], severity}]} (content-free; table audit_flags); GET /admin/messages adds flags, severity; GET /admin/channels/:id/stats -> {total, first, last, by_hour[24], participants[{id,name,count,last}], by_wire_type, flagged, relayed}.
- Audit service (scripts/audit/audit_service.py, control-room laptop, 127.0.0.1:3100, admin bearer token): GET /history?channel&q&type&flagged&before_seq&limit, /summary?channel, /media?channel&kind, /media/:message_id/content[?download=1]. Flags: toxic, nudity, hazard, macro, mismatch, unknown_binary; severity 1 warn, 2 high.
- Bridge mode (app setting, default on): connected phones keep the mesh running as gateways. Extra mesh frames: `{k:"st", off:bool}` (sent on connect and when my server reachability changes), `{k:"fwd", fid, m:<server message or broadcast+emergency>, hops}` (gateway -> offline peers only), `{k:"ack", fid, ids:[bundle_id], hops}` (gateway -> everyone after POST /bundles stored/duplicate; the origin marks those messages sent). fwd/ack are de-duplicated by fid and re-flooded up to 6 hops.
