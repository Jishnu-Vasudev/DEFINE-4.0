package main

import (
	"crypto/ed25519"
	"encoding/base64"
	"math/big"
	"strconv"

	"github.com/gin-gonic/gin"
)

// Delay-tolerant "muling": phones carry other people's messages (bundles) across the nearby
// mesh and hand them in here when any of them reaches the server. Each bundle is signed by its
// origin's Signal identity key, so a carrier can deliver a message but never forge or alter it.
type bundle struct {
	ID        string `json:"bundle_id"`
	Origin    string `json:"origin"`
	ChannelID string `json:"channel_id"`
	Type      string `json:"type"`
	Body      string `json:"body"`
	CreatedAt int64  `json:"created_at"`
	Hops      int    `json:"hops"`
	Sig       string `json:"sig"`
	Audit     string `json:"audit,omitempty"` // covered by the signature so a carrier cannot swap it
}

// bundleSigned is the exact byte string the origin signs on the phone.
func bundleSigned(b bundle) []byte {
	return []byte("relay-bundle\n" + b.ID + "\n" + b.ChannelID + "\n" + b.Origin + "\n" + b.Type + "\n" + b.Body + "\n" +
		strconv.FormatInt(b.CreatedAt, 10) + "\n" + b.Audit)
}

var p25519, _ = new(big.Int).SetString("7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffed", 16)

// verifyCurveSig checks a Signal (curve25519 / XEdDSA-style) signature: the Montgomery key is
// mapped to its Edwards form, the sign bit is taken from the signature, then plain Ed25519 verify.
func verifyCurveSig(identityKey, msg, sig []byte) bool {
	if len(identityKey) == 33 && identityKey[0] == 0x05 {
		identityKey = identityKey[1:]
	}
	if len(identityKey) != 32 || len(sig) != 64 {
		return false
	}
	le := make([]byte, 32)
	copy(le, identityKey)
	le[31] &= 0x7f
	be := make([]byte, 32)
	for i := range le {
		be[31-i] = le[i]
	}
	u := new(big.Int).SetBytes(be)
	num := new(big.Int).Sub(u, big.NewInt(1))
	den := new(big.Int).Add(u, big.NewInt(1))
	if den.Mod(den, p25519).Sign() == 0 {
		return false
	}
	y := num.Mul(num, den.ModInverse(den, p25519)).Mod(num, p25519)
	pub := make([]byte, 32)
	yb := y.FillBytes(make([]byte, 32))
	for i := range yb {
		pub[i] = yb[31-i]
	}
	pub[31] |= sig[63] & 0x80
	s := make([]byte, 64)
	copy(s, sig)
	s[63] &= 0x7f
	return ed25519.Verify(pub, msg, s)
}

func bundleOK(b bundle) string {
	if b.ID == "" || b.ChannelID == "" || b.Origin == "" || (b.Type != "enc" && b.Type != "sos") {
		return "invalid"
	}
	if !isMember(b.Origin, b.ChannelID) {
		return "not_member"
	}
	var ik string
	if db.QueryRow("SELECT identity_key FROM keys WHERE user_id=?", b.Origin).Scan(&ik) != nil {
		return "no_key"
	}
	key, err1 := base64.StdEncoding.DecodeString(ik)
	sig, err2 := base64.StdEncoding.DecodeString(b.Sig)
	if err1 != nil || err2 != nil || !verifyCurveSig(key, bundleSigned(b), sig) {
		return "bad_signature"
	}
	return ""
}

// postBundles ingests {list:[bundle]} carried by the caller; returns a status per bundle_id.
func postBundles(c *gin.Context) {
	var req struct {
		List []bundle `json:"list"`
	}
	if c.BindJSON(&req) != nil || len(req.List) > 500 {
		c.JSON(400, gin.H{"error": "array of up to 500 bundles required"})
		return
	}
	carrier := c.GetString("uid")
	out := gin.H{}
	for _, b := range req.List {
		if why := bundleOK(b); why != "" {
			out[b.ID] = why
			continue
		}
		res, err := db.Exec(`INSERT OR IGNORE INTO messages(id,channel_id,sender_id,type,body,media,created_at,offline,relayed_by,audit)
			VALUES(?,?,?,?,?,'',?,1,?,NULLIF(?,''))`, b.ID, b.ChannelID, b.Origin, b.Type, b.Body, b.CreatedAt, nullIfSame(carrier, b.Origin), b.Audit)
		if err != nil {
			out[b.ID] = "error"
			continue
		}
		if n, _ := res.RowsAffected(); n == 0 {
			out[b.ID] = "duplicate"
			continue
		}
		out[b.ID] = "stored"
		if m, err := scanMsg(db.QueryRow("SELECT "+msgCols+" WHERE m.id=?", b.ID)); err == nil {
			sendToChannel(b.ChannelID, gin.H{"t": "message", "message": m})
		}
	}
	c.JSON(200, out)
}

func nullIfSame(carrier, origin string) any {
	if carrier == origin {
		return nil
	}
	return carrier
}
