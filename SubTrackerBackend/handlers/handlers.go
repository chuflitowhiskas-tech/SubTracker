package handlers

import (
	"encoding/json"
	"net/http"
	"subtrackerbackend/db"
	"subtrackerbackend/models"
)

func RatesHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	var rates models.ExchangeRates
	err := db.DB.QueryRow("SELECT usd_pen, ars_pen FROM exchange_rates ORDER BY updated_at DESC LIMIT 1").Scan(&rates.USDPEN, &rates.ARSPEN)
	if err != nil {
		http.Error(w, "Failed to get exchange rates", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(rates)
}

func SubscriptionsHandler(w http.ResponseWriter, r *http.Request) {
	switch r.Method {
	case http.MethodGet:
		getSubscriptions(w, r)
	case http.MethodPost:
		createSubscription(w, r)
	case http.MethodPut:
		updateSubscription(w, r)
	case http.MethodDelete:
		deleteSubscription(w, r)
	default:
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
	}
}

func getSubscriptions(w http.ResponseWriter, r *http.Request) {
	rows, err := db.DB.Query("SELECT id, name, cost, currency, billingDay FROM subscriptions")
	if err != nil {
		http.Error(w, "Failed to get subscriptions", http.StatusInternalServerError)
		return
	}
	defer rows.Close()

	var subscriptions []models.Subscription
	for rows.Next() {
		var sub models.Subscription
		if err := rows.Scan(&sub.ID, &sub.Name, &sub.Cost, &sub.Currency, &sub.BillingDay); err != nil {
			continue
		}
		subscriptions = append(subscriptions, sub)
	}

	if subscriptions == nil {
		subscriptions = []models.Subscription{}
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(subscriptions)
}

func createSubscription(w http.ResponseWriter, r *http.Request) {
	var sub models.Subscription
	if err := json.NewDecoder(r.Body).Decode(&sub); err != nil {
		http.Error(w, "Invalid request payload", http.StatusBadRequest)
		return
	}

	stmt, err := db.DB.Prepare("INSERT INTO subscriptions(id, name, cost, currency, billingDay) VALUES(?, ?, ?, ?, ?)")
	if err != nil {
		http.Error(w, "Failed to prepare query", http.StatusInternalServerError)
		return
	}
	defer stmt.Close()

	_, err = stmt.Exec(sub.ID, sub.Name, sub.Cost, sub.Currency, sub.BillingDay)
	if err != nil {
		http.Error(w, "Failed to insert subscription", http.StatusInternalServerError)
		return
	}

	w.WriteHeader(http.StatusCreated)
}

func updateSubscription(w http.ResponseWriter, r *http.Request) {
	var sub models.Subscription
	if err := json.NewDecoder(r.Body).Decode(&sub); err != nil {
		http.Error(w, "Invalid request payload", http.StatusBadRequest)
		return
	}

	stmt, err := db.DB.Prepare("UPDATE subscriptions SET name=?, cost=?, currency=?, billingDay=? WHERE id=?")
	if err != nil {
		http.Error(w, "Failed to prepare query", http.StatusInternalServerError)
		return
	}
	defer stmt.Close()

	res, err := stmt.Exec(sub.Name, sub.Cost, sub.Currency, sub.BillingDay, sub.ID)
	if err != nil {
		http.Error(w, "Failed to update subscription", http.StatusInternalServerError)
		return
	}

	rowsAffected, _ := res.RowsAffected()
	if rowsAffected == 0 {
		http.Error(w, "Subscription not found", http.StatusNotFound)
		return
	}

	w.WriteHeader(http.StatusOK)
}

func deleteSubscription(w http.ResponseWriter, r *http.Request) {
	id := r.URL.Query().Get("id")
	if id == "" {
		http.Error(w, "ID is required", http.StatusBadRequest)
		return
	}

	stmt, err := db.DB.Prepare("DELETE FROM subscriptions WHERE id=?")
	if err != nil {
		http.Error(w, "Failed to prepare query", http.StatusInternalServerError)
		return
	}
	defer stmt.Close()

	res, err := stmt.Exec(id)
	if err != nil {
		http.Error(w, "Failed to delete subscription", http.StatusInternalServerError)
		return
	}

	rowsAffected, _ := res.RowsAffected()
	if rowsAffected == 0 {
		http.Error(w, "Subscription not found", http.StatusNotFound)
		return
	}

	w.WriteHeader(http.StatusOK)
}
