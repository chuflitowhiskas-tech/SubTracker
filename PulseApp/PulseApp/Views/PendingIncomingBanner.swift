import SwiftUI
import UIKit

/// Shown when `ConnectionState == .pendingIncoming`: a prominent banner with
/// Accept (success style) / Reject (muted style) actions.
struct PendingIncomingBanner: View {
    let partnerName: String
    @EnvironmentObject private var store: PairingStore

    var body: some View {
        VStack(spacing: 18) {
            VStack(spacing: 8) {
                Image(systemName: "heart.text.square.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(PulseColor.secondaryAccent)

                Text("¡\(partnerName) quiere conectarse contigo!")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(PulseColor.textPrimary)
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: 12) {
                Button {
                    haptic(.medium)
                    Task { await store.acceptIncomingRequest() }
                } label: {
                    Text("Aceptar")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                }
                .background(PulseColor.success)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                Button {
                    haptic(.light)
                    Task { await store.rejectIncomingRequest() }
                } label: {
                    Text("Rechazar")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                }
                .background(PulseColor.backgroundElevated)
                .foregroundStyle(PulseColor.textMuted)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .disabled(store.isBusy)
            .opacity(store.isBusy ? 0.6 : 1)
        }
        .padding(20)
        .background(PulseColor.backgroundSurface)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(PulseColor.secondaryAccent.opacity(0.5), lineWidth: 1.5)
        )
    }

    private func haptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }
}

#Preview {
    ZStack {
        PulseColor.backgroundBase.ignoresSafeArea()
        PendingIncomingBanner(partnerName: "Joaquín")
            .padding(20)
    }
    .environmentObject(PairingStore())
    .preferredColorScheme(.dark)
}
