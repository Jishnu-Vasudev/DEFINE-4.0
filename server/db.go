package main

import (
	"crypto/rand"
	"database/sql"
	"fmt"
	"log"
	"time"

	_ "github.com/mattn/go-sqlite3"
)

var db *sql.DB

const schema = `
CREATE TABLE IF NOT EXISTS users(id TEXT PRIMARY KEY, name TEXT, role TEXT, revoked INT DEFAULT 0, last_seen INT);
CREATE TABLE IF NOT EXISTS teams(id TEXT PRIMARY KEY, name TEXT);
CREATE TABLE IF NOT EXISTS channels(id TEXT PRIMARY KEY, team_id TEXT, name TEXT, kind TEXT);
CREATE TABLE IF NOT EXISTS members(user_id TEXT, channel_id TEXT, UNIQUE(user_id, channel_id));
CREATE TABLE IF NOT EXISTS invites(code TEXT PRIMARY KEY, team_id TEXT, role TEXT, expires_at INT, used INT DEFAULT 0);
CREATE TABLE IF NOT EXISTS messages(seq INTEGER PRIMARY KEY AUTOINCREMENT, id TEXT UNIQUE, channel_id TEXT, sender_id TEXT, type TEXT, body TEXT, media TEXT, created_at INT, offline INT DEFAULT 0);
CREATE TABLE IF NOT EXISTS acks(message_id TEXT, user_id TEXT, at INT, UNIQUE(message_id, user_id));
`

func openDB(path string) {
	var err error
	db, err = sql.Open("sqlite3", path+"?_journal_mode=WAL&_busy_timeout=5000&_foreign_keys=on")
	if err != nil {
		log.Fatal(err)
	}
	db.SetMaxOpenConns(1)
	if _, err = db.Exec(schema); err != nil {
		log.Fatal(err)
	}
	// group invites: one QR, up to max_uses joins (errors if the column already exists)
	db.Exec("ALTER TABLE invites ADD COLUMN max_uses INT DEFAULT 1")
	seed()
	migrateChannelCodes()
	migrateKeys()
	// store-and-forward: who carried a relayed message to the server
	db.Exec("ALTER TABLE messages ADD COLUMN relayed_by TEXT")
	migrateAudit()
}

// seed creates the HQ team and an admin invite on first run.
func seed() {
	var n int
	db.QueryRow("SELECT COUNT(*) FROM users WHERE role='admin'").Scan(&n)
	if n > 0 {
		return
	}
	var code string
	err := db.QueryRow("SELECT code FROM invites WHERE role='admin' AND used=0").Scan(&code)
	if err == sql.ErrNoRows {
		teamID := newID()
		db.Exec("INSERT INTO teams(id,name) VALUES(?,?)", teamID, "HQ")
		db.Exec("INSERT INTO channels(id,team_id,name,kind) VALUES(?,?,?,?)", newID(), teamID, "General", "team")
		code = newCode()
		db.Exec("INSERT INTO invites(code,team_id,role,expires_at) VALUES(?,?,?,?)", code, teamID, "admin", time.Now().Add(365*24*time.Hour).Unix())
	}
	fmt.Printf("\n=== Bunny Hop ADMIN INVITE CODE: %s ===\n\n", code)
}

func newID() string {
	b := make([]byte, 16)
	rand.Read(b)
	return fmt.Sprintf("%x-%x-%x-%x-%x", b[0:4], b[4:6], b[6:8], b[8:10], b[10:])
}

func newCode() string {
	const abc = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
	b := make([]byte, 6)
	rand.Read(b)
	for i := range b {
		b[i] = abc[int(b[i])%len(abc)]
	}
	return string(b)
}
