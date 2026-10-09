package main

import (
	"encoding/base64"
	"encoding/json"
	"net"
	"strconv"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/skip2/go-qrcode"
)

func routes(r *gin.Engine) {
	r.GET("/health", func(c *gin.Context) { c.String(200, "ok") })
	// open http://<laptop>:3000/diag in a phone browser: proves the phone reaches the server
	r.GET("/diag", func(c *gin.Context) {
		c.JSON(200, gin.H{"server": "ok", "lan_ip": lanIP(), "livekit_url": lkURL(), "livekit_up": lkUp()})
	})
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

	ad := a.Group("/admin", adminMW)
	ad.POST("/teams", createTeam)
	ad.POST("/channels", createChannel)
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
	db.Exec("INSERT INTO channels(id,team_id,name,kind) VALUES(?,?,?,?)", in.ID, in.TeamID, in.Name, in.Kind)
	// existing team members and all admins join new team/zone channels
	db.Exec(`INSERT OR IGNORE INTO members(user_id,channel_id)
		SELECT DISTINCT m.user_id, ? FROM members m JOIN channels c ON c.id=m.channel_id WHERE c.team_id=?
		UNION SELECT id, ? FROM users WHERE role='admin'`, in.ID, in.TeamID, in.ID)
	c.JSON(200, in)
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
	var n int
	if db.QueryRow("SELECT COUNT(*) FROM teams WHERE id=?", in.TeamID).Scan(&n); n == 0 {
		c.JSON(404, gin.H{"error": "team not found"})
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
	if _, err := db.Exec("INSERT INTO invites(code,team_id,role,expires_at,max_uses) VALUES(?,?,?,?,?)",
		code, in.TeamID, in.Role, time.Now().Add(7*24*time.Hour).Unix(), in.MaxUses); err != nil {
		c.JSON(500, gin.H{"error": err.Error()})
		return
	}
	port, _ := strconv.Atoi(envOr("PORT", "3000")) // QR must carry the port the server really listens on
	payload, _ := json.Marshal(gin.H{"host": lanIP(), "port": port, "code": code})
	png, _ := qrcode.Encode(string(payload), qrcode.Medium, 512)
	c.JSON(200, gin.H{"code": code, "max_uses": in.MaxUses, "qr_png_base64": base64.StdEncoding.EncodeToString(png), "payload": string(payload)})
}

// lanIP is the address phones should use. HOST_IP wins; otherwise take the interface the OS
// routes LAN traffic through, but never a VirtualBox/Hyper-V/Docker/WSL/VPN adapter.
func lanIP() string {
	if h := envOr("HOST_IP", ""); h != "" {
		return h
	}
	var good []string
	ifs, _ := net.Interfaces()
	for _, ifc := range ifs {
		if ifc.Flags&net.FlagUp == 0 || ifc.Flags&net.FlagLoopback != 0 || virtualName(ifc.Name) {
			continue
		}
		addrs, _ := ifc.Addrs()
		for _, a := range addrs {
			if ipn, ok := a.(*net.IPNet); ok {
				if ip4 := ipn.IP.To4(); ip4 != nil && ip4.IsPrivate() {
					good = append(good, ip4.String())
				}
			}
		}
	}
	routed := ""
	if conn, err := net.Dial("udp", "192.168.0.1:80"); err == nil { // UDP dial sends nothing
		routed = conn.LocalAddr().(*net.UDPAddr).IP.String()
		conn.Close()
	}
	for _, g := range good {
		if g == routed {
			return routed
		}
	}
	if len(good) > 0 {
		return good[0]
	}
	if routed != "" {
		return routed
	}
	return "127.0.0.1"
}

func virtualName(n string) bool {
	n = strings.ToLower(n)
	for _, bad := range []string{"virtualbox", "vbox", "vmware", "vethernet", "hyper-v", "docker", "wsl", "veth", "br-", "tailscale", "zerotier", "vpn", "tap", "tun"} {
		if strings.Contains(n, bad) {
			return true
		}
	}
	return false
}
