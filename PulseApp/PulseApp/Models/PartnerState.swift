import Foundation

/// Latest known status of the paired partner, cached in the App Group so the
/// Lock Screen widget can render without a network round-trip.
struct PartnerState: Codable, Equatable, Sendable {
    var partnerName: String
    var mood: PulseMood
    var updatedAt: Date

    /// Localized "hace Xm" / "hace Xh" relative label used by both the app
    /// and the widget's row 1 layout.
    var relativeUpdatedAtLabel: String {
        let seconds = max(0, Date().timeIntervalSince(updatedAt))
        let minutes = Int(seconds / 60)
        if minutes < 1 { return "hace un momento" }
        if minutes < 60 { return "hace \(minutes) min" }
        let hours = minutes / 60
        if hours < 24 { return "hace \(hours) h" }
        let days = hours / 24
        return "hace \(days) d"
    }
}
