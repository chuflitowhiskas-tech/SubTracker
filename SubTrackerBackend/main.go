package main

import (
	"log"
	"net/http"
	"subtrackerbackend/db"
	"subtrackerbackend/handlers"
	"subtrackerbackend/worker"
)

func main() {
	db.InitDB()
	worker.StartWorker()

	http.HandleFunc("/api/rates", handlers.RatesHandler)
	http.HandleFunc("/api/subscriptions", handlers.SubscriptionsHandler)

	log.Println("Server started on :8080")
	if err := http.ListenAndServe(":8080", nil); err != nil {
		log.Fatal(err)
	}
}
