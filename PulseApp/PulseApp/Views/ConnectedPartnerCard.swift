import SwiftUI
import Combine

/// Shown when `ConnectionState == .connected`: partner's large mood icon,
/// mood name, and a relative "hace Xm" timestamp that ticks live.
struct ConnectedPartnerCard: View {
    @EnvironmentObject private var store: PairingStore
    @State private var now = Date()

    private let ticker = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    private var partner: PartnerState? { store.partnerState }

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill((partner?.mood ?? .good).tintColor.opacity(0.16))
                    .frame(width: 108, height: 108)

                Image(systemName: (partner?.mood ?? .good).systemImageName)
                    .font(.system(size: 46, weight: .semibold))
                    .foregroundStyle((partner?.mood ?? .good).tintColor)
            }

            VStack(spacing: 4) {
                Text(partner?.mood.displayName ?? "Sin datos")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(PulseColor.textPrimary)

                if let partner {
                    Text(partner.relativeUpdatedAtLabel)
                        .font(.system(size: 13))
                        .foregroundStyle(PulseColor.textMuted)
                        .id(now)
                }
            }
        }
        .padding(.vertical, 28)
        .frame(maxWidth: .infinity)
        .background(PulseColor.backgroundSurface)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(PulseColor.border, lineWidth: 1)
        )
        .onReceive(ticker) { now = $0 }
    }
}

#Preview {
    ZStack {
        PulseColor.backgroundBase.ignoresSafeArea()
        ConnectedPartnerCard()
            .padding(20)
    }
    .environmentObject(PairingStore())
    .preferredColorScheme(.dark)
}
