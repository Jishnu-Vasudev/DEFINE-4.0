package main

import (
	"sync"
	"time"

	"github.com/gin-gonic/gin"
)

const floorTimeout = 30 * time.Second

// Floor priorities; a higher one pre-empts a lower one.
const (
	PriorityRoutine   = 1
	PriorityOps       = 2 // admin broadcast
	PriorityEmergency = 3
)

type floorHold struct {
	UserID   string
	Name     string
	Priority int
	timer    *time.Timer
}

var (
	floorMu sync.Mutex
	floors  = map[string]*floorHold{} // channel_id -> current talker
)

func init() {
	onUserOffline = func(uid string) {
		floorMu.Lock()
		var chans []string
		for ch, h := range floors {
			if h.UserID == uid {
				chans = append(chans, ch)
			}
		}
		floorMu.Unlock()
		for _, ch := range chans {
			releaseFloor(ch, uid)
		}
	}
}

func floorEvent(ch, state string, h *floorHold) {
	sendToChannel(ch, gin.H{"t": "floor", "channel_id": ch, "state": state,
		"user_id": h.UserID, "name": h.Name, "priority": h.Priority})
}

// floorHolder is used by the admin view to show who is talking.
func floorHolder(ch string) *floorHold {
	floorMu.Lock()
	defer floorMu.Unlock()
	return floors[ch]
}

func requestFloor(ch, uid, name string, prio int) (bool, *floorHold) {
	floorMu.Lock()
	cur := floors[ch]
	if cur != nil && cur.UserID != uid && cur.Priority >= prio {
		floorMu.Unlock()
		return false, cur
	}
	if cur != nil {
		cur.timer.Stop()
	}
	h := &floorHold{UserID: uid, Name: name, Priority: prio}
	h.timer = time.AfterFunc(floorTimeout, func() {
		floorMu.Lock()
		same := floors[ch] == h // ignore a stale timer from a refreshed hold
		floorMu.Unlock()
		if same {
			releaseFloor(ch, uid)
		}
	})
	floors[ch] = h
	floorMu.Unlock()

	if cur != nil && cur.UserID != uid {
		// pre-empted: tell the old talker to stop, cut their audio at the SFU too
		floorEvent(ch, "released", cur)
		sendToUser(cur.UserID, gin.H{"t": "force_mute", "channel_id": ch, "by": name, "priority": prio})
		go lkMuteParticipant(ch, cur.UserID)
	}
	if prio >= PriorityEmergency {
		sendToChannel(ch, gin.H{"t": "emergency_override", "channel_id": ch, "user_id": uid, "name": name})
	}
	floorEvent(ch, "granted", h)
	return true, h
}

func releaseFloor(ch, uid string) {
	floorMu.Lock()
	h := floors[ch]
	if h == nil || h.UserID != uid {
		floorMu.Unlock()
		return
	}
	h.timer.Stop()
	delete(floors, ch)
	floorMu.Unlock()
	floorEvent(ch, "released", h)
}

func postFloorRequest(c *gin.Context) {
	var in struct {
		ChannelID string `json:"channel_id"`
		Priority  int    `json:"priority"`
	}
	if c.BindJSON(&in) != nil || in.ChannelID == "" {
		c.JSON(400, gin.H{"error": "channel_id required"})
		return
	}
	uid := c.GetString("uid")
	if !isMember(uid, in.ChannelID) {
		c.JSON(403, gin.H{"error": "not a member"})
		return
	}
	// only admins may talk over others
	if in.Priority < 1 || in.Priority > 3 || c.GetString("role") != "admin" {
		in.Priority = 1
	}
	var name string
	db.QueryRow("SELECT name FROM users WHERE id=?", uid).Scan(&name)
	ok, h := requestFloor(in.ChannelID, uid, name, in.Priority)
	if ok {
		c.JSON(200, gin.H{"granted": true})
		return
	}
	c.JSON(200, gin.H{"granted": false, "holder": gin.H{"user_id": h.UserID, "name": h.Name, "priority": h.Priority}})
}

func postFloorRelease(c *gin.Context) {
	var in struct {
		ChannelID string `json:"channel_id"`
	}
	if c.BindJSON(&in) != nil || in.ChannelID == "" {
		c.JSON(400, gin.H{"error": "channel_id required"})
		return
	}
	releaseFloor(in.ChannelID, c.GetString("uid"))
	c.JSON(200, gin.H{"ok": true})
}
