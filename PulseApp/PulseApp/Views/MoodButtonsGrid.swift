import SwiftUI

/// Three interactive mood cards, visible only while connected. Tapping one
/// triggers a medium haptic, writes the mood to shared storage immediately,
/// reloads widget timelines, and dispatches `POST /status` in the background
/// — all handled by `PairingStore.setMyMood`.
struct MoodButtonsGrid: View {
    @EnvironmentObject private var store: PairingStore

    var body: some View {
        HStack(spacing: 12) {
            ForEach(PulseMood.allCases, id: \.self) { mood in
                MoodCard(mood: mood, isSelected: store.myMood == mood) {
                    store.setMyMood(mood)
                }
            }
        }
    }
}

private struct MoodCard: View {
    let mood: PulseMood
    let isSelected: Bool
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                Image(systemName: mood.systemImageName)
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(isSelected ? mood.tintColor : PulseColor.textMuted)

                Text(mood.displayName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(isSelected ? PulseColor.textPrimary : PulseColor.textMuted)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(isSelected ? mood.tintColor.opacity(0.14) : PulseColor.backgroundSurface)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isSelected ? mood.tintColor : PulseColor.border, lineWidth: isSelected ? 1.5 : 1)
            )
            .scaleEffect(isPressed ? 0.94 : 1.0)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: isPressed)
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: isSelected)
    }
}

#Preview {
    ZStack {
        PulseColor.backgroundBase.ignoresSafeArea()
        MoodButtonsGrid()
            .padding(20)
    }
    .environmentObject(PairingStore())
    .preferredColorScheme(.dark)
}
