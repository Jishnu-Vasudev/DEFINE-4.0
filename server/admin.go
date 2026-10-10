package main

import (
	"strings"
	"time"

	"github.com/gin-gonic/gin"
)

func adminRoutes(ad *gin.RouterGroup) {
	ad.GET("/teams", listTeams)
	ad.GET("/presence", presence)
	ad.POST("/broadcast", broadcast)
	ad.GET("/acks/:id", acks)
	ad.POST("/users/:id/revoke", revoke)
	ad.GET("/messages", recentMessages)
}

// recentMessages feeds the dashboard activity list (newest first, with channel name).
func recentMessages(c *gin.Context) {
	type row struct {
		message
		Channel    string `json:"channel"`
		RelayedVia string `json:"relayed_via,omitempty"`
		Flags      string `json:"flags,omitempty"`
		Severity   int    `json:"severity,omitempty"`
	}
	out := []row{}
	rows, err := db.Query(`SELECT m.seq, m.id, m.channel_id, m.sender_id, COALESCE(u.name,''), m.type, COALESCE(m.body,''),
		COALESCE(m.media,''), m.created_at, m.offline, COALESCE(ch.name, CASE m.channel_id WHEN 'all' THEN 'Everyone' ELSE 'Team' END),
		COALESCE(r.name,''), COALESCE(f.flags,''), COALESCE(f.severity,0)
		FROM messages m LEFT JOIN users u ON u.id=m.sender_id LEFT JOIN channels ch ON ch.id=m.channel_id
		LEFT JOIN users r ON r.id=m.relayed_by LEFT JOIN audit_flags f ON f.message_id=m.id
		ORDER BY m.seq DESC LIMIT 40`)
	if err != nil {
		c.JSON(500, gin.H{"error": err.Error()})
		return
	}
	defer rows.Close()
	for rows.Next() {
		var r row
		m := &r.message
		if rows.Scan(&m.Seq, &m.ID, &m.ChannelID, &m.SenderID, &m.SenderName, &m.Type, &m.Body, &m.Media, &m.CreatedAt, &m.Offline, &r.Channel, &r.RelayedVia, &r.Flags, &r.Severity) == nil {
			out = append(out, r)
		}
	}
	c.JSON(200, out)
}

func listTeams(c *gin.Context) {
	type team struct {
		ID       string    `json:"id"`
		Name     string    `json:"name"`
		Channels []channel `json:"channels"`
	}
	out := []team{}
	rows, _ := db.Query("SELECT id, name FROM teams ORDER BY name")
	for rows.Next() {
		var t team
		rows.Scan(&t.ID, &t.Name)
		out = append(out, t)
	}
	rows.Close()
	for i := range out {
		out[i].Channels = []channel{}
		cr, _ := db.Query("SELECT id, team_id, name, kind FROM channels WHERE team_id=? AND kind!='dm' ORDER BY name", out[i].ID)
		for cr.Next() {
			var ch channel
			cr.Scan(&ch.ID, &ch.TeamID, &ch.Name, &ch.Kind)
			out[i].Channels = append(out[i].Channels, ch)
		}
		cr.Close()
	}
	c.JSON(200, out)
}

func presence(c *gin.Context) {
	users := []gin.H{}
	rows, _ := db.Query("SELECT id, name, role, last_seen FROM users WHERE revoked=0 ORDER BY name")
	for rows.Next() {
		var id, name, role string
		var seen int64
		rows.Scan(&id, &name, &role, &seen)
		hubMu.Lock()
		off := offlineMode[id]
		hubMu.Unlock()
		users = append(users, gin.H{"id": id, "name": name, "role": role, "online": isOnline(id), "last_seen": seen, "offline_mode": off})
	}
	rows.Close()

	chans := []gin.H{}
	rows, _ = db.Query(`SELECT c.id, c.name, COALESCE(t.name,''), GROUP_CONCAT(m.user_id) FROM channels c
		LEFT JOIN teams t ON t.id=c.team_id LEFT JOIN members m ON m.channel_id=c.id
		WHERE c.kind!='dm' GROUP BY c.id ORDER BY t.name, c.name`)
	for rows.Next() {
		var id, name, team string
		var mem *string
		rows.Scan(&id, &name, &team, &mem)
		n := 0
		if mem != nil {
			for _, u := range strings.Split(*mem, ",") {
				if isOnline(u) {
					n++
				}
			}
		}
		ch := gin.H{"id": id, "name": name, "team": team, "members_online": n}
		if h := floorHolder(id); h != nil {
			ch["talker"] = gin.H{"user_id": h.UserID, "name": h.Name, "priority": h.Priority}
		}
		chans = append(chans, ch)
	}
	rows.Close()
	c.JSON(200, gin.H{"users": users, "channels": chans})
}

