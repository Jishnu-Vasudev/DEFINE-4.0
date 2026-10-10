package main

import (
	"bytes"
	"encoding/json"
	"log"
	"net/http"
	"strings"
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

func lkAdminToken(room string) string {
	now := time.Now()
	t := jwt.NewWithClaims(jwt.SigningMethodHS256, jwt.MapClaims{
		"iss": lkKey, "sub": "relay-server", "nbf": now.Add(-10 * time.Second).Unix(), "exp": now.Add(time.Minute).Unix(),
		"video": gin.H{"room": room, "roomAdmin": true},
	})
	s, _ := t.SignedString([]byte(lkSecret))
	return s
}

// lkTwirp calls the LiveKit RoomService HTTP API (no SDK needed).
func lkTwirp(method, room string, in, out any) error {
	b, _ := json.Marshal(in)
	url := strings.Replace(strings.Replace(lkURL(), "wss://", "https://", 1), "ws://", "http://", 1) + "/twirp/livekit.RoomService/" + method
	req, _ := http.NewRequest("POST", url, bytes.NewReader(b))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+lkAdminToken(room))
	res, err := (&http.Client{Timeout: 3 * time.Second}).Do(req)
	if err != nil {
		return err
	}
	defer res.Body.Close()
	if res.StatusCode != 200 {
		return &lkError{res.StatusCode}
	}
	if out == nil {
		return nil
	}
	return json.NewDecoder(res.Body).Decode(out)
}

type lkError struct{ status int }

func (e *lkError) Error() string { return "livekit api status " + http.StatusText(e.status) }

// lkMuteParticipant server-side mutes every audio track of a pre-empted talker, so a stuck or
// misbehaving client cannot keep transmitting after losing the floor.
func lkMuteParticipant(room, identity string) {
	var p struct {
		Tracks []struct {
			Sid  string `json:"sid"`
			Type any    `json:"type"`
		} `json:"tracks"`
	}
	if err := lkTwirp("GetParticipant", room, gin.H{"room": room, "identity": identity}, &p); err != nil {
		log.Println("force mute: get participant:", err)
		return
	}
	for _, t := range p.Tracks {
		if t.Type == "AUDIO" || t.Type == float64(0) {
			if err := lkTwirp("MutePublishedTrack", room, gin.H{"room": room, "identity": identity, "track_sid": t.Sid, "muted": true}, nil); err != nil {
				log.Println("force mute:", err)
			}
		}
	}
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
