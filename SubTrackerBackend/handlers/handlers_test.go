package handlers_test

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"path/filepath"
	"strings"
	"testing"

	"subtrackerbackend/db"
	"subtrackerbackend/handlers"
	"subtrackerbackend/models"
)

func setupTestDB(t *testing.T) {
	t.Helper()
	db.InitDBPath(filepath.Join(t.TempDir(), "test.db"))
	t.Cleanup(func() { db.DB.Close() })
}

func newRequest(t *testing.T, method, target, body string) *http.Request {
	t.Helper()
	return httptest.NewRequest(method, target, strings.NewReader(body))
}

func TestRatesHandlerReturnsLatestRates(t *testing.T) {
	setupTestDB(t)

	rec := httptest.NewRecorder()
	handlers.RatesHandler(rec, newRequest(t, http.MethodGet, "/api/rates", ""))

	if rec.Code != http.StatusOK {
		t.Fatalf("expected status 200, got %d", rec.Code)
	}
	if ct := rec.Header().Get("Content-Type"); ct != "application/json" {
		t.Errorf("expected Content-Type application/json, got %q", ct)
	}

	var rates models.ExchangeRates
	if err := json.Unmarshal(rec.Body.Bytes(), &rates); err != nil {
		t.Fatalf("failed to decode response: %v", err)
	}
	// insertDefaultRates seeds 3.8 / 0.003 when the table is empty.
	if rates.USDPEN != 3.8 || rates.ARSPEN != 0.003 {
		t.Errorf("expected rates 3.8/0.003, got %v/%v", rates.USDPEN, rates.ARSPEN)
	}
}

func TestRatesHandlerRejectsNonGetMethods(t *testing.T) {
	setupTestDB(t)

	for _, method := range []string{http.MethodPost, http.MethodPut, http.MethodDelete, http.MethodPatch} {
		rec := httptest.NewRecorder()
		handlers.RatesHandler(rec, newRequest(t, method, "/api/rates", ""))
		if rec.Code != http.StatusMethodNotAllowed {
			t.Errorf("method %s: expected 405, got %d", method, rec.Code)
		}
	}
}

func TestRatesHandlerReturns500WhenNoRatesStored(t *testing.T) {
	setupTestDB(t)
	if _, err := db.DB.Exec("DELETE FROM exchange_rates"); err != nil {
		t.Fatalf("failed to clear rates: %v", err)
	}

	rec := httptest.NewRecorder()
	handlers.RatesHandler(rec, newRequest(t, http.MethodGet, "/api/rates", ""))

	if rec.Code != http.StatusInternalServerError {
		t.Errorf("expected 500, got %d", rec.Code)
	}
}

func TestSubscriptionsCRUD(t *testing.T) {
	setupTestDB(t)

	// GET on an empty table returns an empty JSON array, not null.
	rec := httptest.NewRecorder()
	handlers.SubscriptionsHandler(rec, newRequest(t, http.MethodGet, "/api/subscriptions", ""))
	if rec.Code != http.StatusOK {
		t.Fatalf("GET empty: expected 200, got %d", rec.Code)
	}
	var empty []models.Subscription
	if err := json.Unmarshal(rec.Body.Bytes(), &empty); err != nil {
		t.Fatalf("GET empty: failed to decode response: %v", err)
	}
	if empty == nil || len(empty) != 0 {
		t.Errorf("GET empty: expected [], got %v", rec.Body.String())
	}

	// POST creates a subscription.
	rec = httptest.NewRecorder()
	handlers.SubscriptionsHandler(rec, newRequest(t, http.MethodPost, "/api/subscriptions",
		`{"id":"sub-1","name":"Netflix","cost":34.9,"currency":"PEN","billingDay":15}`))
	if rec.Code != http.StatusCreated {
		t.Fatalf("POST: expected 201, got %d", rec.Code)
	}

	// GET returns the stored subscription.
	rec = httptest.NewRecorder()
	handlers.SubscriptionsHandler(rec, newRequest(t, http.MethodGet, "/api/subscriptions", ""))
	var subs []models.Subscription
	if err := json.Unmarshal(rec.Body.Bytes(), &subs); err != nil {
		t.Fatalf("GET: failed to decode response: %v", err)
	}
	if len(subs) != 1 || subs[0].ID != "sub-1" || subs[0].Name != "Netflix" || subs[0].Cost != 34.9 ||
		subs[0].Currency != "PEN" || subs[0].BillingDay != 15 {
		t.Errorf("GET: unexpected subscription: %+v", subs)
	}

	// PUT updates the subscription.
	rec = httptest.NewRecorder()
	handlers.SubscriptionsHandler(rec, newRequest(t, http.MethodPut, "/api/subscriptions",
		`{"id":"sub-1","name":"Netflix Premium","cost":40,"currency":"USD","billingDay":1}`))
	if rec.Code != http.StatusOK {
		t.Fatalf("PUT: expected 200, got %d", rec.Code)
	}

	rec = httptest.NewRecorder()
	handlers.SubscriptionsHandler(rec, newRequest(t, http.MethodGet, "/api/subscriptions", ""))
	if err := json.Unmarshal(rec.Body.Bytes(), &subs); err != nil {
		t.Fatalf("GET after PUT: failed to decode response: %v", err)
	}
	if len(subs) != 1 || subs[0].Name != "Netflix Premium" || subs[0].Cost != 40 ||
		subs[0].Currency != "USD" || subs[0].BillingDay != 1 {
		t.Errorf("GET after PUT: unexpected subscription: %+v", subs)
	}

	// DELETE removes the subscription.
	rec = httptest.NewRecorder()
	handlers.SubscriptionsHandler(rec, newRequest(t, http.MethodDelete, "/api/subscriptions?id=sub-1", ""))
	if rec.Code != http.StatusOK {
		t.Fatalf("DELETE: expected 200, got %d", rec.Code)
	}

	rec = httptest.NewRecorder()
	handlers.SubscriptionsHandler(rec, newRequest(t, http.MethodGet, "/api/subscriptions", ""))
	if got := strings.TrimSpace(rec.Body.String()); got != "[]" {
		t.Errorf("GET after DELETE: expected [], got %s", got)
	}
}

