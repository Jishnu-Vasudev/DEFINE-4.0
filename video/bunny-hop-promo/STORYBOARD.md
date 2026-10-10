---
format: 1920x1080
fps: 60
duration: 90s
message: "Your team, one press away: push-to-talk that keeps working when the network doesn't"
arc: Feature-Benefit Cascade (demo loop on one phone, then the control room) → CTA
audience: event, venue and hospital operations teams who run on walkie-talkies today; hackathon judges
mode: collaborative
music: none
---

## Video direction

- **Palette (frame.md, Broadside ember remix):** ground ink-black #1B110B with a warm radial ember glow top-right; cream #FFF6EA text; fire-orange #E85D18 is the single accent (one accent moment per frame); amber #FF9A3D for live UI state; danger red only for SOS / nearby-mode / emergency. Frame 10 is the one orange-register frame.
- **Type (frame.md roles):** display/h1 Barlow 900/800 lowercase, tight negative tracking; kickers and data in IBM Plex Mono uppercase 0.14em; UI text inside the phone and dashboard in Barlow 400–700.
- **Motion grammar:** long-tail eases (power3.out default, soft power2.inOut for in-phone page changes and the phone slide-left, a soft back.out only on spring pops). Every piece reveals on its spoken cue (VO-paced); nothing fires all at t=0. Data updates (counters, tiles, rows, ack bar) advance in lockstep with a typed caret on the same element.
- **Camera:** one continuous camera language: slow push-ins under reveals; the phone is the held hero of frames 03–10, the dashboard of 11–14.
- **Held frames (rhythm):** 02 (lockup holds), 10 (SOS statement holds), 15 (end card holds to the last frame). Others reveal to the VO and settle in their last window.
- **Caption band:** narration captions own the bottom ~17%; all content stays in the top ~83%. Visible text is short motion copy, never the narration sentence.
- **Never:** front-load then freeze (slideshow); everything floating independently (screensaver); gradients on text; a second accent hue; stock icons standing in for product UI; exit tweens on non-final frames.

## Frame 1 — When the network dies

- scene: Black stage; kinetic lines punch in one by one, the last word "silent" drains to grey, then "Not yours." snaps in ember
- voiceover: "Big event. Hundreds of staff. The Wi-Fi drops, and the team goes silent. Not yours."
- duration: 6.58s
- transition_in: cut
- status: animated
- src: compositions/frames/01-hook.html
- type: hook
- persuasion: Pain validation, then negative contrast
- beat: tension → relief
- blueprint: kinetic-type-beats (Reproduce)
- asset_candidates:

narrativeRole: name the real-world failure (team comms die with the network) and promise the opposite in one breath.
keyMessage: this team keeps talking when everyone else goes quiet.

Scene 1 (0.0–1.2s): black ground; "big event." punches in upper-left (h2), cream — asymmetric 70/30, left-aligned column.
Scene 2 (1.2–2.4s): "hundreds of staff." punches in beneath on its cue; first line dims to hint grey.
Scene 3 (2.4–4.4s): "the wi-fi drops, and the team goes silent." builds word-by-word on the VO; "silent." drains from cream to grey and the whole column dims.
Scene 4 (4.4–5.8s): "not yours." slams in bottom-right above the caption band (display, fire-orange) with a short scale settle; glow blooms behind it and holds.

## Frame 2 — Meet Bunny Hop

- scene: The ember ring draws on, the bunny springs into it mid-hop, wordmark "Bunny Hop" assembles, tagline types beneath
- voiceover: "Meet Bunny Hop. Your whole team, one press away."
- duration: 5.18s
- transition_in: zoom-through
- status: animated
- src: compositions/frames/02-intro.html
- type: product_intro
- persuasion: Promise statement (value claim lands in beat 2)
- beat: curiosity → confidence
- blueprint: logo-assemble-lockup (Adapt)
- focal: assets/logo.png
- roles: logo = cutout (centered hero)
- asset_candidates: assets/logo.png — Bunny Hop bunny in a glowing ember ring

