import SwiftUI

@main
struct PulseApp: App {
    @UIApplicationDelegateAdaptor(PulseAppDelegate.self) private var appDelegate
    @StateObject private var pairingStore = PairingStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(pairingStore)
                .preferredColorScheme(.dark)
        }
    }
}
