package models

type Subscription struct {
	ID         string  `json:"id"`
	Name       string  `json:"name"`
	Cost       float64 `json:"cost"`
	Currency   string  `json:"currency"`
	BillingDay int     `json:"billingDay"`
}

type ExchangeRates struct {
	USDPEN float64 `json:"usd_pen"`
	ARSPEN float64 `json:"ars_pen"`
}
