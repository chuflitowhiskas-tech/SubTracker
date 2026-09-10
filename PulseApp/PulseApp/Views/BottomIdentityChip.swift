import SwiftUI

/// Pill card pinned near the bottom of `MainView` showing the current
/// user's avatar initial and name, e.g. "TÚ · Joaquín".
struct BottomIdentityChip: View {
    @EnvironmentObject private var store: PairingStore

    private var displayName: String { store.session?.displayName ?? "Invitado" }
    private var initial: String { String(displayName.prefix(1)).uppercased() }

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(PulseColor.primaryAccent.opacity(0.2))
                    .frame(width: 30, height: 30)

                Text(initial)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(PulseColor.primaryAccent)
            }

            Text("TÚ · \(displayName)")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(PulseColor.textPrimary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(PulseColor.backgroundSurface)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(PulseColor.border, lineWidth: 1))
    }
}

#Preview {
    ZStack {
        PulseColor.backgroundBase.ignoresSafeArea()
        BottomIdentityChip()
    }
    .environmentObject(PairingStore())
    .preferredColorScheme(.dark)
}
