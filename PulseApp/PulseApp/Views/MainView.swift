import SwiftUI

/// Primary authenticated screen. Renders a header, a state-driven center
/// section (idle / pending-outgoing / pending-incoming / connected), the mood
/// grid when connected, and the bottom identity chip.
struct MainView: View {
    @EnvironmentObject private var store: PairingStore
    @State private var showSettings = false
    @State private var refreshTask: Task<Void, Never>?

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                header

                centerSection
                    .animation(.spring(response: 0.35, dampingFraction: 0.75), value: connectionKind)

                if store.connectionState.isConnected {
                    MoodButtonsGrid()
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                Spacer(minLength: 12)

                BottomIdentityChip()
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .background(PulseColor.backgroundBase.ignoresSafeArea())
        .scrollIndicators(.hidden)
        .sheet(isPresented: $showSettings) {
            SettingsSheet()
                .environmentObject(store)
        }
        .task { startPolling() }
        .onDisappear { refreshTask?.cancel() }
    }

    private var connectionKind: Int {
        switch store.connectionState {
        case .idle: return 0
        case .pendingOutgoing: return 1
        case .pendingIncoming: return 2
        case .connected: return 3
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("PULSE")
                    .font(.system(size: 12, weight: .bold))
                    .tracking(2.5)
                    .foregroundStyle(PulseColor.textMuted)

                Text(headerTitle)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(PulseColor.textPrimary)
            }

            Spacer()

            Button {
                showSettings = true
            } label: {
                Text("Ajustes")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(PulseColor.textPrimary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(PulseColor.backgroundSurface)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(PulseColor.border, lineWidth: 1))
            }
        }
        .padding(.top, 8)
    }

    private var headerTitle: String {
        if case .connected(_, let partnerName) = store.connectionState {
            return partnerName
        }
        return "Conectar en privado"
    }

    // MARK: - Center section

    @ViewBuilder
    private var centerSection: some View {
        switch store.connectionState {
        case .idle:
            IdleConnectCard()
        case .pendingOutgoing(let code):
            PendingOutgoingCard(partnerCode: code)
        case .pendingIncoming(_, let partnerName):
            PendingIncomingBanner(partnerName: partnerName)
        case .connected:
            ConnectedPartnerCard()
        }
    }

    // MARK: - Polling

    private func startPolling() {
        refreshTask?.cancel()
        refreshTask = Task {
            while !Task.isCancelled {
                if store.connectionState.isConnected {
                    await store.refreshPartnerStatus()
                } else {
                    await store.refreshConnectionStatus()
                }
                try? await Task.sleep(for: .seconds(15))
            }
        }
    }
}

#Preview {
    MainView()
        .environmentObject(PairingStore())
        .preferredColorScheme(.dark)
}