// broadcastTargets: everyone for scope "all", else users in any channel of that team.
func broadcastTargets(scope string) []string {
	q, args := "SELECT id FROM users WHERE revoked=0", []any{}
	if scope != "all" {
		q = `SELECT DISTINCT u.id FROM users u JOIN members m ON m.user_id=u.id
			JOIN channels c ON c.id=m.channel_id WHERE u.revoked=0 AND c.team_id=?`
		args = append(args, scope)
	}
	out := []string{}
	rows, err := db.Query(q, args...)
	if err != nil {
		return out
	}
	defer rows.Close()
	for rows.Next() {
		var id string
		rows.Scan(&id)
		out = append(out, id)
	}
	return out
}

func broadcast(c *gin.Context) {
	var in struct {
		Text      string `json:"text"`
		Scope     string `json:"scope"`
		Emergency bool   `json:"emergency"`
	}
	if c.BindJSON(&in) != nil || strings.TrimSpace(in.Text) == "" {
		c.JSON(400, gin.H{"error": "text required"})
		return
	}
	if in.Scope == "" {
		in.Scope = "all"
	}
	id := newID()
	// broadcast rows use the scope ("all" or team_id) as channel_id
	db.Exec(`INSERT INTO messages(id,channel_id,sender_id,type,body,created_at) VALUES(?,?,?,?,?,?)`,
		id, in.Scope, c.GetString("uid"), "broadcast", in.Text, time.Now().UnixMilli())
	m, _ := scanMsg(db.QueryRow("SELECT "+msgCols+" WHERE m.id=?", id))
	ev := gin.H{"t": "broadcast", "message": m, "emergency": in.Emergency}
	for _, u := range broadcastTargets(in.Scope) {
		sendToUser(u, ev)
	}
	c.JSON(200, gin.H{"message_id": id})
}

func acks(c *gin.Context) {
	id := c.Param("id")
	var scope, sender string
	if db.QueryRow("SELECT channel_id, sender_id FROM messages WHERE id=? AND type='broadcast'", id).Scan(&scope, &sender) != nil {
		c.JSON(404, gin.H{"error": "no such broadcast"})
		return
	}
	acked := map[string]bool{}
	rows, _ := db.Query("SELECT user_id FROM acks WHERE message_id=?", id)
	for rows.Next() {
		var u string
		rows.Scan(&u)
		acked[u] = true
	}
	rows.Close()
	a, p := []gin.H{}, []gin.H{}
	for _, u := range broadcastTargets(scope) {
		if u == sender {
			continue
		}
		var name string
		db.QueryRow("SELECT name FROM users WHERE id=?", u).Scan(&name)
		row := gin.H{"id": u, "name": name, "online": isOnline(u)}
		if acked[u] {
			a = append(a, row)
		} else {
			p = append(p, row)
		}
	}
	c.JSON(200, gin.H{"acked": a, "pending": p})
}

func revoke(c *gin.Context) {
	id := c.Param("id")
	if id == c.GetString("uid") {
		c.JSON(400, gin.H{"error": "cannot revoke yourself"})
		return
	}
	db.Exec("UPDATE users SET revoked=1 WHERE id=?", id)
	hubMu.Lock()
	for cl := range hub[id] {
		cl.conn.Close() // read pump exits and cleans up
	}
	hubMu.Unlock()
	c.JSON(200, gin.H{"ok": true})
}
