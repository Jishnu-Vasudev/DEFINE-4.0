package main

import (
	"os"
	"path/filepath"

	"github.com/gin-gonic/gin"
)

// deleteChannel purges a channel with its members, messages, acks and uploaded files,
// then tells every former member so their apps drop it and leave the chat.
func deleteChannel(c *gin.Context) {
	id := c.Param("id")
	var name string
	if db.QueryRow("SELECT name FROM channels WHERE id=?", id).Scan(&name) != nil {
		c.JSON(404, gin.H{"error": "channel not found"})
		return
	}
	members := channelUserIDs(id)
	var files []string
	if rows, err := db.Query("SELECT media FROM messages WHERE channel_id=? AND COALESCE(media,'')!=''", id); err == nil {
		for rows.Next() {
			var f string
			rows.Scan(&f)
			files = append(files, f)
		}
		rows.Close()
	}
	tx, err := db.Begin()
	if err != nil {
		c.JSON(500, gin.H{"error": err.Error()})
		return
	}
	tx.Exec("DELETE FROM acks WHERE message_id IN (SELECT id FROM messages WHERE channel_id=?)", id)
	tx.Exec("DELETE FROM messages WHERE channel_id=?", id)
	tx.Exec("DELETE FROM key_msgs WHERE channel_id=?", id)
	tx.Exec("DELETE FROM members WHERE channel_id=?", id)
	tx.Exec("DELETE FROM channels WHERE id=?", id)
	if err := tx.Commit(); err != nil {
		c.JSON(500, gin.H{"error": err.Error()})
		return
	}
	for _, f := range files {
		os.Remove(filepath.Join("uploads", filepath.Base(f)))
	}
	floorMu.Lock()
	if h := floors[id]; h != nil {
		h.timer.Stop()
		delete(floors, id)
	}
	floorMu.Unlock()
	ev := gin.H{"t": "channel_deleted", "channel_id": id, "name": name}
	for _, uid := range members {
		sendToUser(uid, ev)
	}
	c.JSON(200, gin.H{"ok": true})
}

// leaveChannel removes only the caller's membership.
func leaveChannel(c *gin.Context) {
	uid, id := c.GetString("uid"), c.Param("id")
	if !isMember(uid, id) {
		c.JSON(404, gin.H{"error": "not a member"})
		return
	}
	db.Exec("DELETE FROM members WHERE user_id=? AND channel_id=?", uid, id)
	releaseFloor(id, uid)
	c.JSON(200, gin.H{"ok": true})
}

func channelUserIDs(id string) []string {
	out := []string{}
	rows, err := db.Query("SELECT user_id FROM members WHERE channel_id=?", id)
	if err != nil {
		return out
	}
	defer rows.Close()
	for rows.Next() {
		var u string
		rows.Scan(&u)
		out = append(out, u)
	}
	return out
}
