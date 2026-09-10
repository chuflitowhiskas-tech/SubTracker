import UIKit
import UserNotifications
import WidgetKit

/// `UIApplicationDelegate` bridge used from the `@main` `App` struct via
/// `@UIApplicationDelegateAdaptor`. Owns remote-notification registration and
/// the silent-push → shared-storage → widget-reload pipeline.
final class PulseAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        PulseNotificationService.shared.configure()

        if PulseSharedStore.pushNotificationsEnabled {
            application.registerForRemoteNotifications()
        }

        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        PulseSharedStore.deviceToken = tokenString
        Task {
            try? await PulseAPIClient.shared.registerDeviceToken(tokenString)
        }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        // Non-fatal: mood updates still work via manual pull-to-refresh.
    }

    /// Handles `content-available: 1` silent pushes for `mood_update`, and
    /// surfaces a visible local banner for `connection_request` pushes.
    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        Task { @MainActor in
            let result = PulseNotificationService.shared.handleBackgroundPush(userInfo: userInfo)
            completionHandler(result)
        }
    }
}
