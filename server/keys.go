package main

import (
	"time"

	"github.com/gin-gonic/gin"
)

// E2EE key directory and sealed key-message relay. The server only stores public keys and
// opaque ciphertext; it can never read message text or media.
const keySchema = `
CREATE TABLE IF NOT EXISTS keys(user_id TEXT PRIMARY KEY, registration_id INT, identity_key TEXT, signed_id INT, signed_pub TEXT, signed_sig TEXT);
CREATE TABLE IF NOT EXISTS prekeys(user_id TEXT, key_id INT, pub TEXT, PRIMARY KEY(user_id, key_id));
CREATE TABLE IF NOT EXISTS key_msgs(id INTEGER PRIMARY KEY AUTOINCREMENT, to_user TEXT, from_user TEXT, channel_id TEXT, type INT, body TEXT, created_at INT);
`

func migrateKeys() { db.Exec(keySchema) }

type preKey struct {
	ID  int    `json:"id"`
	Pub string `json:"pub"`
}

// putKeys replaces the caller's identity + signed pre-key and adds one-time pre-keys.
func putKeys(c *gin.Context) {
	var in struct {
		RegistrationID int    `json:"registration_id"`
		IdentityKey    string `json:"identity_key"`
		Signed         struct {
			ID  int    `json:"id"`
			Pub string `json:"pub"`
			Sig string `json:"sig"`
		} `json:"signed_prekey"`
		PreKeys []preKey `json:"prekeys"`
	}
	if c.BindJSON(&in) != nil || in.IdentityKey == "" || in.Signed.Pub == "" {
		c.JSON(400, gin.H{"error": "identity_key and signed_prekey required"})
		return
	}
	uid := c.GetString("uid")
	var old string
	db.QueryRow("SELECT identity_key FROM keys WHERE user_id=?", uid).Scan(&old)
	if old != "" && old != in.IdentityKey {
		db.Exec("DELETE FROM prekeys WHERE user_id=?", uid) // new identity: old pre-keys are useless
	}
	db.Exec(`INSERT OR REPLACE INTO keys(user_id,registration_id,identity_key,signed_id,signed_pub,signed_sig) VALUES(?,?,?,?,?,?)`,
		uid, in.RegistrationID, in.IdentityKey, in.Signed.ID, in.Signed.Pub, in.Signed.Sig)
	for _, k := range in.PreKeys {
		db.Exec("INSERT OR REPLACE INTO prekeys(user_id,key_id,pub) VALUES(?,?,?)", uid, k.ID, k.Pub)
	}
	c.JSON(200, gin.H{"prekeys": preKeyCount(uid)})
}

func preKeyCount(uid string) int {
	var n int
	db.QueryRow("SELECT COUNT(*) FROM prekeys WHERE user_id=?", uid).Scan(&n)
	return n
}

func keyCount(c *gin.Context) { c.JSON(200, gin.H{"prekeys": preKeyCount(c.GetString("uid"))}) }

// getBundle hands out a pre-key bundle and consumes one one-time pre-key (X3DH).
func getBundle(c *gin.Context) {
	uid := c.Param("uid")
	out := gin.H{"user_id": uid}
	var reg, sid int
	var ik, spub, ssig string
	if db.QueryRow("SELECT registration_id,identity_key,signed_id,signed_pub,signed_sig FROM keys WHERE user_id=?", uid).
		Scan(&reg, &ik, &sid, &spub, &ssig) != nil {
		c.JSON(404, gin.H{"error": "no keys for user"})
		return
	}
	out["registration_id"], out["identity_key"] = reg, ik
	out["signed_prekey"] = gin.H{"id": sid, "pub": spub, "sig": ssig}
	var k preKey
	if db.QueryRow("SELECT key_id,pub FROM prekeys WHERE user_id=? ORDER BY key_id LIMIT 1", uid).Scan(&k.ID, &k.Pub) == nil {
		db.Exec("DELETE FROM prekeys WHERE user_id=? AND key_id=?", uid, k.ID)
		out["prekey"] = k
	}
	c.JSON(200, out)
}

