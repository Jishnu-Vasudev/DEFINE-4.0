package main

import (
	"database/sql"
	"strconv"
	"time"

	"github.com/gin-gonic/gin"
)

type message struct {
	Seq        int64  `json:"seq"`
	ID         string `json:"id"`
	ChannelID  string `json:"channel_id"`
	SenderID   string `json:"sender_id"`
	SenderName string `json:"sender_name"`
	Type       string `json:"type"`
	Body       string `json:"body"`
	Media      string `json:"media"`
	CreatedAt  int64  `json:"created_at"`
	Offline    int    `json:"offline"`
}

const msgCols = `m.seq, m.id, m.channel_id, m.sender_id, COALESCE(u.name,''), m.type, COALESCE(m.body,''),
	COALESCE(m.media,''), m.created_at, m.offline FROM messages m LEFT JOIN users u ON u.id=m.sender_id`

func scanMsg(r interface{ Scan(...any) error }) (message, error) {
	var m message
	err := r.Scan(&m.Seq, &m.ID, &m.ChannelID, &m.SenderID, &m.SenderName, &m.Type, &m.Body, &m.Media, &m.CreatedAt, &m.Offline)
	return m, err
}

func isMember(uid, channelID string) bool {
	var n int
	db.QueryRow("SELECT COUNT(*) FROM members WHERE user_id=? AND channel_id=?", uid, channelID).Scan(&n)
	return n > 0
}

var userMsgTypes = map[string]bool{"text": true, "image": true, "sos": true, "ptt_clip": true}

func postMessage(c *gin.Context) {
	var in message
	if c.BindJSON(&in) != nil || in.ID == "" || in.ChannelID == "" || !userMsgTypes[in.Type] {
		c.JSON(400, gin.H{"error": "id, channel_id and valid type required"})
		return
	}
	uid := c.GetString("uid")
	if !isMember(uid, in.ChannelID) {
		c.JSON(403, gin.H{"error": "not a member"})
		return
	}
	if in.CreatedAt == 0 {
		in.CreatedAt = time.Now().UnixMilli()
	}
	res, err := db.Exec(`INSERT OR IGNORE INTO messages(id,channel_id,sender_id,type,body,media,created_at,offline)
		VALUES(?,?,?,?,?,?,?,?)`, in.ID, in.ChannelID, uid, in.Type, in.Body, in.Media, in.CreatedAt, in.Offline)
	if err != nil {
		c.JSON(500, gin.H{"error": err.Error()})
		return
	}
	m, err := scanMsg(db.QueryRow("SELECT "+msgCols+" WHERE m.id=?", in.ID))
	if err != nil {
		c.JSON(500, gin.H{"error": err.Error()})
		return
	}
	// only fan out on first insert; retries of the same id are silent
	if n, _ := res.RowsAffected(); n == 1 {
		sendToChannel(m.ChannelID, gin.H{"t": "message", "message": m})
	}
	c.JSON(200, gin.H{"seq": m.Seq})
}

func listMessages(c *gin.Context) {
	ch := c.Param("id")
	if !isMember(c.GetString("uid"), ch) {
		c.JSON(403, gin.H{"error": "not a member"})
		return
	}
	after, _ := strconv.ParseInt(c.DefaultQuery("after_seq", "0"), 10, 64)
	rows, err := db.Query("SELECT "+msgCols+" WHERE m.channel_id=? AND m.seq>? ORDER BY m.seq LIMIT 500", ch, after)
	out := []message{}
	if err == nil {
		defer rows.Close()
		for rows.Next() {
			if m, err := scanMsg(rows); err == nil {
				out = append(out, m)
			}
		}
	}
	c.JSON(200, out)
}

func postAck(c *gin.Context) {
	var in struct {
		MessageID string `json:"message_id"`
	}
	if c.BindJSON(&in) != nil || in.MessageID == "" {
		c.JSON(400, gin.H{"error": "message_id required"})
		return
	}
	if err := db.QueryRow("SELECT 1 FROM messages WHERE id=?", in.MessageID).Scan(new(int)); err == sql.ErrNoRows {
		c.JSON(404, gin.H{"error": "no such message"})
		return
	}
	db.Exec("INSERT OR IGNORE INTO acks(message_id,user_id,at) VALUES(?,?,?)", in.MessageID, c.GetString("uid"), time.Now().Unix())
	c.JSON(200, gin.H{"ok": true})
}
