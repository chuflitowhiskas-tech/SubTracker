import Foundation

class ApiClient {
    static let shared = ApiClient()
    private let baseURL = "http://localhost:8080/api"

    func fetchRates() async throws -> ApiExchangeRates {
        guard let url = URL(string: "\(baseURL)/rates") else { throw URLError(.badURL) }
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode(ApiExchangeRates.self, from: data)
    }

    func fetchSubscriptions() async throws -> [ApiSubscription] {
        guard let url = URL(string: "\(baseURL)/subscriptions") else { throw URLError(.badURL) }
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode([ApiSubscription].self, from: data)
    }

    func createSubscription(_ sub: Subscription) async throws {
        guard let url = URL(string: "\(baseURL)/subscriptions") else { throw URLError(.badURL) }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let apiSub = ApiSubscription(id: sub.id, name: sub.name, cost: sub.cost, currency: sub.currency, billingDay: sub.billingDay)
        request.httpBody = try JSONEncoder().encode(apiSub)

        let (_, response) = try await URLSession.shared.data(for: request)
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 201 {
            throw URLError(.badServerResponse)
        }
    }

    func updateSubscription(_ sub: Subscription) async throws {
        guard let url = URL(string: "\(baseURL)/subscriptions") else { throw URLError(.badURL) }
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let apiSub = ApiSubscription(id: sub.id, name: sub.name, cost: sub.cost, currency: sub.currency, billingDay: sub.billingDay)
        request.httpBody = try JSONEncoder().encode(apiSub)

        let (_, response) = try await URLSession.shared.data(for: request)
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            throw URLError(.badServerResponse)
        }
    }

    func deleteSubscription(id: String) async throws {
        var components = URLComponents(string: "\(baseURL)/subscriptions")!
        components.queryItems = [URLQueryItem(name: "id", value: id)]
        guard let url = components.url else { throw URLError(.badURL) }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"

        let (_, response) = try await URLSession.shared.data(for: request)
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            throw URLError(.badServerResponse)
        }
    }
}
