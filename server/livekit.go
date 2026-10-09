package main

import (
	"time"

	"github.com/gin-gonic/gin"
	"github.com/golang-jwt/jwt/v5"
)

// LiveKit access tokens are plain HS256 JWTs; signing here avoids pulling the whole SDK.
var (
	lkKey    = envOr("LIVEKIT_KEY", "devkey")
	lkSecret = envOr("LIVEKIT_SECRET", "secret")
)

func lkURL() string { return envOr("LIVEKIT_URL", "ws://"+lanIP()+":7880") }

func lkToken(identity, name, room string) string {
	now := time.Now()
	t := jwt.NewWithClaims(jwt.SigningMethodHS256, jwt.MapClaims{
		"iss":  lkKey,
		"sub":  identity,
		"name": name,
		"nbf":  now.Add(-10 * time.Second).Unix(),
		"exp":  now.Add(12 * time.Hour).Unix(),
		"video": gin.H{"room": room, "roomJoin": true, "canPublish": true, "canSubscribe": true},
	})
	s, _ := t.SignedString([]byte(lkSecret))
	return s
}

func getLKToken(c *gin.Context) {
	room := c.Query("room")
	uid := c.GetString("uid")
	if room == "" || !(isMember(uid, room) || callAllowed(uid, room)) {
		c.JSON(403, gin.H{"error": "not allowed in room"})
		return
	}
	var name string
	db.QueryRow("SELECT name FROM users WHERE id=?", uid).Scan(&name)
	c.JSON(200, gin.H{"token": lkToken(uid, name, room), "url": lkURL()})
}
