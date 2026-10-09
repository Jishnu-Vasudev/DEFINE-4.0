package main

import (
	"os"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/golang-jwt/jwt/v5"
)

// shortcut: fixed default secret, set JWT_SECRET for a real deployment.
var (
	jwtSecret          = []byte(envOr("JWT_SECRET", "ptt-lan-secret"))
	jwtSecretIsDefault = os.Getenv("JWT_SECRET") == ""
)

func envOr(k, def string) string {
	if v := os.Getenv(k); v != "" {
		return v
	}
	return def
}

func makeJWT(uid, role string) string {
	t := jwt.NewWithClaims(jwt.SigningMethodHS256, jwt.MapClaims{
		"uid": uid, "role": role, "iat": time.Now().Unix(),
	})
	s, _ := t.SignedString(jwtSecret)
	return s
}

// parseJWT returns uid and role if the token is valid and the user is not revoked.
func parseJWT(s string) (string, string, bool) {
	t, err := jwt.Parse(s, func(*jwt.Token) (any, error) { return jwtSecret, nil },
		jwt.WithValidMethods([]string{"HS256"}))
	if err != nil || !t.Valid {
		return "", "", false
	}
	c := t.Claims.(jwt.MapClaims)
	uid, _ := c["uid"].(string)
	var role string
	var revoked int
	if db.QueryRow("SELECT role, revoked FROM users WHERE id=?", uid).Scan(&role, &revoked) != nil || revoked == 1 {
		return "", "", false
	}
	return uid, role, true
}

func authMW(c *gin.Context) {
	tok := strings.TrimPrefix(c.GetHeader("Authorization"), "Bearer ")
	if tok == "" {
		tok = c.Query("token")
	}
	uid, role, ok := parseJWT(tok)
	if !ok {
		c.AbortWithStatusJSON(401, gin.H{"error": "unauthorized"})
		return
	}
	c.Set("uid", uid)
	c.Set("role", role)
	c.Next()
}

func adminMW(c *gin.Context) {
	if c.GetString("role") != "admin" {
		c.AbortWithStatusJSON(403, gin.H{"error": "admin only"})
		return
	}
	c.Next()
}

func join(c *gin.Context) {
	var in struct{ Code, Name string }
	if c.BindJSON(&in) != nil || strings.TrimSpace(in.Name) == "" {
		c.JSON(400, gin.H{"error": "code and name required"})
		return
	}
	code := strings.ToUpper(strings.TrimSpace(in.Code))
	// claim a seat atomically so a group QR never admits more than max_uses people
	res, err := db.Exec("UPDATE invites SET used=used+1 WHERE code=? AND used<max_uses AND expires_at>?", code, time.Now().Unix())
	if err != nil {
		c.JSON(500, gin.H{"error": err.Error()})
		return
	}
	if n, _ := res.RowsAffected(); n == 0 {
		c.JSON(400, gin.H{"error": "invalid or used invite"})
		return
	}
	var teamID, role string
	db.QueryRow("SELECT team_id, role FROM invites WHERE code=?", code).Scan(&teamID, &role)
	uid := newID()
	name := strings.TrimSpace(in.Name)
	db.Exec("INSERT INTO users(id,name,role,last_seen) VALUES(?,?,?,?)", uid, name, role, time.Now().Unix())
	db.Exec("INSERT OR IGNORE INTO members(user_id,channel_id) SELECT ?, id FROM channels WHERE team_id=? AND kind!='dm'", uid, teamID)
	c.JSON(200, gin.H{
		"jwt":      makeJWT(uid, role),
		"user":     gin.H{"id": uid, "name": name, "role": role},
		"channels": userChannels(uid),
	})
}
