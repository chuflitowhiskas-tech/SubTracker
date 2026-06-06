package worker

import (
	"encoding/json"
	"log"
	"net/http"
	"subtrackerbackend/db"
	"time"
)

type ERApiResponse struct {
	Rates struct {
		PEN float64 `json:"PEN"`
	} `json:"rates"`
}

type BluelyticsResponse struct {
	Blue struct {
		ValueSell float64 `json:"value_sell"`
	} `json:"blue"`
}

func StartWorker() {
	go func() {
		updateRates()
		ticker := time.NewTicker(1 * time.Hour)
		defer ticker.Stop()

		for {
			select {
			case <-ticker.C:
				updateRates()
			}
		}
	}()
}

func updateRates() {
	usdPen, err := fetchUSDPEN()
	if err != nil {
		log.Println("Error fetching USD to PEN rate:", err)
		return
	}

	usdArs, err := fetchUSDARS()
	if err != nil {
		log.Println("Error fetching USD to ARS rate:", err)
		return
	}

	arsPen := 0.0
	if usdArs > 0 {
		arsPen = usdPen / usdArs
	}

	insertRate(usdPen, arsPen)
}

func fetchUSDPEN() (float64, error) {
	resp, err := http.Get("https://open.er-api.com/v6/latest/USD")
	if err != nil {
		return 0, err
	}
	defer resp.Body.Close()

	var data ERApiResponse
	if err := json.NewDecoder(resp.Body).Decode(&data); err != nil {
		return 0, err
	}

	return data.Rates.PEN, nil
}

func fetchUSDARS() (float64, error) {
	resp, err := http.Get("https://api.bluelytics.com.ar/v2/latest")
	if err != nil {
		return 0, err
	}
	defer resp.Body.Close()

	var data BluelyticsResponse
	if err := json.NewDecoder(resp.Body).Decode(&data); err != nil {
		return 0, err
	}

	return data.Blue.ValueSell, nil
}

func insertRate(usdPen, arsPen float64) {
	stmt, err := db.DB.Prepare("INSERT INTO exchange_rates(usd_pen, ars_pen) VALUES(?, ?)")
	if err != nil {
		log.Println("Error preparing insert statement:", err)
		return
	}
	defer stmt.Close()

	_, err = stmt.Exec(usdPen, arsPen)
	if err != nil {
		log.Println("Error executing insert statement:", err)
	} else {
		log.Printf("Inserted exchange rates: USD/PEN = %.2f, ARS/PEN = %.5f\n", usdPen, arsPen)
	}
}
