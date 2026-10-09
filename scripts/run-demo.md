# Run the demo

1. Connect the laptop and all phones to the same Wi-Fi/hotspot. Find the laptop IP: `ipconfig` (IPv4, e.g. 10.80.0.64).
2. Start voice (LiveKit): `D:\tools\livekit\livekit-server.exe --config server\livekit.yaml --node-ip <LAPTOP_IP>` (or `NODE_IP=<ip> docker compose up` if Docker is installed).
3. Start the server: `cd server; .\ptt-server.exe` (set `$env:HOST_IP="<LAPTOP_IP>"` first if the QR shows the wrong IP). Note the printed ADMIN INVITE CODE.
4. Open the firewall once: admin PowerShell, `.\scripts\open-firewall.ps1` (TCP 3000, 7880, 7881 + UDP 50000-50100, Wi-Fi set to Private). Without it chat works but voice is silent.
   Check from a phone browser: `http://<LAPTOP_IP>:3000/diag` must show `"livekit_up": true`.
5. Open `http://localhost:3000/admin`, then sign in with your name and the admin code.
6. In Setup, add a team and a channel, set "how many people" and click "Get QR" (one QR for the whole group).
7. Install `app\build\app\outputs\flutter-apk\app-debug.apk` on each phone, open Relay, enter your name, scan the QR, and allow mic, notifications and nearby devices.
8. Demo: chat and photo, then push-to-talk (hold or tap mode; a second phone pressing at the same time gets denied), then a call from the People icon, then an emergency broadcast from admin (watch the ack bar fill).
9. Fallback: turn the hotspot off, wait about 12 s for the red "nearby mode" bar, send text or SOS phone to phone (with 3 phones in a line A–B–C, B passes A's message on to C), then turn the hotspot on and the messages show in admin tagged "nearby".
10. Reset everything: stop the server and delete `server\ptt.db` (a new admin code is printed on the next start).
