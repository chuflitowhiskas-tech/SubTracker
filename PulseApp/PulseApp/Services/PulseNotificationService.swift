import Foundation
import UserNotifications
import UIKit
import WidgetKit

/// Wraps `UNUserNotificationCenter` authorization and payload parsing for
/// both foreground presentation and silent background pushes. Shared by
/// `PulseAppDelegate` and `SettingsSheet`'s push toggle.
final class PulseNotificationService: NSObject, UNUserNotificationCenterDelegate {
    static let shared = PulseNotificationService()

    private override init() { super.init() }

    func configure() {
        UNUserNotificationCenter.current().delegate = self
    }

    @discardableResult
    func requestAuthorization() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
            PulseSharedStore.pushNotificationsEnabled = granted
            if granted {
                await MainActor.run { UIApplication.shared.registerForRemoteNotifications() }
            }
            return granted
        } catch {
            PulseSharedStore.pushNotificationsEnabled = false
            return false
        }
    }

    // MARK: - Foreground presentation

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // App is active: still surface alert + sound + badge per spec.
        completionHandler([.banner, .list, .sound, .badge])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        completionHandler()
    }

    // MARK: - Remote notification payload handling

    enum RemotePayloadKind {
        case moodUpdate(mood: PulseMood, partnerName: String)
        case connectionRequest(partnerName: String)
        case unknown
    }

    func parse(userInfo: [AnyHashable: Any]) -> RemotePayloadKind {
        guard let type = userInfo["type"] as? String else { return .unknown }

        switch type {
        case "mood_update":
            guard
                let moodRaw = userInfo["mood"] as? String,
                let mood = PulseMood(rawValue: moodRaw)
            else { return .unknown }
            let partnerName = (userInfo["partner_name"] as? String) ?? "Tu pareja"
            return .moodUpdate(mood: mood, partnerName: partnerName)

        case "connection_request":
            let partnerName = (userInfo["partner_name"] as? String) ?? "Alguien"
            return .connectionRequest(partnerName: partnerName)

        default:
            return .unknown
        }
    }

    /// Handles a `content-available: 1` silent push: updates shared storage,
    /// reloads widget timelines, and returns the fetch result the system
    /// expects from `application(_:didReceiveRemoteNotification:fetchCompletionHandler:)`.
    @MainActor
    func handleBackgroundPush(userInfo: [AnyHashable: Any]) -> UIBackgroundFetchResult {
        switch parse(userInfo: userInfo) {
        case .moodUpdate(let mood, let partnerName):
            PulseSharedStore.applyPartnerUpdate(partnerName: partnerName, mood: mood)
            return .newData

        case .connectionRequest(let partnerName):
            postLocalConnectionRequestBanner(partnerName: partnerName)
            return .newData

        case .unknown:
            return .noData
        }
    }

    /// Presents the visible local banner required for `connection_request`
    /// pushes: "[Partner] quiere conectarse contigo".
    func postLocalConnectionRequestBanner(partnerName: String) {
        let content = UNMutableNotificationContent()
        content.title = "Pulse"
        content.body = "\(partnerName) quiere conectarse contigo"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "connection-request-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
}
