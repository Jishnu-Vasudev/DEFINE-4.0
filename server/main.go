package main

import (
	"log"
	"net/http"
	"os"

	"github.com/gin-gonic/gin"
)

func main() {
	initDB()

	r := gin.Default()

	// Static admin dashboard
	adminHTML, err := os.ReadFile("../admin/index.html")
	if err != nil {
		log.Println("warn: admin/index.html not found, /admin will return 404")
	}
	r.GET("/admin", func(c *gin.Context) {
		if adminHTML == nil {
			c.Status(http.StatusNotFound)
			return
		}
		c.Data(http.StatusOK, "text/html; charset=utf-8", adminHTML)
	})

	// Health check
	r.GET("/health", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{"ok": true})
	})

	// Media folder
	os.MkdirAll("uploads", 0755)

	port := os.Getenv("PORT")
	if port == "" {
		port = "3000"
	}
	log.Printf("Listening on 0.0.0.0:%s", port)
	if err := r.Run("0.0.0.0:" + port); err != nil {
		log.Fatal(err)
	}
}
