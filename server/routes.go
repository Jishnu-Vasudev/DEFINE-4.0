package main

import (
	"encoding/base64"
	"encoding/json"
	"net"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/skip2/go-qrcode"
)

func routes(r *gin.Engine) {
	r.GET("/health", func(c *gin.Context) { c.String(200, "ok") })
	r.POST("/auth/join", join)
	r.GET("/ws", wsHandler)

	a := r.Group("/", authMW)
	a.GET("/me/channels", func(c *gin.Context) { c.JSON(200, userChannels(c.GetString("uid"))) })
	a.POST("/messages", postMessage)
	a.GET("/channels/:id/messages", listMessages)
	a.POST("/ack", postAck)
	a.POST("/floor/request", postFloorRequest)
	a.POST("/floor/release", postFloorRelease)
	a.GET("/livekit/token", getLKToken)
	a.POST("/media", uploadMedia)
	a.GET("/media/:file", getMedia)
	a.POST("/call/invite", callInvite)
	a.GET("/channels/:id/members", channelMembers)
	a.POST("/channels/join", joinChannel)
	a.POST("/channels/:id/leave", leaveChannel)
	a.GET("/config", getConfig)
	a.PUT("/keys", putKeys)
	a.GET("/keys/count", keyCount)
	a.GET("/keys/inbox", keyInbox)
	a.POST("/keys/ack", ackKeyMsgs)
	a.POST("/keys/send", sendKeyMsg)
	a.GET("/keys/user/:uid", getBundle)
	a.POST("/dm", openDM)
	a.POST("/bundles", postBundles)
	a.GET("/audit-key", getAuditKey)

	ad := a.Group("/admin", adminMW)
	ad.POST("/teams", createTeam)
	ad.POST("/channels", createChannel)
	ad.GET("/channels/:id", channelDetails)
	ad.DELETE("/channels/:id", deleteChannel)
	ad.GET("/channels/:id/stats", channelStats)
	ad.PUT("/audit-key", putAuditKey)
	ad.GET("/audit/queue", auditQueue)
	ad.POST("/audit/flags", postAuditFlags)
	ad.POST("/invites", createInvite)
	adminRoutes(ad)

	r.StaticFile("/admin", envOr("ADMIN_HTML", "../admin/index.html"))
}

type channel struct {
	ID     string `json:"id"`
	TeamID string `json:"team_id"`
	Name   string `json:"name"`
	Kind   string `json:"kind"`
}

func userChannels(uid string) []channel {
	out := []channel{}
	rows, err := db.Query(`SELECT c.id, c.team_id, c.name, c.kind FROM channels c
		JOIN members m ON m.channel_id=c.id WHERE m.user_id=? ORDER BY c.name`, uid)
	if err != nil {
		return out
	}
	defer rows.Close()
	for rows.Next() {
		var ch channel
		rows.Scan(&ch.ID, &ch.TeamID, &ch.Name, &ch.Kind)
		out = append(out, ch)
	}
	return out
}

func createTeam(c *gin.Context) {
	var in struct{ Name string }
	if c.BindJSON(&in) != nil || strings.TrimSpace(in.Name) == "" {
		c.JSON(400, gin.H{"error": "name required"})
		return
	}
	id := newID()
	db.Exec("INSERT INTO teams(id,name) VALUES(?,?)", id, in.Name)
	c.JSON(200, gin.H{"id": id, "name": in.Name})
}

func createChannel(c *gin.Context) {
	var in channel
	if c.BindJSON(&in) != nil || in.Name == "" || in.TeamID == "" {
		c.JSON(400, gin.H{"error": "team_id and name required"})
		return
	}
	if in.Kind != "zone" && in.Kind != "dm" {
		in.Kind = "team"
	}
	var n int
	if db.QueryRow("SELECT COUNT(*) FROM teams WHERE id=?", in.TeamID).Scan(&n); n == 0 {
		c.JSON(404, gin.H{"error": "team not found"})
		return
	}
	in.ID = newID()
	code := ""
	if in.Kind != "dm" {
		code = uniqueCode()
	}
	db.Exec("INSERT INTO channels(id,team_id,name,kind,invite_code) VALUES(?,?,?,?,NULLIF(?,''))", in.ID, in.TeamID, in.Name, in.Kind, code)
	// a new channel starts with exactly one admin: its creator; everyone else joins with its code
	db.Exec("INSERT OR IGNORE INTO members(user_id,channel_id) VALUES(?,?)", c.GetString("uid"), in.ID)
	c.JSON(200, gin.H{"id": in.ID, "team_id": in.TeamID, "name": in.Name, "kind": in.Kind, "invite_code": code})
}

func createInvite(c *gin.Context) {
	var in struct {
		TeamID  string `json:"team_id"`
		Role    string `json:"role"`
		MaxUses int    `json:"max_uses"`
	}
	if c.BindJSON(&in) != nil || in.TeamID == "" {
		c.JSON(400, gin.H{"error": "team_id required"})
		return
	}
	if in.Role != "admin" {
		in.Role = "member"
	}
	if in.MaxUses < 1 {
		in.MaxUses = 1
	}
	if in.MaxUses > 500 {
		in.MaxUses = 500
	}
	code := newCode()
	db.Exec("INSERT INTO invites(code,team_id,role,expires_at,max_uses) VALUES(?,?,?,?,?)",
		code, in.TeamID, in.Role, time.Now().Add(7*24*time.Hour).Unix(), in.MaxUses)
	payload, _ := json.Marshal(gin.H{"host": lanIP(), "port": 3000, "code": code})
	png, _ := qrcode.Encode(string(payload), qrcode.Medium, 512)
	c.JSON(200, gin.H{"code": code, "max_uses": in.MaxUses, "qr_png_base64":base64.StdEncoding.EncodeToString(png), "payload": string(payload)})
}

// lanIP picks the address of the interface used for outbound traffic; UDP dial sends nothing.
func lanIP() string {
	if h := envOr("HOST_IP", ""); h != "" {
		return h
	}
	conn, err := net.Dial("udp", "192.168.0.1:80")
	if err != nil {
		return "127.0.0.1"
	}
	defer conn.Close()
	return conn.LocalAddr().(*net.UDPAddr).IP.String()
}
