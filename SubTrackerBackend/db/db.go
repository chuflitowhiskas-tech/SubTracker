package db

import (
	"database/sql"
	"log"

	_ "github.com/mattn/go-sqlite3"
)

var DB *sql.DB

func InitDB() {
	var err error
	DB, err = sql.Open("sqlite3", "./subtracker.db")
	if err != nil {
		log.Fatal("Failed to open database:", err)
	}

	createTables()
}

func createTables() {
	createSubscriptionsTable := `
	CREATE TABLE IF NOT EXISTS subscriptions (
		id TEXT PRIMARY KEY,
		name TEXT NOT NULL,
		cost REAL NOT NULL,
		currency TEXT NOT NULL,
		billingDay INTEGER NOT NULL
	);`

	createExchangeRatesTable := `
	CREATE TABLE IF NOT EXISTS exchange_rates (
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		usd_pen REAL NOT NULL,
		ars_pen REAL NOT NULL,
		updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
	);`

	_, err := DB.Exec(createSubscriptionsTable)
	if err != nil {
		log.Fatal("Failed to create subscriptions table:", err)
	}

	_, err = DB.Exec(createExchangeRatesTable)
	if err != nil {
		log.Fatal("Failed to create exchange_rates table:", err)
	}

	insertDefaultRates()
}

func insertDefaultRates() {
	var count int
	DB.QueryRow("SELECT COUNT(*) FROM exchange_rates").Scan(&count)
	if count == 0 {
		DB.Exec("INSERT INTO exchange_rates(usd_pen, ars_pen) VALUES(3.8, 0.003)")
	}
}
