package main

import (
	"encoding/json"
	"strconv"
	"time"

	"github.com/gin-gonic/gin"
)

// Organisation audit (moderation). Phones seal every encrypted message a second time to the
// control room's audit public key ("audit envelope"). Only the audit service on the control-room
// laptop holds the private key; this server stores envelopes and the resulting safety flags only.
func migrateAudit() {
	db.Exec("ALTER TABLE messages ADD COLUMN audit TEXT")
	db.Exec(`CREATE TABLE IF NOT EXISTS audit_flags(message_id TEXT PRIMARY KEY, channel_id TEXT, kind TEXT, flags TEXT,
		severity INT, scanned_at INT)`)
	db.Exec("CREATE TABLE IF NOT EXISTS settings(k TEXT PRIMARY KEY, v TEXT)")
}

func setting(k string) string {
	var v string
	db.QueryRow("SELECT v FROM settings WHERE k=?", k).Scan(&v)
	return v
}

// GET /audit-key: phones fetch the audit public key ("" = auditing off).
func getAuditKey(c *gin.Context) { c.JSON(200, gin.H{"public_key": setting("audit_public_key")}) }

// PUT /admin/audit-key {public_key}: the audit service registers its key (33-byte 0x05-prefixed X25519, base64).
func putAuditKey(c *gin.Context) {
	var in struct {
		PublicKey string `json:"public_key"`
	}
	if c.BindJSON(&in) != nil {
		c.JSON(400, gin.H{"error": "public_key required"})
		return
	}
	db.Exec("INSERT OR REPLACE INTO settings(k,v) VALUES('audit_public_key',?)", in.PublicKey)
	sendToAll(gin.H{"t": "audit_key", "public_key": in.PublicKey})
	c.JSON(200, gin.H{"ok": true})
}

// GET /admin/audit/queue?after_seq=N&limit=200: envelopes for the audit service, oldest first.
func auditQueue(c *gin.Context) {
	after, _ := strconv.ParseInt(c.DefaultQuery("after_seq", "0"), 10, 64)
	limit, _ := strconv.Atoi(c.DefaultQuery("limit", "200"))
	if limit < 1 || limit > 500 {
		limit = 200
	}
	out := []gin.H{}
	rows, err := db.Query(`SELECT m.seq, m.id, m.channel_id, m.sender_id, COALESCE(u.name,''), m.type, COALESCE(m.body,''),
		COALESCE(m.media,''), m.created_at, m.offline, COALESCE(m.audit,''), COALESCE(r.name,'')
		FROM messages m LEFT JOIN users u ON u.id=m.sender_id LEFT JOIN users r ON r.id=m.relayed_by
		WHERE m.seq>? ORDER BY m.seq LIMIT ?`, after, limit)
	if err == nil {
		for rows.Next() {
			var seq, at int64
			var off int
			var id, ch, sid, sname, typ, body, media, audit, via string
			rows.Scan(&seq, &id, &ch, &sid, &sname, &typ, &body, &media, &at, &off, &audit, &via)
			if typ == "enc" {
				body = "" // ciphertext is useless to the audit service; the envelope carries the content
			}
			out = append(out, gin.H{"seq": seq, "id": id, "channel_id": ch, "sender_id": sid, "sender_name": sname, "type": typ,
				"body": body, "media": media, "created_at": at, "offline": off, "audit": audit, "relayed_via": via})
		}
		rows.Close()
	}
	c.JSON(200, out)
}

// POST /admin/audit/flags {list:[{message_id, kind, flags:[...], severity}]}: scan results (no content).
func postAuditFlags(c *gin.Context) {
	var in struct {
		List []struct {
			MessageID string   `json:"message_id"`
			Kind      string   `json:"kind"`
			Flags     []string `json:"flags"`
			Severity  int      `json:"severity"`
		} `json:"list"`
	}
	if c.BindJSON(&in) != nil {
		c.JSON(400, gin.H{"error": "list required"})
		return
	}
	now := time.Now().Unix()
	for _, f := range in.List {
		var ch string
		db.QueryRow("SELECT channel_id FROM messages WHERE id=?", f.MessageID).Scan(&ch)
		b, _ := json.Marshal(f.Flags)
		db.Exec("INSERT OR REPLACE INTO audit_flags(message_id,channel_id,kind,flags,severity,scanned_at) VALUES(?,?,?,?,?,?)",
			f.MessageID, ch, f.Kind, string(b), f.Severity, now)
	}
	c.JSON(200, gin.H{"ok": true, "n": len(in.List)})
}

// GET /admin/channels/:id/stats: activity summary from metadata only (works without the audit key).
func channelStats(c *gin.Context) {
	id := c.Param("id")
	out := gin.H{"channel_id": id}
	var total, first, last int64
	db.QueryRow("SELECT COUNT(*), COALESCE(MIN(created_at),0), COALESCE(MAX(created_at),0) FROM messages WHERE channel_id=?", id).
		Scan(&total, &first, &last)
	out["total"], out["first"], out["last"] = total, first, last
	byHour := make([]int, 24)
	if rows, err := db.Query("SELECT created_at FROM messages WHERE channel_id=?", id); err == nil {
		for rows.Next() {
			var at int64
			rows.Scan(&at)
			byHour[time.UnixMilli(at).Hour()]++
		}
		rows.Close()
	}
	out["by_hour"] = byHour
	people := []gin.H{}
	if rows, err := db.Query(`SELECT m.sender_id, COALESCE(u.name,''), COUNT(*), MAX(m.created_at) FROM messages m
		LEFT JOIN users u ON u.id=m.sender_id WHERE m.channel_id=? GROUP BY m.sender_id ORDER BY COUNT(*) DESC`, id); err == nil {
		for rows.Next() {
			var uid, name string
			var n, lastAt int64
			rows.Scan(&uid, &name, &n, &lastAt)
			people = append(people, gin.H{"id": uid, "name": name, "count": n, "last": lastAt})
		}
		rows.Close()
	}
	out["participants"] = people
	byType := gin.H{}
	if rows, err := db.Query("SELECT type, COUNT(*) FROM messages WHERE channel_id=? GROUP BY type", id); err == nil {
		for rows.Next() {
			var t string
			var n int
			rows.Scan(&t, &n)
			byType[t] = n
		}
		rows.Close()
	}
	out["by_wire_type"] = byType
	var flagged, relayed int
	db.QueryRow("SELECT COUNT(*) FROM audit_flags WHERE channel_id=? AND severity>0", id).Scan(&flagged)
	db.QueryRow("SELECT COUNT(*) FROM messages WHERE channel_id=? AND relayed_by IS NOT NULL", id).Scan(&relayed)
	out["flagged"], out["relayed"] = flagged, relayed
	c.JSON(200, out)
}
