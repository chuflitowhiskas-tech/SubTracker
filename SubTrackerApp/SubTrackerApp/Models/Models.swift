import Foundation
import SwiftData

@Model
final class Subscription: Identifiable {
    var id: String
    var name: String
    var cost: Double
    var currency: String // "PEN", "USD", "ARS"
    var billingDay: Int

    init(id: String = UUID().uuidString, name: String, cost: Double, currency: String, billingDay: Int) {
        self.id = id
        self.name = name
        self.cost = cost
        self.currency = currency
        self.billingDay = billingDay
    }
}

@Model
final class ExchangeRatesCache {
    var usdPen: Double
    var arsPen: Double
    var updatedAt: Date

    init(usdPen: Double = 3.8, arsPen: Double = 0.003, updatedAt: Date = Date()) {
        self.usdPen = usdPen
        self.arsPen = arsPen
        self.updatedAt = updatedAt
    }
}

struct ApiSubscription: Codable {
    let id: String
    let name: String
    let cost: Double
    let currency: String
    let billingDay: Int
}

struct ApiExchangeRates: Codable {
    let usd_pen: Double
    let ars_pen: Double
}
