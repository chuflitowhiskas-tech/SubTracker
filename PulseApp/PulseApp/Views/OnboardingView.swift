import SwiftUI

/// Minimal guest-auth onboarding: asks for a display name and calls
/// `POST /auth/guest` through `PairingStore.signInAsGuest`.
struct OnboardingView: View {
    @EnvironmentObject private var store: PairingStore
    @State private var displayName = ""
    @FocusState private var nameFieldFocused: Bool

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            VStack(spacing: 10) {
                Image(systemName: "waveform.path.ecg")
                    .font(.system(size: 44, weight: .semibold))
                    .foregroundStyle(PulseColor.primaryAccent)

                Text("PULSE")
                    .font(.system(size: 14, weight: .bold))
                    .tracking(3)
                    .foregroundStyle(PulseColor.textMuted)

                Text("Conecta con tu pareja\nen tiempo real")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(PulseColor.textPrimary)
            }

            VStack(spacing: 14) {
                TextField("", text: $displayName, prompt: Text("Tu nombre").foregroundStyle(PulseColor.textMuted))
                    .focused($nameFieldFocused)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .foregroundStyle(PulseColor.textPrimary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(PulseColor.backgroundSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(PulseColor.border, lineWidth: 1)
                    )

                Button {
                    nameFieldFocused = false
                    Task { await store.signInAsGuest(displayName: trimmedName) }
                } label: {
                    Group {
                        if store.isBusy {
                            ProgressView().tint(.white)
                        } else {
                            Text("Comenzar")
                                .font(.system(size: 16, weight: .semibold))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                }
                .background(trimmedName.isEmpty ? PulseColor.borderStrong : PulseColor.primaryAccent)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .disabled(trimmedName.isEmpty || store.isBusy)
                .animation(.spring(response: 0.35, dampingFraction: 0.75), value: trimmedName.isEmpty)
            }
            .padding(.horizontal, 28)

            if let error = store.lastErrorMessage {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(PulseColor.danger)
                    .padding(.horizontal, 28)
                    .multilineTextAlignment(.center)
            }

            Spacer()
            Spacer()
        }
    }

    private var trimmedName: String {
        displayName.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

#Preview {
    ZStack {
        PulseColor.backgroundBase.ignoresSafeArea()
        OnboardingView()
    }
    .environmentObject(PairingStore())
    .preferredColorScheme(.dark)
}
