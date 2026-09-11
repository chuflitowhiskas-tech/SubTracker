import Foundation
import WidgetKit

/// Single source of truth for everything persisted in the shared App Group
/// container (`group.com.pulse.app`). Both the main app and
/// `PulseWidgetExtension` read/write exclusively through this type so the
/// storage format never drifts between targets.
///
/// The widget's timeline provider reads only from here (never the network),
/// which is what makes the Lock Screen widget render with zero lag.
enum PulseSharedStore {
    static let appGroupSuiteName = "group.com.pulse.app"

    static var defaults: UserDefaults {
        guard let defaults = UserDefaults(suiteName: appGroupSuiteName) else {
            // Falling back to `.standard` keeps the app usable (e.g. in SwiftUI
            // previews or a misconfigured App Group during development)
            // instead of crashing the process.
            return .standard
        }
        return defaults
    }

    private enum Key {
        static let session = "pulse.session"
        static let connectionState = "pulse.connectionState"
        static let partnerState = "pulse.partnerState"
        static let myMood = "pulse.myMood"
        static let pushEnabled = "pulse.pushEnabled"
        static let deviceToken = "pulse.deviceToken"
    }

    private static let encoder = JSONEncoder()
    private static let decoder = JSONDecoder()

    // MARK: - Session

    static var session: PulseSession? {
        get { decode(PulseSession.self, forKey: Key.session) }
        set { encode(newValue, forKey: Key.session) }
    }

    static var isAuthenticated: Bool { session != nil }

    // MARK: - Connection state

    static var connectionState: ConnectionState {
        get { decode(ConnectionState.self, forKey: Key.connectionState) ?? .idle }
        set { encode(newValue, forKey: Key.connectionState) }
    }

    // MARK: - Partner state (read by widget timeline)

    static var partnerState: PartnerState? {
        get { decode(PartnerState.self, forKey: Key.partnerState) }
        set { encode(newValue, forKey: Key.partnerState) }
    }

    // MARK: - My own mood (optimistic, written by widget intent + app)

    static var myMood: PulseMood {
        get {
            guard let raw = defaults.string(forKey: Key.myMood) else { return .good }
            return PulseMood(rawValue: raw) ?? .good
        }
        set { defaults.set(newValue.rawValue, forKey: Key.myMood) }
    }

    // MARK: - Push notification preference

    static var pushNotificationsEnabled: Bool {
        get { defaults.bool(forKey: Key.pushEnabled) }
        set { defaults.set(newValue, forKey: Key.pushEnabled) }
    }

    // MARK: - APNs device token (hex string)

    static var deviceToken: String? {
        get { defaults.string(forKey: Key.deviceToken) }
        set { defaults.set(newValue, forKey: Key.deviceToken) }
    }

    // MARK: - Widget update helper

    /// Applies a mood update (locally initiated or pushed by APNs) and asks
    /// WidgetKit to reload every timeline so the Lock Screen widget reflects
    /// it on the very next render pass.
    static func applyPartnerUpdate(partnerName: String, mood: PulseMood, updatedAt: Date = Date()) {
        partnerState = PartnerState(partnerName: partnerName, mood: mood, updatedAt: updatedAt)
        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: - Generic helpers

    private static func decode<T: Decodable>(_ type: T.Type, forKey key: String) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? decoder.decode(T.self, from: data)
    }

    private static func encode<T: Encodable>(_ value: T?, forKey key: String) {
        guard let value else {
            defaults.removeObject(forKey: key)
            return
        }
        guard let data = try? encoder.encode(value) else { return }
        defaults.set(data, forKey: key)
    }
}
