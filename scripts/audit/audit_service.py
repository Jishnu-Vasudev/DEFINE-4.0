#!/usr/bin/env python3
"""Bunny Hop audit service: the control room's moderation pipeline. Runs on the control-room laptop only.

  1. Publishes the organisation audit public key to the relay server (private key stays in data/).
  2. Pulls audit envelopes from the server, opens them, downloads + decrypts media.
  3. Scans text (toxicity), images (NudeNet) and files (signature / extension / macro guard).
  4. Reports content-free flags back to the server, and serves history/search/gallery to the admin
     dashboard on http://127.0.0.1:3100 (localhost only; every call needs a valid admin token).

  First run:  scripts/audit/.venv/Scripts/python scripts/audit/audit_service.py --admin-code ABC123
  Later:      scripts/audit/.venv/Scripts/python scripts/audit/audit_service.py
"""
import argparse, json, os, sqlite3, sys, threading, time, traceback, urllib.error, urllib.parse, urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from audit_crypto import decrypt_media, load_or_create_key, open_envelope  # noqa: E402
from scanners import file_guard, image_scan, text_scan  # noqa: E402

SCHEMA = """
CREATE TABLE IF NOT EXISTS meta(k TEXT PRIMARY KEY, v TEXT);
CREATE TABLE IF NOT EXISTS items(id TEXT PRIMARY KEY, seq INTEGER, channel_id TEXT, sender_id TEXT, sender_name TEXT,
  created_at INTEGER, wire_type TEXT, type TEXT, text TEXT, name TEXT, media_file TEXT, mime TEXT, family TEXT, size INTEGER,
  flags TEXT, severity INTEGER, score REAL, detail TEXT, relayed_via TEXT, status TEXT);
CREATE INDEX IF NOT EXISTS items_ch ON items(channel_id, seq);
"""
EXT = {"image": "jpg", "video": "mp4", "audio": "m4a"}


