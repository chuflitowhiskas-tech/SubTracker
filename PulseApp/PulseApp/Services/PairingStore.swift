import Foundation
import WidgetKit
import UIKit

/// Observable façade over `PulseSharedStore` + `PulseAPIClient` that drives
/// `RootView`/`MainView`. Owns the async round-trips to the backend and keeps
/// the shared App Group storage (and therefore the widget) in sync with every
/// state transition.
@MainActor
final class PairingStore: ObservableObject {
    @Published private(set) var connectionState: ConnectionState
    @Published private(set) var partnerState: PartnerState?
    @Published private(set) var myMood: PulseMood
    @Published var isBusy = false
    @Published var lastErrorMessage: String?

    private let api: PulseAPIClient

    init(api: PulseAPIClient = .shared) {
        self.api = api
        self.connectionState = PulseSharedStore.connectionState
        self.partnerState = PulseSharedStore.partnerState
        self.myMood = PulseSharedStore.myMood
    }

    var session: PulseSession? { PulseSharedStore.session }
    var isAuthenticated: Bool { PulseSharedStore.isAuthenticated }

    // MARK: - Bootstrap

    func bootstrap() async {
        connectionState = PulseSharedStore.connectionState
        partnerState = PulseSharedStore.partnerState
        myMood = PulseSharedStore.myMood
        guard isAuthenticated else { return }
        await refreshConnectionStatus()
        if connectionState.isConnected {
            await refreshPartnerStatus()
        }
    }

    // MARK: - Auth

    func signInAsGuest(displayName: String) async {
        isBusy = true
        defer { isBusy = false }
        do {
            let response = try await api.guestAuth(displayName: displayName)
            PulseSharedStore.session = PulseSession(
                userId: response.userId,
                connectionCode: response.connectionCode,
                token: response.token,
                displayName: displayName
            )
            await refreshConnectionStatus()
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    // MARK: - Connection status polling

    func refreshConnectionStatus() async {
        do {
            let status = try await api.connectionStatus()
            let newState: ConnectionState
            switch status.status {
            case .idle:
                newState = .idle
            case .pendingOutgoing:
                newState = .pendingOutgoing(partnerCode: status.partnerCode ?? "")
            case .pendingIncoming:
                newState = .pendingIncoming(
                    requestId: status.requestId ?? "",
                    partnerName: status.partnerName ?? "Tu pareja"
                )
            case .connected:
                newState = .connected(
                    partnerId: status.partnerId ?? "",
                    partnerName: status.partnerName ?? "Tu pareja"
                )
            }
            connectionState = newState
            PulseSharedStore.connectionState = newState
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    func requestConnection(code: String) async {
        isBusy = true
        defer { isBusy = false }
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !trimmed.isEmpty else { return }
        do {
            try await api.requestConnection(code: trimmed)
            connectionState = .pendingOutgoing(partnerCode: trimmed)
            PulseSharedStore.connectionState = connectionState
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    func acceptIncomingRequest() async {
        guard case .pendingIncoming(let requestId, _) = connectionState else { return }
        isBusy = true
        defer { isBusy = false }
        do {
            try await api.acceptConnection(requestId: requestId)
            // Refresh from the server rather than fabricating `partnerId`
            // locally: `/connections/me` is the source of truth once the
            // backend has recorded the mutual pairing.
            await refreshConnectionStatus()
            if connectionState.isConnected {
                await refreshPartnerStatus()
            }
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    func rejectIncomingRequest() async {
        guard case .pendingIncoming(let requestId, _) = connectionState else { return }
        isBusy = true
        defer { isBusy = false }
        do {
            try await api.rejectConnection(requestId: requestId)
            connectionState = .idle
            PulseSharedStore.connectionState = .idle
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    func disconnect() async {
        isBusy = true
        defer { isBusy = false }
        do {
            try await api.disconnect()
            connectionState = .idle
            partnerState = nil
            PulseSharedStore.connectionState = .idle
            PulseSharedStore.partnerState = nil
            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    // MARK: - Mood

    /// Applies the mood change instantly to local + widget state, then fires
    /// the network call in the background. Mirrors the behavior required of
    /// `UpdateMoodIntent` so the app and the Lock Screen widget feel identical.
    func setMyMood(_ mood: PulseMood, haptics: Bool = true) {
        myMood = mood
        PulseSharedStore.myMood = mood
        WidgetCenter.shared.reloadAllTimelines()

        if haptics {
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
        }

        Task { await api.postStatus(mood: mood) }
    }

    // MARK: - Partner status

    func refreshPartnerStatus() async {
        do {
            let status = try await api.partnerStatus()
            let state = PartnerState(
                partnerName: status.partnerName,
                mood: status.mood,
                updatedAt: status.updatedAt
            )
            partnerState = state
            PulseSharedStore.partnerState = state
            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            // Non-fatal: MainView keeps showing the last cached partner state.
        }
    }

    /// Called by the app delegate when a silent push delivers a fresh
    /// partner mood, so the UI updates without waiting for a manual refresh.
    func applyRemotePartnerUpdate(partnerName: String, mood: PulseMood) {
        let state = PartnerState(partnerName: partnerName, mood: mood, updatedAt: Date())
        partnerState = state
    }
}
