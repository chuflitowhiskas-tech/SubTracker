package worker

import (
	"errors"
	"math"
	"path/filepath"
	"testing"

	"subtrackerbackend/db"
)

func setupTestDB(t *testing.T) {
	t.Helper()
	db.InitDBPath(filepath.Join(t.TempDir(), "test.db"))
	t.Cleanup(func() { db.DB.Close() })
	// Drop the seeded default row so assertions only see worker inserts.
	if _, err := db.DB.Exec("DELETE FROM exchange_rates"); err != nil {
		t.Fatalf("failed to clear rates: %v", err)
	}
}

func storedRateCount(t *testing.T) int {
	t.Helper()
	var count int
	if err := db.DB.QueryRow("SELECT COUNT(*) FROM exchange_rates").Scan(&count); err != nil {
		t.Fatalf("failed to count rates: %v", err)
	}
	return count
}

func lastStoredRate(t *testing.T) (usdPen, arsPen float64) {
	t.Helper()
	err := db.DB.QueryRow("SELECT usd_pen, ars_pen FROM exchange_rates ORDER BY id DESC LIMIT 1").
		Scan(&usdPen, &arsPen)
	if err != nil {
		t.Fatalf("failed to read latest rate: %v", err)
	}
	return usdPen, arsPen
}

func TestUpdateRatesWithInsertsUsdAndCrossRate(t *testing.T) {
	setupTestDB(t)

	updateRatesWith(
		func() (float64, error) { return 3.80, nil },
		func() (float64, error) { return 950, nil },
	)

	usdPen, arsPen := lastStoredRate(t)
	if usdPen != 3.80 {
		t.Errorf("expected usd_pen 3.80, got %v", usdPen)
	}
	// ARS/PEN is derived as USD/PEN divided by USD/ARS: 3.80 / 950 = 0.004.
	if math.Abs(arsPen-0.004) > 1e-9 {
		t.Errorf("expected ars_pen 0.004, got %v", arsPen)
	}
}

func TestUpdateRatesWithZeroUSDARSStoresZeroCrossRate(t *testing.T) {
	setupTestDB(t)

	updateRatesWith(
		func() (float64, error) { return 3.80, nil },
		func() (float64, error) { return 0, nil },
	)

	if n := storedRateCount(t); n != 1 {
		t.Fatalf("expected one row inserted, got %d", n)
	}
	usdPen, arsPen := lastStoredRate(t)
	if usdPen != 3.80 || arsPen != 0 {
		t.Errorf("expected 3.80/0, got %v/%v", usdPen, arsPen)
	}
}

func TestUpdateRatesWithFetchErrorSkipsInsert(t *testing.T) {
	cases := []struct {
		name string
		pen  func() (float64, error)
		ars  func() (float64, error)
	}{
		{
			name: "pen fetch fails",
			pen:  func() (float64, error) { return 0, errors.New("pen api down") },
			ars:  func() (float64, error) { return 950, nil },
		},
		{
			name: "ars fetch fails",
			pen:  func() (float64, error) { return 3.80, nil },
			ars:  func() (float64, error) { return 0, errors.New("ars api down") },
		},
	}

	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			setupTestDB(t)

			updateRatesWith(tc.pen, tc.ars)

			if n := storedRateCount(t); n != 0 {
				t.Errorf("expected no rows inserted, got %d", n)
			}
		})
	}
}