narrativeRole: name the product and land the promise (the brief's message) by beat 2.
keyMessage: Bunny Hop = your team, one press away.

Adapt: keep the mark-comes-to-exist signature (ring draws on, mark springs in); wordmark + tagline instead of a URL.
Scene 1 (0.0–1.1s): centered; the ember ring around the logo draws on and the logo springs in from 70% scale with a glow bloom — centered, ~30% of frame.
Scene 2 (1.1–2.2s): "bunny hop" wordmark rises letter-by-letter beneath the mark (display).
Scene 3 (2.2–3.2s): tagline kicker "your whole team, one press away" types in under the wordmark; everything holds still.

## Frame 3 — Join in seconds

- scene: Phone mockup smooth scale-in on the Join screen (radar rings around the logo); "Asha" types into Your name, a finger tap ripples on "Scan channel QR", the channel opens
- voiceover: "Scan the channel code your admin shows. Type your name. Tap. You're in."
- duration: 5.43s
- transition_in: crossfade
- status: animated
- src: compositions/frames/03-join.html
- type: feature_showcase
- persuasion: Friction reduction (three steps, no accounts)
- beat: ease
- blueprint: device-surface-showcase (Adapt)
- focal: assets/logo.png
- roles: logo = supporting (inside the phone's Join screen radar rings)
- asset_candidates: assets/logo.png — logo inside the Join screen's radar rings (rest of the UI rebuilt in HTML from the app)

narrativeRole: show onboarding is instant: the first proof of "one press away".
keyMessage: joining takes one scan and one tap.

Adapt: phone held as hero; cursorless flow done by a finger-tap ripple instead of a cursor.
Scene 1 (0.0–1.4s): the phone smooth-scales in from 70% at right third on the Join screen (logo with two pulsing radar rings, "Join a channel"); left column kicker "01 · join" and "scan." appear — asymmetric 40/60, 3 depth layers (glow, headline, phone).
Scene 2 (1.4–2.8s): on "Type your name" the name field types "Asha" with a caret; "type." joins the left stack.
Scene 3 (2.8–3.8s): on "Tap" a finger-tap ripple fires on "Scan channel QR", the button depresses; "tap." lands in fire-orange.
Scene 4 (3.8–4.6s): the phone screen soft-slides to a "Gate B · joined" confirmation chip; hold.

## Frame 4 — A channel for every crew

- scene: The phone settles on the Channels screen; glass cards cascade in (Gate B, Medical, Stage Crew) with a greeting "Hi, Asha"
- voiceover: "Every crew, every zone, gets its own channel."
- duration: 3.98s
- transition_in: push-slide LEFT
- status: animated
- src: compositions/frames/04-channels.html
- type: feature_showcase
- persuasion: Feature-to-benefit translation (organised by team and place)
- beat: clarity
- blueprint: grid-card-assemble (Adapt)
- asset_candidates:

narrativeRole: show structure: teams and zones each have a channel.
keyMessage: everyone hears exactly the people they work with.

Adapt: card cascade happens inside the held phone, not as a free grid.
Scene 1 (0.0–1.0s): phone at right third shows "Channels · 3 channels · Hi, Asha"; left: kicker "02 · channels", "every crew." — asymmetric 40/60.
Scene 2 (1.0–2.4s): Gate B, Medical, Stage Crew cards cascade up one by one inside the phone; "every zone." joins the left stack on its cue.
Scene 3 (2.4–3.2s): the Gate B card glows amber (selected); hold.

## Frame 5 — Hold to talk

- scene: Inside Gate B; a thumb presses the "Hold to talk" pill, the mic orb breathes, live waveform; on the next beat a second phone shows "Asha is talking"; a lock-screen glance with the volume key
- voiceover: "Hold to talk. One voice at a time, crystal clear. Even from the lock screen, with the volume key."
- duration: 7.56s
- transition_in: crossfade
- status: animated
- src: compositions/frames/05-ptt.html
- type: feature_showcase
- persuasion: Show-don't-tell proof (the walkie-talkie, in the phone)
- beat: control + power
- blueprint: device-surface-showcase (Adapt)
- asset_candidates:

narrativeRole: the core feature: real push-to-talk replaces the radio.
keyMessage: it works exactly like a walkie-talkie, only clearer.

Adapt: two phones (sender + listener) instead of one screen cycle; the screen change is the talk state.
Scene 1 (0.0–1.4s): left: kicker "03 · push to talk", "hold to talk." (h1, "talk." fire-orange); center phone in Gate B with the talk pill idle "Hold to talk".
Scene 2 (1.4–3.0s): a thumb-press ripple on the pill; it turns ember "Talking… release to stop", the mic orb breathes and a waveform runs above it.
Scene 3 (3.0–4.8s): on "one voice at a time" a second, smaller phone slides in at right showing "Asha is talking" with a matching waveform.
Scene 4 (4.8–6.8s): on "even from the lock screen" a small lock-screen chip "Volume key = talk" pops beside the second phone; hold.

## Frame 6 — More than voice

- scene: Chat thread fills: a typed message, a photo slides in, a voice note waveform, a PDF card, each landing with its line
- voiceover: "Messages, photos, voice notes and files, all in the same thread."
- duration: 5.13s
- transition_in: push-slide LEFT
- status: animated
- src: compositions/frames/06-chat.html
- type: benefit_highlight
- persuasion: Value stacking (rule of four)
- beat: ease
- blueprint: grid-card-assemble (Adapt)
- asset_candidates:

narrativeRole: widen the value beyond voice: one place for every kind of update.
keyMessage: no second app needed.

Adapt: a vertical list that accumulates inside the phone thread; each item tied to a left-column word.
Scene 1 (0.0–1.0s): phone at right third shows the Gate B thread; left kicker "04 · more than voice"; "messages." lights and a text bubble lands.
Scene 2 (1.0–2.0s): "photos." lights; a photo bubble slides in.
Scene 3 (2.0–3.0s): "voice notes." lights; a voice-note bubble with waveform lands.
Scene 4 (3.0–4.3s): "files." lights fire-orange; a PDF card lands "floor-plan.pdf"; hold.

## Frame 7 — Locked end to end

- scene: Camera pushes into the chat header's lock badge; a message turns into scrambled ciphertext as it travels to a server icon and back to readable text on the other phone; kinetic "Not even the server can read it."
- voiceover: "And it's all end-to-end encrypted. Not even the server can read it."
- duration: 5.02s
- transition_in: zoom-through
- status: animated
- src: compositions/frames/07-e2ee.html
- type: benefit_highlight
- persuasion: Risk reversal (privacy by design)
- beat: trust
- blueprint: kinetic-type-beats (Adapt)
- asset_candidates:

narrativeRole: remove the security objection with one clear, true claim (Signal protocol, server sees only ciphertext).
keyMessage: private by design.

Adapt: the word swap is a message turning into ciphertext and back.
Scene 1 (0.0–1.4s): centered row: "need water at gate b" (mono) on a sender chip left, a server box center, a receiver chip right — triptych, centered.
Scene 2 (1.4–2.6s): the message travels right; passing the server it scrambles into ciphertext "9f#k2Q!x…" (fire-orange) — the server only ever shows the scramble.
Scene 3 (2.6–4.2s): it resolves to readable text at the receiver; "not even the server can read it." (h1, "can read it." fire-orange) rises beneath and holds.

## Frame 8 — When the Wi-Fi dies

- scene: The router icon cuts out; a red "Server lost: nearby mode" bar drops onto three phones; dotted links spring between them and a message hops phone to phone across the frame
- voiceover: "Then the Wi-Fi dies. Bunny Hop doesn't. Phones find each other, and messages hop from phone to phone."
- duration: 7.75s
- transition_in: blur-crossfade
- status: animated
- src: compositions/frames/08-mesh.html
- type: feature_showcase
- persuasion: Negative contrast (pays off the hook)
- beat: tension → relief
- blueprint: camera-journey (Adapt)
- asset_candidates:

narrativeRole: pay off the hook: the mesh keeps the team talking with no network.
keyMessage: no Wi-Fi, still connected.

Adapt: action roundtrip across three phones; the camera tracks the hopping message.
Scene 1 (0.0–1.6s): wide: a Wi-Fi router icon top-center cuts out (bars drop, red X); headline "wi-fi dies." upper-left.
Scene 2 (1.6–3.2s): "bunny hop doesn't." completes the headline in fire-orange; three phones across the frame each get a red "Server lost: nearby mode" bar — triptych, 3 depth layers.
Scene 3 (3.2–5.2s): dotted amber links draw between neighbours; an "On my way" bubble hops phone 1 → phone 2 → phone 3 as the camera pans with it.
Scene 4 (5.2–7.0s): the bubble lands on phone 3 with a soft pulse; hold.

## Frame 9 — The bridge home

- scene: One phone walks back into Wi-Fi range; it glows as a bridge and carries the queued messages up to the server; the sender's tick flips to "sent"
- voiceover: "And the first phone back in range carries everyone's messages home."
- duration: 5.17s
- transition_in: crossfade
- status: animated
- src: compositions/frames/09-bridge.html
- type: benefit_highlight
- persuasion: Future pacing (nothing gets lost)
- beat: relief + peace of mind
- blueprint: camera-journey (Adapt)
- asset_candidates:

narrativeRole: complete the offline story: messages always get delivered.
keyMessage: nothing gets lost.

Adapt: cause (phone back in range) → consequence (messages delivered) connected by one camera move.
Scene 1 (0.0–1.4s): a phone at left-center steps into a Wi-Fi arc and glows (bridge); headline "the first phone back in range" upper-left.
Scene 2 (1.4–3.0s): queued bubbles stream up an ember line to a "Bunny Hop server" box at right; "carries everyone home." joins the headline in fire-orange.
Scene 3 (3.0–4.4s): the sender's tick flips to "✓ sent"; hold.

## Frame 10 — SOS

- scene: A finger taps the red SOS button; every nearby phone flashes a full-screen alert; kinetic "One tap. Everyone knows."
- voiceover: "In an emergency, one tap alerts everyone nearby."
- duration: 5.26s
- transition_in: cut
- status: animated
- src: compositions/frames/10-sos.html
- type: benefit_highlight
- persuasion: Scarcity/urgency (the moment it matters most)
- beat: urgency → confidence
- blueprint: kinetic-type-beats (Adapt)
- asset_candidates:

narrativeRole: the safety beat: the reason a venue or hospital needs this.
keyMessage: help is one tap away, even offline.

Adapt: the orange register; statement builds onto a spring-pop payoff around the SOS button.
Scene 1 (0.0–1.0s): hard cut to orange; the black SOS button springs in center-top.
Scene 2 (1.0–2.2s): a finger-tap ripple fires; three ring pulses expand outward.
Scene 3 (2.2–3.5s): "one tap." then "everyone knows." stack in beneath (display, ink); hold.

## Frame 11 — Behind it all: Bunny Hop Control

- scene: The phone slides left with soft spring physics and the camera follows into the laptop dashboard "Bunny Hop Control": header with Live dot and "No emergency", channel cards glowing as people talk
- voiceover: "Behind it all, Bunny Hop Control. Your control room, on one screen."
- duration: 5.22s
- transition_in: push-slide LEFT
- status: animated
- src: compositions/frames/11-control.html
- type: product_intro
- persuasion: Authority (the operator's view)
- beat: control
- blueprint: cursor-ui-demo (Adapt)
- focal: assets/logo.png
- roles: logo = supporting (dashboard header)
- asset_candidates: assets/logo.png — logo in the dashboard header (dashboard rebuilt in HTML from admin/index.html)

narrativeRole: open the second surface: the admin/control-room side.
keyMessage: the operator sees and controls everything.

Adapt: no cursor; the hand-off is the phone sliding left with soft spring physics while the camera follows into the dashboard.
Scene 1 (0.0–1.4s): the phone (left) slides off to the left on a soft spring as the dashboard window glides in from the right to center — wide, ~70% of frame.
Scene 2 (1.4–2.8s): header settles: logo, "Bunny Hop Control", "● Live", "No emergency", "26 of 28 online · 1 talking"; three channel cards cascade in.
Scene 3 (2.8–4.4s): the Gate B card glows amber with "Ravi is talking" waveform; an activity row types in beneath ("Meera … Relayed via Joel"); hold.

## Frame 12 — Every device, live

- scene: The Nodes matrix fills tile by tile in sync with a typed counter "26 of 28 online · 1 talking"; one tile pulses ember (talking), two turn yellow (nearby mode), one greys out
- voiceover: "See every device, live. Who's online, who's talking, who's out of range."
- duration: 5.45s
- transition_in: crossfade
- status: animated
- src: compositions/frames/12-nodes.html
- type: feature_showcase
- persuasion: Show-don't-tell proof
- beat: control + clarity
- blueprint: dataviz-countup (Adapt)
- asset_candidates:

narrativeRole: situational awareness: the whole network at a glance.
keyMessage: nothing happens without you seeing it.

Adapt: the hero metric is the node matrix itself; counter types in lockstep with tiles.
Scene 1 (0.0–1.2s): dashboard panel "Nodes" centered, wide; the counter starts typing "26 of 28 online" while the first tiles pop in.
Scene 2 (1.2–2.8s): the 28 tiles pop in row by row in step with the counter; on "who's talking" one tile ignites ember with a glow.
Scene 3 (2.8–4.6s): on "who's out of range" two tiles turn yellow and two grey; legend fades in; a slow push-in on the grid settles and holds.

## Frame 13 — Every channel, on the record

- scene: A channel audit panel slides in; History rows type in one by one (with a "Relayed via Meera" tag), the hourly bar chart grows in step, a flagged photo stays blurred under "Sensitive content"
- voiceover: "Open any channel for its history, activity, and shared media, safety-checked automatically."
- duration: 6.86s
- transition_in: push-slide LEFT
- status: animated
- src: compositions/frames/13-audit.html
- type: feature_showcase
- persuasion: Authority + risk reversal (oversight built in)
- beat: trust
- blueprint: transcript-scroll-artifact-reveal (Adapt)
- asset_candidates:

narrativeRole: oversight and safety: history, stats, moderation.
keyMessage: you can review and keep the channel safe.

Adapt: short history feed instead of a long transcript; the artifact is the blurred, flagged photo.
Scene 1 (0.0–1.4s): audit panel slides in from the right (History tab active); hourly bar chart at left grows first bars.
Scene 2 (1.4–3.8s): history rows type in one at a time (Ravi, Meera with "Relayed via Meera", Asha); bars grow in step with each row.
Scene 3 (3.8–6.0s): on "safety-checked" the last row's photo stays blurred and a red "Sensitive content" badge pops; hold.

## Frame 14 — Reach everyone, now

- scene: "Evacuate Hall C via Gate B" types into the Broadcast box, the Emergency switch flips red, Send; the acknowledgement bar fills 3, 7, 12 of 14 in step with names ticking
- voiceover: "Need everyone, right now? Send one broadcast, and watch every acknowledgement come in."
- duration: 6.24s
- transition_in: crossfade
- status: animated
- src: compositions/frames/14-broadcast.html
- type: feature_showcase
- persuasion: Show-don't-tell proof (closed loop)
- beat: power → peace of mind
- blueprint: prompt-type-submit-generate (Adapt)
- asset_candidates:

narrativeRole: the climax: one action reaches everyone and proves they got it.
keyMessage: one message, everyone confirmed.

Adapt: the prompt is the broadcast message; the generated result is the acknowledgement stream.
Scene 1 (0.0–1.6s): broadcast panel centered; "Evacuate Hall C via Gate B" types into the box with a caret.
Scene 2 (1.6–2.6s): the Emergency switch flips red; the send button presses with a ripple; a red emergency glow blooms behind the panel.
Scene 3 (2.6–5.4s): on "watch every acknowledgement" the ack bar fills 3 → 7 → 12 of 14 while name chips tick ✓ in on the same beats; hold.

## Frame 15 — One press away

- scene: Dashboard and phone pull back and fade; the logo re-forms center, "Bunny Hop" lockup, tagline, and a final line "Runs on your own network. No internet needed."
- voiceover: "Bunny Hop. Your team, one press away. On your own network, no internet needed."
- duration: 7.55s
- transition_in: zoom-through
- status: animated
- src: compositions/frames/15-outro.html
- type: cta
- persuasion: Value restatement + status (own infrastructure)
- beat: confidence + inevitability
- blueprint: logo-assemble-lockup (Reproduce)
- focal: assets/logo.png
- roles: logo = cutout (centered hero)
- asset_candidates: assets/logo.png — final lockup

narrativeRole: close on the brand and the promise, plus the deployment truth (offline, self-hosted).
keyMessage: Bunny Hop: your team, one press away.

Scene 1 (0.0–1.4s): centered; the logo springs in with the ember ring and a glow bloom.
Scene 2 (1.4–3.0s): "bunny hop" wordmark rises; "your team, one press away." settles beneath ("one press away." fire-orange).
Scene 3 (3.0–5.4s): mono line "runs on your own network · no internet needed" fades in last; everything holds to the final frame, then a gentle fade to black.

