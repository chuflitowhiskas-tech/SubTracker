import Foundation

/// Authenticated guest session returned by `POST /auth/guest`. Persisted in
/// the shared App Group storage so both the app and the widget extension
/// intent handler can find a token without inter-process calls.
struct PulseSession: Codable, Equatable, Sendable {
    var userId: String
    var connectionCode: String
    var token: String
    var displayName: String
}
