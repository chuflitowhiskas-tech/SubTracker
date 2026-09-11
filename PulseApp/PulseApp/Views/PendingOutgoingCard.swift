import SwiftUI

/// Shown when `ConnectionState == .pendingOutgoing`: a pulsing spinner plus
/// copy indicating the request awaits the partner's confirmation.
struct PendingOutgoingCard: View {
    let partnerCode: String
    @State private var isPulsing = false

    var body: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .stroke(PulseColor.primaryAccent.opacity(0.25), lineWidth: 3)
                    .frame(width: 64, height: 64)
                    .scaleEffect(isPulsing ? 1.35 : 1.0)
                    .opacity(isPulsing ? 0 : 1)

                Circle()
                    .stroke(PulseColor.primaryAccent, lineWidth: 3)
                    .frame(width: 64, height: 64)

                ProgressView()
                    .tint(PulseColor.primaryAccent)
            }
            .onAppear {
                withAnimation(.easeOut(duration: 1.4).repeatForever(autoreverses: false)) {
                    isPulsing = true
                }
            }

            VStack(spacing: 6) {
                Text("Solicitud enviada a tu pareja")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(PulseColor.textPrimary)

                Text("Esperando confirmación...")
                    .font(.system(size: 14))
                    .foregroundStyle(PulseColor.textMuted)
            }
            .multilineTextAlignment(.center)
        }
        .padding(.vertical, 36)
        .frame(maxWidth: .infinity)
        .background(PulseColor.backgroundSurface)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(PulseColor.border, lineWidth: 1)
        )
    }
}

#Preview {
    ZStack {
        PulseColor.backgroundBase.ignoresSafeArea()
        PendingOutgoingCard(partnerCode: "AB12CD")
            .padding(20)
    }
    .preferredColorScheme(.dark)
}
