package main

import (
	"crypto/rand"
	"database/sql"
	"encoding/hex"
	"fmt"
	"log"
	"os"

	_ "github.com/mattn/go-sqlite3"
)

var db *sql.DB

func initDB() {
	dbPath := os.Getenv("DB_PATH")
	if dbPath == "" {
		dbPath = "data.db"
	}
	var err error
	db, err = sql.Open("sqlite3", dbPath+"?_journal_mode=WAL&_foreign_keys=on")
	if err != nil {
		log.Fatal("db open:", err)
	}
	if err = db.Ping(); err != nil {
		log.Fatal("db ping:", err)
	}
	applySchema()
	seedAdmin()
}

func applySchema() {
	stmts := []string{
		`CREATE TABLE IF NOT EXISTS users (
			id TEXT PRIMARY KEY,
			name TEXT NOT NULL,
			role TEXT NOT NULL DEFAULT 'member',
			revoked INTEGER NOT NULL DEFAULT 0,
			last_seen INTEGER NOT NULL DEFAULT 0
		)`,
		`CREATE TABLE IF NOT EXISTS teams (
			id TEXT PRIMARY KEY,
			name TEXT NOT NULL
		)`,
		`CREATE TABLE IF NOT EXISTS channels (
			id TEXT PRIMARY KEY,
			team_id TEXT NOT NULL,
			name TEXT NOT NULL,
			kind TEXT NOT NULL DEFAULT 'team'
		)`,
		`CREATE TABLE IF NOT EXISTS members (
			user_id TEXT NOT NULL,
			channel_id TEXT NOT NULL,
			PRIMARY KEY (user_id, channel_id)
		)`,
		`CREATE TABLE IF NOT EXISTS invites (
			code TEXT PRIMARY KEY,
			team_id TEXT NOT NULL,
			role TEXT NOT NULL DEFAULT 'member',
			expires_at INTEGER NOT NULL,
			used INTEGER NOT NULL DEFAULT 0
		)`,
		`CREATE TABLE IF NOT EXISTS messages (
			seq INTEGER PRIMARY KEY AUTOINCREMENT,
			id TEXT UNIQUE NOT NULL,
			channel_id TEXT NOT NULL,
			sender_id TEXT NOT NULL,
			type TEXT NOT NULL,
			body TEXT,
			media TEXT,
			created_at INTEGER NOT NULL,
			offline INTEGER NOT NULL DEFAULT 0
		)`,
		`CREATE TABLE IF NOT EXISTS acks (
			message_id TEXT NOT NULL,
			user_id TEXT NOT NULL,
			at INTEGER NOT NULL,
			PRIMARY KEY (message_id, user_id)
		)`,
	}
	for _, s := range stmts {
		if _, err := db.Exec(s); err != nil {
			log.Fatal("schema:", err)
		}
	}
}

func seedAdmin() {
	var count int
	db.QueryRow(`SELECT COUNT(*) FROM users WHERE role='admin'`).Scan(&count)
	if count > 0 {
		return
	}

	// create default team
	teamID := newID()
	db.Exec(`INSERT INTO teams(id,name) VALUES(?,?)`, teamID, "Default")

	// create admin user
	adminID := newID()
	db.Exec(`INSERT INTO users(id,name,role,last_seen) VALUES(?,?,?,0)`, adminID, "Admin", "admin")

	// create admin invite code (single-use, 1 year)
	code := newCode()
	db.Exec(`INSERT INTO invites(code,team_id,role,expires_at,used) VALUES(?,?,?,?,0)`,
		code, teamID, "admin", 9999999999)

	fmt.Printf("\n=== ADMIN INVITE CODE: %s ===\n\n", code)
}

func newID() string {
	b := make([]byte, 16)
	rand.Read(b)
	return hex.EncodeToString(b)
}

func newCode() string {
	b := make([]byte, 4)
	rand.Read(b)
	return hex.EncodeToString(b)
}
