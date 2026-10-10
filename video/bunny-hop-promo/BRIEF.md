---
workflow: product-launch-video
flow: automation
storyboard: yes
message: "Your team, one press away: push-to-talk that keeps working when the network doesn't"
destination: youtube
aspect: 1920x1080
language: en
length: 90s
angle: feature-walkthrough
fps: 60
vo_mode: restructured
narration: voice-over + on-screen narrator text
voice: am_michael
tts_provider: kokoro
music: none
---

## Intent

Sell mode (a promo, not a neutral tour). Cinematic motion graphics with kinetic typography and one
seamless, continuous camera. A phone mockup runs the Bunny Hop Flutter app, then the camera moves on to
the Go-backed admin dashboard, "Bunny Hop Control".

Locked story order (user-confirmed):
logo cold-open -> phone smooth scale-in on the Join screen -> simulated finger tap on the primary button
("Scan channel QR") -> channels -> push-to-talk (live waveform) -> chat + photo/file + end-to-end
encryption lock -> offline mesh / bridge hop -> SOS -> slide-left physics transition to Bunny Hop Control
(nodes matrix filling in, channel audit with typed history, emergency broadcast + ack bar) -> logo close
"Your team, one press away".

User's styling rules (verbatim intent): "set the frame rate to 60fps, use soft easing curves for page
transitions, and sync the timing of simulated data updates with standard text typing effects".

## Assets

- assets/logo.png: the Bunny Hop logo (ember bunny in a glowing ring), from app/assets/logo.png.
- No website capture: the app UI and dashboard are rebuilt as HTML from the real Flutter/admin code
  (palette, copy, layout), so typing, live tiles and taps can animate. Source of truth:
  app/lib/theme.dart, app/lib/screens/*, admin/index.html.

## Customizations

- Simulated finger tap (touch ripple) on the Join screen's primary button.
- Slide-left physics (soft spring) from phone to dashboard.
- Data updates (node tiles, counts, history rows, ack bar) land in step with typed text.

## Notes

- Brand palette: canvas #1B110B, panel #26180F, accent #FF9A3D, ember #E85D18, cream text #FFF6EA,
  muted #C4AA94, danger #FF5D4F. Product name: Bunny Hop; admin app: Bunny Hop Control.
- Audio: spoken voice-over with the OFFLINE Kokoro voice am_michael (HeyGen sign-in was impossible in
  this terminal); no music bed (user's choice; can be added later). User asked for
  "some text explaining each and everything like someone telling": a narrator script (written by us,
  VO_MODE restructured), read aloud AND shown on screen as narrator text/captions, one line per beat;
  scene timing follows the narration.
- Claims must stay true to the product: offline LAN, Signal-protocol E2EE, nearby mesh + bridge,
  SOS, push-to-talk with priority override, admin broadcast with acknowledgements.
