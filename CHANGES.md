# BunnyHop changes

- Branding: name, logo, launcher icons (adaptive + legacy), native splash (Android 12+ aware) and animated in-app splash. Theme palette sampled from the logo.
- UI: new join screen, app bar brand, server/hop-mode tag, gradient live PTT button, themed dialogs/sheets.
- Fixes (app): mesh duplicate wiped message `seq`; PTT stuck on "Connecting…"; floor held when voice server down; missing Nearby/Bluetooth/location permissions in manifest; duplicate mesh connection requests; unbounded `_seen`; malformed WS frame crash; stacked timers on re-join; broken session restore; garbled `…` in call screen; port validation.
- Fixes (server): invite QR used hard-coded port 3000; invite for unknown team accepted; nil-rows panics in admin endpoints; warns on default `JWT_SECRET`.
- Not verified by build: no Flutter SDK / Go modules in the authoring sandbox. Run `flutter pub get && flutter analyze` and `go build` once.

## Voice / conversation fixes (round 2)
- **No audio, root cause 1 (app):** mic, notification and Nearby permissions were requested from two places at once; `permission_handler` throws on overlap, so the mic stayed denied and voice rooms never joined. All requests now go through `lib/perms.dart` (one queue, one batch).
- **No audio, root cause 2 (network):** Windows Firewall blocks LiveKit UDP 50000-50100 / TCP 7881 (popup dismissed, or hotspot is "Public"). Chat uses TCP 3000 so it still works. New `scripts/open-firewall.ps1`. Server now prints a warning if LiveKit is down, and `/diag` shows `livekit_up`.
- PTT: press while a room was still connecting returned "Can't reach the server"; connects are now shared. Mic failure no longer leaves the floor held. Voice link is checked before taking the floor. Specific error messages (mic off, voice server down). Hold-to-talk uses a raw pointer listener so a drifting finger no longer cuts the transmission. Rooms join one by one.
- Calls: mic permission check, earpiece by default (button state matched real routing), loudspeaker restored for PTT after hang-up.
- Server: `/livekit/token` returns 503 with a clear message when LiveKit is not running; `lanIP()` skips VirtualBox/Hyper-V/Docker/WSL/VPN adapters; `livekit.yaml` ignored `excludes` because `includes` was set; `docker-compose.yml` now uses the same config (UDP mux port 7882 was not published).
- Still not built here: run `flutter pub get && flutter analyze` and `go build`.
- Hop mode (Nearby) carries text and SOS only; live audio over hops is not implemented.