// sendKeyMsg relays a pairwise-encrypted key message (e.g. a channel sender key) to one member.
func sendKeyMsg(c *gin.Context) {
	var in struct {
		To        string `json:"to"`
		ChannelID string `json:"channel_id"`
		Type      int    `json:"type"`
		Body      string `json:"body"`
	}
	uid := c.GetString("uid")
	if c.BindJSON(&in) != nil || in.To == "" || in.Body == "" || !isMember(uid, in.ChannelID) || !isMember(in.To, in.ChannelID) {
		c.JSON(400, gin.H{"error": "to, body and a shared channel_id required"})
		return
	}
	now := time.Now().UnixMilli()
	res, err := db.Exec("INSERT INTO key_msgs(to_user,from_user,channel_id,type,body,created_at) VALUES(?,?,?,?,?,?)",
		in.To, uid, in.ChannelID, in.Type, in.Body, now)
	if err != nil {
		c.JSON(500, gin.H{"error": err.Error()})
		return
	}
	id, _ := res.LastInsertId()
	sendToUser(in.To, gin.H{"t": "key", "id": id, "from": uid, "channel_id": in.ChannelID, "type": in.Type, "body": in.Body})
	c.JSON(200, gin.H{"id": id})
}

func keyInbox(c *gin.Context) {
	out := []gin.H{}
	rows, err := db.Query("SELECT id,from_user,channel_id,type,body FROM key_msgs WHERE to_user=? ORDER BY id", c.GetString("uid"))
	if err == nil {
		for rows.Next() {
			var id int64
			var from, ch, body string
			var typ int
			rows.Scan(&id, &from, &ch, &typ, &body)
			out = append(out, gin.H{"id": id, "from": from, "channel_id": ch, "type": typ, "body": body})
		}
		rows.Close()
	}
	c.JSON(200, out)
}

func ackKeyMsgs(c *gin.Context) {
	var in struct {
		IDs []int64 `json:"ids"`
	}
	c.BindJSON(&in)
	for _, id := range in.IDs {
		db.Exec("DELETE FROM key_msgs WHERE id=? AND to_user=?", id, c.GetString("uid"))
	}
	c.JSON(200, gin.H{"ok": true})
}

// openDM returns (creating once) the direct channel between the caller and another user.
func openDM(c *gin.Context) {
	var in struct {
		UserID string `json:"user_id"`
	}
	uid := c.GetString("uid")
	var peer string
	if c.BindJSON(&in) != nil || in.UserID == uid || db.QueryRow("SELECT name FROM users WHERE id=? AND revoked=0", in.UserID).Scan(&peer) != nil {
		c.JSON(400, gin.H{"error": "valid user_id required"})
		return
	}
	var id string
	db.QueryRow(`SELECT c.id FROM channels c JOIN members a ON a.channel_id=c.id AND a.user_id=?
		JOIN members b ON b.channel_id=c.id AND b.user_id=? WHERE c.kind='dm' LIMIT 1`, uid, in.UserID).Scan(&id)
	if id == "" {
		var me string
		db.QueryRow("SELECT name FROM users WHERE id=?", uid).Scan(&me)
		id = newID()
		db.Exec("INSERT INTO channels(id,team_id,name,kind) VALUES(?,?,?,?)", id, "", me+" & "+peer, "dm")
		db.Exec("INSERT OR IGNORE INTO members(user_id,channel_id) VALUES(?,?),(?,?)", uid, id, in.UserID, id)
	}
	for _, ch := range userChannels(uid) {
		if ch.ID == id {
			sendToUser(in.UserID, gin.H{"t": "channel_added", "channel": ch})
			c.JSON(200, ch)
			return
		}
	}
	c.JSON(500, gin.H{"error": "dm failed"})
}
