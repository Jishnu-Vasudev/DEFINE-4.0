#!/usr/bin/env python3
"""Relay swarm simulator: N headless clients against the Go hub (stdlib only, Python 3.9+).

Each client joins a channel with its code, keeps a WebSocket open with heartbeats, and makes
random push-to-talk bursts through floor control (request -> hold -> release), like a phone.
Voice itself travels over LiveKit/WebRTC, not this hub, so bursts exercise floor control and
event fan-out, not media. Sim clients show up live in the admin dashboard (Nodes panel).

  python scripts/swarm_sim.py --server http://127.0.0.1:3000 --code ABC123 --clients 60 --duration 120
  options: --heartbeat 10  --talk-rate 0.03  --state-file swarm_state.json  --admin-token <jwt> (revoke sims at end)
"""
import argparse, asyncio, base64, json, os, random, statistics, time, urllib.error, urllib.request
from urllib.parse import urlparse


def http(server, method, path, body=None, token=None, timeout=8):
    req = urllib.request.Request(server + path, method=method, data=json.dumps(body).encode() if body is not None else None,
                                 headers={"Content-Type": "application/json", **({"Authorization": "Bearer " + token} if token else {})})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return json.loads(r.read() or b"null")


class WS:
    """Minimal RFC 6455 client: text frames out (masked), frames in, answers pings."""

    def __init__(self, reader, writer):
        self.r, self.w = reader, writer

    @classmethod
    async def connect(cls, url):
        u = urlparse(url)
        reader, writer = await asyncio.wait_for(asyncio.open_connection(u.hostname, u.port or 80), 5)
        key = base64.b64encode(os.urandom(16)).decode()
        writer.write((f"GET {u.path}?{u.query} HTTP/1.1\r\nHost: {u.hostname}:{u.port}\r\nUpgrade: websocket\r\n"
                      f"Connection: Upgrade\r\nSec-WebSocket-Key: {key}\r\nSec-WebSocket-Version: 13\r\n\r\n").encode())
        status = await asyncio.wait_for(reader.readuntil(b"\r\n\r\n"), 5)
        if b" 101 " not in status.split(b"\r\n", 1)[0]:
            raise ConnectionError(status.split(b"\r\n", 1)[0].decode(errors="replace"))
        return cls(reader, writer)

    async def _frame(self, opcode, data):
        mask = os.urandom(4)
        n = len(data)
        head = bytes([0x80 | opcode]) + (bytes([0x80 | n]) if n < 126 else bytes([0x80 | 126]) + n.to_bytes(2, "big") if n < 65536
                                        else bytes([0x80 | 127]) + n.to_bytes(8, "big"))
        self.w.write(head + mask + bytes(b ^ mask[i % 4] for i, b in enumerate(data)))
        await self.w.drain()

    async def send(self, obj):
        await self._frame(0x1, json.dumps(obj).encode())

    async def recv(self):
        while True:
            b1, b2 = await self.r.readexactly(2)
            n = b2 & 0x7F
            if n == 126:
                n = int.from_bytes(await self.r.readexactly(2), "big")
            elif n == 127:
                n = int.from_bytes(await self.r.readexactly(8), "big")
            data = await self.r.readexactly(n)
            op = b1 & 0x0F
            if op == 0x9:
                await self._frame(0xA, data)
            elif op == 0x8:
                raise ConnectionError("closed by server")
            elif op in (0x1, 0x2):
                return json.loads(data)

    def close(self):
        self.w.close()


