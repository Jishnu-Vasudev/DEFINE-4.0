package main

import (
	"database/sql"
	"encoding/base64"
	"encoding/json"
	"strings"

	"github.com/gin-gonic/gin"
	"github.com/skip2/go-qrcode"
)

// Every non-dm channel has a permanent invite code, set once and never regenerated.
func migrateChannelCodes() {
	db.Exec("ALTER TABLE channels ADD COLUMN invite_code TEXT")
	db.Exec("CREATE UNIQUE INDEX IF NOT EXISTS channels_invite_code ON channels(invite_code)")
	var ids []string
	rows, err := db.Query("SELECT id FROM channels WHERE invite_code IS NULL AND kind!='dm'")
	if err != nil {
		return
	}
	for rows.Next() {
		var id string
		rows.Scan(&id)
		ids = append(ids, id)
	}
	rows.Close()
	for _, id := range ids {
		db.Exec("UPDATE channels SET invite_code=? WHERE id=?", uniqueCode(), id)
	}
}

// uniqueCode avoids clashes with both channel codes and one-off invites.
func uniqueCode() string {
	for {
		code, n := newCode(), 0
		db.QueryRow("SELECT (SELECT COUNT(*) FROM channels WHERE invite_code=?) + (SELECT COUNT(*) FROM invites WHERE code=?)", code, code).Scan(&n)
		if n == 0 {
			return code
		}
	}
}

// channelByCode resolves a permanent channel invite code.
func channelByCode(code string) (chID, teamID string, ok bool) {
	err := db.QueryRow("SELECT id, team_id FROM channels WHERE invite_code=? AND kind!='dm'", code).Scan(&chID, &teamID)
	return chID, teamID, err == nil
}

func invitePayload(code string) (string, string) {
	payload, _ := json.Marshal(gin.H{"host": lanIP(), "port": 3000, "code": code})
	png, _ := qrcode.Encode(string(payload), qrcode.Medium, 512)
	return string(payload), base64.StdEncoding.EncodeToString(png)
}

func channelDetails(c *gin.Context) {
	var id, name, kind, team string
	var code sql.NullString
	err := db.QueryRow(`SELECT c.id, c.name, c.kind, COALESCE(t.name,''), c.invite_code FROM channels c
		LEFT JOIN teams t ON t.id=c.team_id WHERE c.id=? AND c.kind!='dm'`, c.Param("id")).Scan(&id, &name, &kind, &team, &code)
	if err != nil {
		c.JSON(404, gin.H{"error": "channel not found"})
		return
	}
	if !code.Valid {
		code.String = uniqueCode()
		db.Exec("UPDATE channels SET invite_code=? WHERE id=?", code.String, id)
	}
	type mem struct {
		ID       string `json:"id"`
		Name     string `json:"name"`
		Role     string `json:"role"`
		Online   bool   `json:"online"`
		LastSeen int64  `json:"last_seen"`
	}
	members := []mem{}
	rows, err := db.Query(`SELECT u.id, u.name, u.role, COALESCE(u.last_seen,0) FROM users u JOIN members m ON m.user_id=u.id
		WHERE m.channel_id=? AND u.revoked=0 ORDER BY u.name`, id)
	if err == nil {
		for rows.Next() {
			var m mem
			rows.Scan(&m.ID, &m.Name, &m.Role, &m.LastSeen)
			members = append(members, m)
		}
		rows.Close()
	}
	online := 0
	for i := range members {
		if members[i].Online = isOnline(members[i].ID); members[i].Online {
			online++
		}
	}
	payload, png := invitePayload(code.String)
	c.JSON(200, gin.H{"id": id, "name": name, "kind": kind, "team": team, "invite_code": code.String,
		"payload": payload, "qr_png_base64": png, "total": len(members), "online": online, "members": members})
}

// joinChannel adds the signed-in user to a channel by its permanent invite code.
func joinChannel(c *gin.Context) {
	var in struct{ Code string }
	if c.BindJSON(&in) != nil || strings.TrimSpace(in.Code) == "" {
		c.JSON(400, gin.H{"error": "code required"})
		return
	}
	chID, _, ok := channelByCode(strings.ToUpper(strings.TrimSpace(in.Code)))
	if !ok {
		c.JSON(404, gin.H{"error": "invalid invite code"})
		return
	}
	db.Exec("INSERT OR IGNORE INTO members(user_id,channel_id) VALUES(?,?)", c.GetString("uid"), chID)
	for _, ch := range userChannels(c.GetString("uid")) {
		if ch.ID == chID {
			c.JSON(200, ch)
			return
		}
	}
	c.JSON(500, gin.H{"error": "join failed"})
}