class Service:
    def __init__(self, a):
        self.a, self.data = a, os.path.abspath(a.data)
        os.makedirs(os.path.join(self.data, "media"), exist_ok=True)
        self.db_path = os.path.join(self.data, "audit.db")
        with self.db() as c:
            c.executescript(SCHEMA)
        self.token = self._token()
        self.priv, self.pub = load_or_create_key(os.path.join(self.data, "audit_private.key"))
        self.api("PUT", "/admin/audit-key", {"public_key": self.pub})
        print(f"Bunny Hop audit: key published; dashboard API on http://127.0.0.1:{a.port}", flush=True)
        self._auth_cache = {}

    def db(self):
        c = sqlite3.connect(self.db_path, timeout=10)
        c.row_factory = sqlite3.Row
        return c

    def api(self, method, path, body=None, token=None, raw=False):
        req = urllib.request.Request(self.a.server + path, method=method, data=json.dumps(body).encode() if body is not None else None,
                                     headers={"Content-Type": "application/json", "Authorization": "Bearer " + (self.token if token is None else token)})
        with urllib.request.urlopen(req, timeout=30) as r:
            data = r.read()
            return data if raw else json.loads(data or b"null")

    def _token(self):
        f = os.path.join(self.data, "service_token")
        if self.a.admin_token:
            return self.a.admin_token
        if os.path.exists(f):
            return open(f).read().strip()
        if not self.a.admin_code:
            sys.exit("first run needs --admin-code (a one-time admin code) or --admin-token")
        r = json.loads(urllib.request.urlopen(urllib.request.Request(self.a.server + "/auth/join", method="POST",
                       data=json.dumps({"code": self.a.admin_code, "name": "Audit Service"}).encode(),
                       headers={"Content-Type": "application/json"}), timeout=10).read())
        if r["user"]["role"] != "admin":
            sys.exit("that code is not an admin code")
        with open(f, "w") as fh:
            fh.write(r["jwt"])
        return r["jwt"]

    # ---- pipeline ----
    def run_pipeline(self):
        while True:
            try:
                with self.db() as c:
                    row = c.execute("SELECT v FROM meta WHERE k='cursor'").fetchone()
                after = int(row["v"]) if row else 0
                batch = self.api("GET", f"/admin/audit/queue?after_seq={after}&limit=100")
                flags = []
                for m in batch:
                    item = self.process(m)
                    with self.db() as c:
                        c.execute("INSERT OR REPLACE INTO items VALUES(:id,:seq,:channel_id,:sender_id,:sender_name,:created_at,:wire_type,"
                                  ":type,:text,:name,:media_file,:mime,:family,:size,:flags,:severity,:score,:detail,:relayed_via,:status)", item)
                        c.execute("INSERT OR REPLACE INTO meta VALUES('cursor',?)", (str(m["seq"]),))
                    flags.append({"message_id": item["id"], "kind": item["type"], "flags": json.loads(item["flags"]), "severity": item["severity"]})
                if flags:
                    self.api("POST", "/admin/audit/flags", {"list": flags})
                    print(f"Bunny Hop audit: scanned {len(flags)} message(s), {sum(1 for f in flags if f['severity'])} flagged", flush=True)
                if len(batch) < 100:
                    time.sleep(self.a.poll)
            except Exception as e:
                print("Bunny Hop audit: pipeline error:", e, flush=True)
                time.sleep(5)

    def process(self, m):
        it = {"id": m["id"], "seq": m["seq"], "channel_id": m["channel_id"], "sender_id": m["sender_id"], "sender_name": m["sender_name"],
              "created_at": m["created_at"], "wire_type": m["type"], "type": m["type"], "text": "", "name": "", "media_file": "",
              "mime": "", "family": "", "size": 0, "flags": "[]", "severity": 0, "score": 0.0, "detail": "",
              "relayed_via": m.get("relayed_via") or "", "status": "ok"}
        payload = None
        if m["type"] == "enc":
            if not m.get("audit"):
                it.update(status="sealed", detail="sent without an audit envelope (before auditing was on)")
                return it
            try:
                payload = open_envelope(self.priv, m["audit"])
            except Exception:
                it.update(status="error", detail="envelope could not be opened (different audit key?)")
                return it
        else:
            payload = {"type": m["type"], "body": m["body"]}
        typ = payload.get("type", "text")
        it["type"] = typ
        flags, sev, score, detail = [], 0, 0.0, []
        if typ in ("image", "video", "audio", "file"):
            it["name"] = payload.get("body") or ""
            media, key = payload.get("media") or m.get("media"), payload.get("media_key")
            if media and key:
                try:
                    data = decrypt_media(key, self.api("GET", "/media/" + urllib.parse.quote(media), raw=True))
                    ext = os.path.splitext(it["name"])[1].lstrip(".") or EXT.get(typ, "bin")
                    path = os.path.join(self.data, "media", f"{m['id']}.{ext.lower()}")
                    with open(path, "wb") as f:
                        f.write(data)
                    fam, mime, ff, fs, why = file_guard(it["name"] or os.path.basename(path), data)
                    it.update(media_file=os.path.basename(path), mime=mime, family=fam, size=len(data))
                    flags += ff; sev = max(sev, fs); detail += [why] if why else []
                    if typ == "image" and fam in ("png", "jpeg", "gif", "webp"):
                        nf, ns, nscore, labels = image_scan(path)
                        flags += nf; sev = max(sev, ns); score = max(score, nscore)
                        if labels:
                            detail.append("nudity: " + ", ".join(labels))
                except Exception as e:
                    it["status"], detail = "error", [f"media unavailable: {e}"]
        else:
            it["text"] = payload.get("body") or ""
            tf, ts, tscore = text_scan(it["text"])
            flags += tf; sev = max(sev, ts); score = max(score, tscore)
        it.update(flags=json.dumps(sorted(set(flags))), severity=sev, score=round(score, 3), detail="; ".join(detail))
        return it

    # ---- dashboard API ----
    def authorized(self, token):
        if not token:
            return False  # never fall back to the service's own admin token
        now = time.time()
        if self._auth_cache.get(token, 0) > now:
            return True
        try:
            self.api("GET", "/admin/teams", token=token)
        except urllib.error.HTTPError:
            return False
        self._auth_cache[token] = now + 60
        return True


def make_handler(svc):
    class H(BaseHTTPRequestHandler):
        def log_message(self, *a):
            pass

        def _cors(self):
            o = self.headers.get("Origin", "")
            if o.endswith(":3000"):
                self.send_header("Access-Control-Allow-Origin", o)
                self.send_header("Access-Control-Allow-Headers", "Authorization")
                self.send_header("Vary", "Origin")

        def _send(self, code, body, ctype="application/json", extra=None):
            data = body if isinstance(body, bytes) else json.dumps(body).encode()
            self.send_response(code)
            self._cors()
            self.send_header("Content-Type", ctype)
            self.send_header("Content-Length", str(len(data)))
            for k, v in (extra or {}).items():
                self.send_header(k, v)
            self.end_headers()
            self.wfile.write(data)

        def do_OPTIONS(self):
            self.send_response(204)
            self._cors()
            self.end_headers()

        def do_GET(self):
            u = urllib.parse.urlparse(self.path)
            q = {k: v[0] for k, v in urllib.parse.parse_qs(u.query).items()}
            if u.path == "/health":
                return self._send(200, {"ok": True})
            if not svc.authorized(self.headers.get("Authorization", "").removeprefix("Bearer ")):
                return self._send(401, {"error": "admin token required"})
            try:
                return routes(svc, self, u.path, q)
            except Exception as e:
                traceback.print_exc()
                return self._send(500, {"error": str(e)})
    return H