func TestSubscriptionsUpdateUnknownIDReturns404(t *testing.T) {
	setupTestDB(t)

	rec := httptest.NewRecorder()
	handlers.SubscriptionsHandler(rec, newRequest(t, http.MethodPut, "/api/subscriptions",
		`{"id":"missing","name":"X","cost":1,"currency":"PEN","billingDay":1}`))

	if rec.Code != http.StatusNotFound {
		t.Errorf("expected 404, got %d", rec.Code)
	}
}

func TestSubscriptionsDeleteUnknownIDReturns404(t *testing.T) {
	setupTestDB(t)

	rec := httptest.NewRecorder()
	handlers.SubscriptionsHandler(rec, newRequest(t, http.MethodDelete, "/api/subscriptions?id=missing", ""))

	if rec.Code != http.StatusNotFound {
		t.Errorf("expected 404, got %d", rec.Code)
	}
}

func TestSubscriptionsDeleteRequiresID(t *testing.T) {
	setupTestDB(t)

	rec := httptest.NewRecorder()
	handlers.SubscriptionsHandler(rec, newRequest(t, http.MethodDelete, "/api/subscriptions", ""))

	if rec.Code != http.StatusBadRequest {
		t.Errorf("expected 400, got %d", rec.Code)
	}
}

func TestSubscriptionsRejectsInvalidPayload(t *testing.T) {
	setupTestDB(t)

	for _, method := range []string{http.MethodPost, http.MethodPut} {
		rec := httptest.NewRecorder()
		handlers.SubscriptionsHandler(rec, newRequest(t, method, "/api/subscriptions", "not json"))
		if rec.Code != http.StatusBadRequest {
			t.Errorf("method %s with bad body: expected 400, got %d", method, rec.Code)
		}
	}
}

func TestSubscriptionsHandlerRejectsUnsupportedMethod(t *testing.T) {
	setupTestDB(t)

	rec := httptest.NewRecorder()
	handlers.SubscriptionsHandler(rec, newRequest(t, http.MethodPatch, "/api/subscriptions", ""))

	if rec.Code != http.StatusMethodNotAllowed {
		t.Errorf("expected 405, got %d", rec.Code)
	}
}

func TestSubscriptionsCreateReturns500WhenDatabaseFails(t *testing.T) {
	setupTestDB(t)
	db.DB.Close()

	rec := httptest.NewRecorder()
	handlers.SubscriptionsHandler(rec, newRequest(t, http.MethodPost, "/api/subscriptions",
		`{"id":"sub-1","name":"Netflix","cost":34.9,"currency":"PEN","billingDay":15}`))

	if rec.Code != http.StatusInternalServerError {
		t.Errorf("expected 500, got %d", rec.Code)
	}
}
