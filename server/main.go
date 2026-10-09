package main

import (
	"log"
	"os"

	"github.com/gin-gonic/gin"
)

func main() {
	os.MkdirAll("uploads", 0o755)
	openDB("ptt.db")

	r := gin.Default()
	routes(r)

	addr := "0.0.0.0:" + envOr("PORT", "3000")
	log.Println("listening on " + addr)
	log.Fatal(r.Run(addr))
}
