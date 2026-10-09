package main

import (
	"log"
	"os"
	"time"

	"github.com/gin-gonic/gin"
)

func main() {
	os.MkdirAll("uploads", 0o755)
	openDB("ptt.db")

	if jwtSecretIsDefault {
		log.Println("WARNING: using the default JWT_SECRET; set JWT_SECRET before real use")
	}
	r := gin.Default()
	routes(r)

	addr := "0.0.0.0:" + envOr("PORT", "3000")
	log.Printf("phones must reach: http://%s:%s  |  admin: http://%s:%s/admin  |  voice: %s", lanIP(), envOr("PORT", "3000"), lanIP(), envOr("PORT", "3000"), lkURL())
	go func() {
		time.Sleep(2 * time.Second)
		if !lkUp() {
			log.Println("WARNING: LiveKit is NOT running; push-to-talk and calls will fail. Start livekit-server first.")
		}
		log.Println("Voice needs Windows Firewall open for TCP 3000, 7880, 7881 and UDP 50000-50100 (run scripts/open-firewall.ps1 as admin).")
	}()
	log.Println("listening on " + addr)
	log.Fatal(r.Run(addr))
}
