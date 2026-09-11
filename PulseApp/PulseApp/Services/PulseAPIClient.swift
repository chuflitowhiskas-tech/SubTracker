import Foundation

/// Errors surfaced by `PulseAPIClient` to callers. UI code maps these to
/// user-facing Spanish copy at the call site.
enum PulseAPIError: Error, LocalizedError {
    case invalidURL
    case unauthorized
    case server(statusCode: Int, message: String?)
    case decoding(Error)
    case transport(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "URL inválida."
        case .unauthorized:
            return "Tu sesión expiró. Vuelve a intentarlo."
        case .server(let statusCode, let message):
            return message ?? "Error del servidor (\(statusCode))."
        case .decoding:
            return "No se pudo leer la respuesta del servidor."
        case .transport(let error):
            return error.localizedDescription
        }
    }
}

/// Thin async/await REST client for the Go VPS backend. Every authenticated
/// call attaches the guest session's bearer token from `PulseSharedStore`.
final class PulseAPIClient: @unchecked Sendable {
    static let shared = PulseAPIClient()

    private let baseURL = URL(string: "https://api.tu-vps.com/api/v1")!
    private let session: URLSession
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(session: URLSession = .shared) {
        self.session = session

        // The backend's REST contract uses camelCase keys throughout
        // (`displayName`, `requestId`, `connectionCode`, ...), unlike its
        // snake_case APNs payloads, so no key conversion strategy is applied
        // here — Swift property names are declared to match the wire format
        // exactly.
        self.encoder = JSONEncoder()

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    // MARK: - DTOs

    struct GuestAuthRequest: Encodable { let displayName: String }
    struct GuestAuthResponse: Decodable {
        let userId: String
        let connectionCode: String
        let token: String
    }

    struct DeviceTokenRequest: Encodable { let token: String }

    enum RemoteConnectionStatus: String, Decodable {
        case idle
        case pendingOutgoing = "pending_outgoing"
        case pendingIncoming = "pending_incoming"
        case connected
    }

    struct ConnectionStatusResponse: Decodable {
        let status: RemoteConnectionStatus
        let partnerCode: String?
        let requestId: String?
        let partnerName: String?
        let partnerId: String?
    }

    struct ConnectionRequestBody: Encodable { let code: String }
    struct ConnectionActionBody: Encodable { let requestId: String }

    struct StatusUpdateBody: Encodable { let mood: PulseMood }

    struct PartnerStatusResponse: Decodable {
        let partnerName: String
        let mood: PulseMood
        let updatedAt: Date
    }

    // MARK: - Auth

    func guestAuth(displayName: String) async throws -> GuestAuthResponse {
        try await send(
            path: "/auth/guest",
            method: "POST",
            body: GuestAuthRequest(displayName: displayName),
            authenticated: false
        )
    }

    func registerDeviceToken(_ token: String) async throws {
        let _: EmptyResponse = try await send(
            path: "/devices/token",
            method: "POST",
            body: DeviceTokenRequest(token: token)
        )
    }

    // MARK: - Connections

    func connectionStatus() async throws -> ConnectionStatusResponse {
        try await send(path: "/connections/me", method: "GET", body: Optional<EmptyBody>.none)
    }

    func requestConnection(code: String) async throws {
        let _: EmptyResponse = try await send(
            path: "/connections/request",
            method: "POST",
            body: ConnectionRequestBody(code: code)
        )
    }

    func acceptConnection(requestId: String) async throws {
        let _: EmptyResponse = try await send(
            path: "/connections/accept",
            method: "POST",
            body: ConnectionActionBody(requestId: requestId)
        )
    }

    func rejectConnection(requestId: String) async throws {
        let _: EmptyResponse = try await send(
            path: "/connections/reject",
            method: "POST",
            body: ConnectionActionBody(requestId: requestId)
        )
    }

    func disconnect() async throws {
        let _: EmptyResponse = try await send(
            path: "/connections/disconnect",
            method: "POST",
            body: Optional<EmptyBody>.none
        )
    }

    // MARK: - Status (mood)

    /// Best-effort optimistic mood push. The caller already updated local +
    /// widget state before this fires, so failures are swallowed by design.
    func postStatus(mood: PulseMood) async {
        do {
            let _: EmptyResponse = try await send(
                path: "/status",
                method: "POST",
                body: StatusUpdateBody(mood: mood)
            )
        } catch {
            // Optimistic execution: local + widget state is already correct.
            // The next successful sync or push notification reconciles state.
        }
    }

    func partnerStatus() async throws -> PartnerStatusResponse {
        try await send(path: "/status/partner", method: "GET", body: Optional<EmptyBody>.none)
    }

    // MARK: - Core request builder

    private struct EmptyBody: Encodable {}
    private struct EmptyResponse: Decodable {}

    private func send<Body: Encodable, Response: Decodable>(
        path: String,
        method: String,
        body: Body?,
        authenticated: Bool = true
    ) async throws -> Response {
        var url = baseURL
        url.append(path: path.hasPrefix("/") ? String(path.dropFirst()) : path)

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if authenticated {
            guard let token = PulseSharedStore.session?.token else {
                throw PulseAPIError.unauthorized
            }
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let body, !(body is EmptyBody) {
            do {
                request.httpBody = try encoder.encode(body)
            } catch {
                throw PulseAPIError.decoding(error)
            }
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw PulseAPIError.transport(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw PulseAPIError.server(statusCode: -1, message: "Respuesta inválida.")
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            if httpResponse.statusCode == 401 { throw PulseAPIError.unauthorized }
            let message = String(data: data, encoding: .utf8)
            throw PulseAPIError.server(statusCode: httpResponse.statusCode, message: message)
        }

        if Response.self == EmptyResponse.self, let empty = EmptyResponse() as? Response {
            return empty
        }

        do {
            return try decoder.decode(Response.self, from: data)
        } catch {
            throw PulseAPIError.decoding(error)
        }
    }
}