class Client:
    def __init__(self, sim, i):
        self.sim, self.name = sim, f"sim-{sim.run}-{i:03d}"
        self.state, self.uid, self.token, self.channel = "joining", None, None, None
        self.events = self.grants = self.denies = self.reconnects = 0
        self.last_rtt_ms = None
        self.ws = None

    async def run(self):
        a = self.sim.args
        try:
            r = await asyncio.to_thread(http, a.server, "POST", "/auth/join", {"code": a.code, "name": self.name})
            self.uid, self.token, self.channel = r["user"]["id"], r["jwt"], (r["channels"] or [{}])[0].get("id")
        except Exception as e:
            self.state = f"failed: {e}"
            return
        while not self.sim.stop.is_set():
            try:
                ws_url = a.server.replace("http", "ws", 1) + "/ws?token=" + self.token
                self.ws = await WS.connect(ws_url)
                self.state = "online"
                await asyncio.gather(self._listen(), self._heartbeat(), self._talk())
            except Exception:
                if self.sim.stop.is_set():
                    self.state = "stopped"
                    break
                self.state = "reconnecting"
                self.reconnects += 1
                if self.ws:
                    self.ws.close()
                await asyncio.sleep(1 + random.random())

    async def _listen(self):
        while not self.sim.stop.is_set():
            ev = await self.ws.recv()
            self.events += 1
            if ev.get("t") == "force_mute" and self.state == "talking":
                self.state = "online"

    async def _heartbeat(self):
        await asyncio.sleep(random.random() * self.sim.args.heartbeat)  # spread clients out
        while not self.sim.stop.is_set():
            await self.ws.send({"t": "ping"})
            await asyncio.sleep(self.sim.args.heartbeat)

    async def _talk(self):
        a = self.sim.args
        while not self.sim.stop.is_set() and self.channel:
            await asyncio.sleep(1)
            if random.random() > a.talk_rate:
                continue
            t0 = time.perf_counter()
            r = await asyncio.to_thread(http, a.server, "POST", "/floor/request", {"channel_id": self.channel}, self.token)
            self.last_rtt_ms = round((time.perf_counter() - t0) * 1000, 1)
            self.sim.floor_ms.append(self.last_rtt_ms)
            if not r.get("granted"):
                self.denies += 1
                continue
            self.grants += 1
            self.state = "talking"
            await asyncio.sleep(random.uniform(1, 4))
            await asyncio.to_thread(http, a.server, "POST", "/floor/release", {"channel_id": self.channel}, self.token)
            if self.state == "talking":
                self.state = "online"

    def snapshot(self):
        return {"name": self.name, "user_id": self.uid, "state": self.state, "events": self.events,
                "grants": self.grants, "denies": self.denies, "reconnects": self.reconnects, "last_floor_rtt_ms": self.last_rtt_ms}


class Sim:
    def __init__(self, args):
        self.args, self.run = args, time.strftime("%H%M%S")
        self.stop = asyncio.Event()
        self.floor_ms = []
        self.clients = [Client(self, i) for i in range(args.clients)]

    def totals(self):
        states = {}
        for c in self.clients:
            key = c.state.split(":")[0]
            states[key] = states.get(key, 0) + 1
        ms = sorted(self.floor_ms)
        pct = (lambda p: ms[min(len(ms) - 1, int(p * len(ms)))]) if ms else (lambda p: None)
        return {"states": states, "events": sum(c.events for c in self.clients), "grants": sum(c.grants for c in self.clients),
                "denies": sum(c.denies for c in self.clients), "floor_p50_ms": pct(.5), "floor_p95_ms": pct(.95),
                "floor_mean_ms": round(statistics.mean(ms), 1) if ms else None}

    async def report(self):
        start = time.time()
        while not self.stop.is_set():
            await asyncio.sleep(2)
            t = self.totals()
            print(f"[{time.time() - start:5.0f}s] {t['states']}  events={t['events']}  floor grant/deny={t['grants']}/{t['denies']}"
                  f"  floor p50/p95={t['floor_p50_ms']}/{t['floor_p95_ms']} ms", flush=True)
            if self.args.state_file:
                tmp = self.args.state_file + ".tmp"
                with open(tmp, "w") as f:
                    json.dump({"updated": time.time(), "totals": t, "clients": [c.snapshot() for c in self.clients]}, f)
                os.replace(tmp, self.args.state_file)

    async def main(self):
        tasks = []
        for c in self.clients:  # ramp up gently instead of a thundering herd
            tasks.append(asyncio.create_task(c.run()))
            await asyncio.sleep(self.args.ramp)
        rep = asyncio.create_task(self.report())
        await asyncio.sleep(self.args.duration)
        self.stop.set()
        for c in self.clients:
            if c.ws:
                c.ws.close()
        await asyncio.gather(*tasks, rep, return_exceptions=True)
        print("final:", json.dumps(self.totals()))
        if self.args.admin_token:
            for c in self.clients:
                if c.uid:
                    try:
                        await asyncio.to_thread(http, self.args.server, "POST", f"/admin/users/{c.uid}/revoke", {}, self.args.admin_token)
                    except urllib.error.URLError:
                        pass
            print(f"revoked {sum(1 for c in self.clients if c.uid)} sim users")


if __name__ == "__main__":
    p = argparse.ArgumentParser(description="Relay swarm simulator")
    p.add_argument("--server", default="http://127.0.0.1:3000")
    p.add_argument("--code", required=True, help="channel invite code (permanent channel code)")
    p.add_argument("--clients", type=int, default=50)
    p.add_argument("--duration", type=int, default=60, help="seconds to run after ramp-up")
    p.add_argument("--heartbeat", type=float, default=10, help="seconds between WS heartbeats")
    p.add_argument("--talk-rate", type=float, default=0.03, help="chance per second that a client presses talk")
    p.add_argument("--ramp", type=float, default=0.05, help="seconds between client starts")
    p.add_argument("--state-file", help="write live JSON state here every 2 s")
    p.add_argument("--admin-token", help="admin JWT: revoke the sim users when done")
    asyncio.run(Sim(p.parse_args()).main())
