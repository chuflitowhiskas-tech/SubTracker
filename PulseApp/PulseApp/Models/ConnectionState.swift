import Foundation

/// Client-side representation of the pairing state machine. Mirrors the
/// backend's `/connections/me` response and drives which screen `MainView`
/// shows. Swift synthesizes `Codable` for enums with associated values
/// (SE-0295), so this round-trips through `JSONEncoder`/`JSONDecoder`
/// unmodified for storage in the shared App Group `UserDefaults`.
enum ConnectionState: Equatable, Codable, Sendable {
    case idle
    case pendingOutgoing(partnerCode: String)
    case pendingIncoming(requestId: String, partnerName: String)
    case connected(partnerId: String, partnerName: String)

    var isConnected: Bool {
        if case .connected = self { return true }
        return false
    }
}