def item_json(r):
    d = dict(r)
    d["flags"] = json.loads(d["flags"] or "[]")
    d["has_media"] = bool(d.pop("media_file"))
    return d


def routes(svc, h, path, q):
    ch = q.get("channel", "")
    with svc.db() as c:
        if path == "/history":
            sql, args = "SELECT * FROM items WHERE channel_id=?", [ch]
            if q.get("q"):
                sql += " AND (text LIKE ? OR name LIKE ? OR sender_name LIKE ?)"; args += [f"%{q['q']}%"] * 3
            if q.get("type"):
                sql += " AND type=?"; args.append(q["type"])
            if q.get("flagged") == "1":
                sql += " AND severity>0"
            if q.get("before_seq"):
                sql += " AND seq<?"; args.append(int(q["before_seq"]))
            limit = min(int(q.get("limit", 40)), 200)
            rows = c.execute(sql + " ORDER BY seq DESC LIMIT ?", args + [limit]).fetchall()
            return h._send(200, {"items": [item_json(r) for r in rows], "next_before": rows[-1]["seq"] if len(rows) == limit else None})
        if path == "/summary":
            types = {r["type"]: r["n"] for r in c.execute("SELECT type, COUNT(*) n FROM items WHERE channel_id=? GROUP BY type", (ch,))}
            flags = {}
            for r in c.execute("SELECT flags FROM items WHERE channel_id=? AND severity>0", (ch,)):
                for f in json.loads(r["flags"]):
                    flags[f] = flags.get(f, 0) + 1
            size = c.execute("SELECT COALESCE(SUM(size),0) s, COUNT(media_file) n FROM items WHERE channel_id=? AND media_file!=''", (ch,)).fetchone()
            sealed = c.execute("SELECT COUNT(*) n FROM items WHERE channel_id=? AND status='sealed'", (ch,)).fetchone()["n"]
            return h._send(200, {"by_type": types, "flags": flags, "media_count": size["n"], "media_bytes": size["s"], "not_auditable": sealed})
        if path == "/media":
            sql, args = "SELECT * FROM items WHERE channel_id=? AND media_file!=''", [ch]
            if q.get("kind"):
                sql += " AND type=?"; args.append(q["kind"])
            return h._send(200, {"items": [item_json(r) for r in c.execute(sql + " ORDER BY seq DESC LIMIT 500", args)]})
        if path.startswith("/media/") and path.endswith("/content"):
            r = c.execute("SELECT media_file, mime, name, type FROM items WHERE id=?", (urllib.parse.unquote(path[7:-8]),)).fetchone()
            if not r or not r["media_file"]:
                return h._send(404, {"error": "no media"})
            with open(os.path.join(svc.data, "media", r["media_file"]), "rb") as f:
                data = f.read()
            inline = r["type"] in ("image", "video", "audio") and q.get("download") != "1"
            disp = "inline" if inline else f'attachment; filename="{(r["name"] or r["media_file"]).replace(chr(34), "")}"'
            return h._send(200, data, r["mime"] or "application/octet-stream", {"Content-Disposition": disp, "X-Content-Type-Options": "nosniff"})
    return h._send(404, {"error": "not found"})


if __name__ == "__main__":
    p = argparse.ArgumentParser(description="Bunny Hop audit service (control room only)")
    p.add_argument("--server", default="http://127.0.0.1:3000")
    p.add_argument("--port", type=int, default=3100)
    p.add_argument("--data", default=os.path.join(os.path.dirname(os.path.abspath(__file__)), "data"))
    p.add_argument("--admin-code", help="one-time admin code, first run only")
    p.add_argument("--admin-token", help="use this admin JWT instead of the saved one")
    p.add_argument("--poll", type=float, default=2.0)
    svc = Service(p.parse_args())
    threading.Thread(target=svc.run_pipeline, daemon=True).start()
    ThreadingHTTPServer(("127.0.0.1", svc.a.port), make_handler(svc)).serve_forever()
