import SwiftUI

/// Entry point view. Checks the shared App Group session to decide between
/// the guest onboarding flow and `MainView`, matching what the widget
/// extension sees so both surfaces never disagree about auth state.
struct RootView: View {
    @EnvironmentObject private var store: PairingStore
    @State private var hasBootstrapped = false

    var body: some View {
        ZStack {
            PulseColor.backgroundBase.ignoresSafeArea()

            if store.isAuthenticated {
                MainView()
                    .transition(.opacity)
            } else {
                OnboardingView()
                    .transition(.opacity)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: store.isAuthenticated)
        .task {
            guard !hasBootstrapped else { return }
            hasBootstrapped = true
            await store.bootstrap()
        }
    }
}

#Preview {
    RootView()
        .environmentObject(PairingStore())
}
