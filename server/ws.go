package main

import (
	"encoding/json"
	"net/http"
	"sync"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/gorilla/websocket"
)

type client struct {
	uid      string
	send     chan []byte
	conn     *websocket.Conn
	lastPing time.Time
}

var (
	hubMu       sync.Mutex
	hub         = map[string]map[*client]bool{} // uid -> live connections
	offlineMode = map[string]bool{}             // uid -> phone reported nearby mode
	upgrader    = websocket.Upgrader{CheckOrigin: func(*http.Request) bool { return true }}
)

func isOnline(uid string) bool {
	hubMu.Lock()
	defer hubMu.Unlock()
	return len(hub[uid]) > 0
}

func sendToUser(uid string, v any) {
	b, _ := json.Marshal(v)
	hubMu.Lock()
	defer hubMu.Unlock()
	for c := range hub[uid] {
		select {
		case c.send <- b:
		default: // slow client: drop rather than block the hub
		}
	}
}

func sendToChannel(channelID string, v any) {
	rows, err := db.Query("SELECT user_id FROM members WHERE channel_id=?", channelID)
	if err != nil {
		return
	}
	var uids []string
	for rows.Next() {
		var u string
		rows.Scan(&u)
		uids = append(uids, u)
	}
	rows.Close()
	for _, u := range uids {
		sendToUser(u, v)
	}
}

func sendToAll(v any) {
	hubMu.Lock()
	uids := make([]string, 0, len(hub))
	for u := range hub {
		uids = append(uids, u)
	}
	hubMu.Unlock()
	for _, u := range uids {
		sendToUser(u, v)
	}
}

func wsHandler(c *gin.Context) {
	uid, _, ok := parseJWT(c.Query("token"))
	if !ok {
		c.AbortWithStatus(401)
		return
	}
	conn, err := upgrader.Upgrade(c.Writer, c.Request, nil)
	if err != nil {
		return
	}
	cl := &client{uid: uid, send: make(chan []byte, 64), conn: conn, lastPing: time.Now()}
	hubMu.Lock()
	first := len(hub[uid]) == 0
	if hub[uid] == nil {
		hub[uid] = map[*client]bool{}
	}
	hub[uid][cl] = true
	hubMu.Unlock()
	touch(uid)
	if first {
		sendToAll(gin.H{"t": "presence", "user_id": uid, "online": true})
	}
	go writePump(cl)
	readPump(cl)
}

func writePump(cl *client) {
	for b := range cl.send {
		cl.conn.SetWriteDeadline(time.Now().Add(10 * time.Second))
		if cl.conn.WriteMessage(websocket.TextMessage, b) != nil {
			cl.conn.Close()
			return
		}
	}
}

func readPump(cl *client) {
	defer dropClient(cl)
	for {
		// no ping for 25 s -> read times out -> client counted offline
		cl.conn.SetReadDeadline(time.Now().Add(25 * time.Second))
		_, b, err := cl.conn.ReadMessage()
		if err != nil {
			return
		}
		var m struct {
			T  string `json:"t"`
			On bool   `json:"on"`
		}
		if json.Unmarshal(b, &m) != nil {
			continue
		}
		switch m.T {
		case "ping":
			touch(cl.uid)
		case "offline_mode":
			hubMu.Lock()
			offlineMode[cl.uid] = m.On
			hubMu.Unlock()
		}
	}
}

func dropClient(cl *client) {
	cl.conn.Close()
	hubMu.Lock()
	delete(hub[cl.uid], cl)
	gone := len(hub[cl.uid]) == 0
	if gone {
		delete(hub, cl.uid)
	}
	close(cl.send)
	hubMu.Unlock()
	if gone {
		touch(cl.uid)
		sendToAll(gin.H{"t": "presence", "user_id": cl.uid, "online": false})
		onUserOffline(cl.uid)
	}
}

// onUserOffline is extended by later phases (floor release).
var onUserOffline = func(uid string) {}

func touch(uid string) {
	db.Exec("UPDATE users SET last_seen=? WHERE id=?", time.Now().Unix(), uid)
}
