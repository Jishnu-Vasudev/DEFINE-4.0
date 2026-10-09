package main

import (
	"path/filepath"
	"strings"
	"sync"

	"github.com/gin-gonic/gin"
)

var imageExt = map[string]bool{".jpg": true, ".jpeg": true, ".png": true, ".webp": true, ".gif": true}

func uploadMedia(c *gin.Context) {
	f, err := c.FormFile("file")
	if err != nil {
		c.JSON(400, gin.H{"error": "file required"})
		return
	}
	if f.Size > 15<<20 {
		c.JSON(413, gin.H{"error": "file too large"})
		return
	}
	ext := strings.ToLower(filepath.Ext(f.Filename))
	if !imageExt[ext] {
		c.JSON(400, gin.H{"error": "only images allowed"})
		return
	}
	name := newID() + ext
	if err := c.SaveUploadedFile(f, filepath.Join("uploads", name)); err != nil {
		c.JSON(500, gin.H{"error": err.Error()})
		return
	}
	c.JSON(200, gin.H{"media": name})
}

func getMedia(c *gin.Context) {
	// Base() strips any ../ so only files inside uploads/ are served
	c.File(filepath.Join("uploads", filepath.Base(c.Param("file"))))
}

// ---- 1:1 calls: room -> the two allowed user ids ----
var (
	callsMu sync.Mutex
	calls   = map[string][2]string{}
)

func callAllowed(uid, room string) bool {
	callsMu.Lock()
	defer callsMu.Unlock()
	p, ok := calls[room]
	return ok && (p[0] == uid || p[1] == uid)
}

func callInvite(c *gin.Context) {
	var in struct {
		ToUserID string `json:"to_user_id"`
	}
	uid := c.GetString("uid")
	if c.BindJSON(&in) != nil || in.ToUserID == "" || in.ToUserID == uid {
		c.JSON(400, gin.H{"error": "to_user_id required"})
		return
	}
	var name string
	if db.QueryRow("SELECT name FROM users WHERE id=? AND revoked=0", in.ToUserID).Scan(new(string)) != nil {
		c.JSON(404, gin.H{"error": "no such user"})
		return
	}
	db.QueryRow("SELECT name FROM users WHERE id=?", uid).Scan(&name)
	room := "call_" + newID()
	callsMu.Lock()
	calls[room] = [2]string{uid, in.ToUserID}
	callsMu.Unlock()
	sendToUser(in.ToUserID, gin.H{"t": "call_invite", "room": room, "from": gin.H{"id": uid, "name": name}})
	c.JSON(200, gin.H{"room": room})
}

func channelMembers(c *gin.Context) {
	ch := c.Param("id")
	if !isMember(c.GetString("uid"), ch) {
		c.JSON(403, gin.H{"error": "not a member"})
		return
	}
	out := []gin.H{}
	rows, err := db.Query(`SELECT u.id, u.name, u.role FROM users u JOIN members m ON m.user_id=u.id
		WHERE m.channel_id=? AND u.revoked=0 ORDER BY u.name`, ch)
	if err != nil {
		c.JSON(200, out)
		return
	}
	type mem struct{ id, name, role string }
	var list []mem
	for rows.Next() {
		var m mem
		rows.Scan(&m.id, &m.name, &m.role)
		list = append(list, m)
	}
	rows.Close()
	for _, m := range list {
		out = append(out, gin.H{"id": m.id, "name": m.name, "role": m.role, "online": isOnline(m.id)})
	}
	c.JSON(200, out)
}
