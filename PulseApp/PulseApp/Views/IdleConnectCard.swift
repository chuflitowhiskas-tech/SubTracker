import SwiftUI
import UIKit

/// Shown when `ConnectionState == .idle`: the user's own 6-character code
/// with a one-tap copy button, plus a field to paste their partner's code.
struct IdleConnectCard: View {
    @EnvironmentObject private var store: PairingStore
    @State private var partnerCodeInput = ""
    @State private var didCopy = false
    @FocusState private var codeFieldFocused: Bool

    private var myCode: String { store.session?.connectionCode ?? "------" }

    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 10) {
                Text("TU CÓDIGO")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(2)
                    .foregroundStyle(PulseColor.textMuted)

                HStack(spacing: 12) {
                    Text(myCode)
                        .font(.system(size: 30, weight: .bold, design: .monospaced))
                        .tracking(4)
                        .foregroundStyle(PulseColor.textPrimary)

                    Button {
                        copyCode()
                    } label: {
                        Image(systemName: didCopy ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(didCopy ? PulseColor.success : PulseColor.primaryAccent)
                            .padding(10)
                            .background(PulseColor.backgroundElevated)
                            .clipShape(Circle())
                    }
                    .animation(.spring(response: 0.35, dampingFraction: 0.75), value: didCopy)
                }
            }
            .padding(.vertical, 22)
            .frame(maxWidth: .infinity)
            .background(PulseColor.backgroundSurface)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(PulseColor.border, lineWidth: 1)
            )

            VStack(spacing: 12) {
                TextField(
                    "",
                    text: $partnerCodeInput,
                    prompt: Text("Código de tu pareja").foregroundStyle(PulseColor.textMuted)
                )
                .focused($codeFieldFocused)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .font(.system(size: 17, weight: .semibold, design: .monospaced))
                .foregroundStyle(PulseColor.textPrimary)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(PulseColor.backgroundSurface)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(PulseColor.border, lineWidth: 1)
                )
                .onChange(of: partnerCodeInput) { _, newValue in
                    partnerCodeInput = String(newValue.uppercased().prefix(6))
                }

                Button {
                    codeFieldFocused = false
                    Task { await store.requestConnection(code: partnerCodeInput) }
                } label: {
                    Group {
                        if store.isBusy {
                            ProgressView().tint(.white)
                        } else {
                            Text("Conectar")
                                .font(.system(size: 16, weight: .semibold))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                }
                .background(canConnect ? PulseColor.primaryAccent : PulseColor.borderStrong)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .disabled(!canConnect || store.isBusy)
                .animation(.spring(response: 0.35, dampingFraction: 0.75), value: canConnect)
            }
        }
    }

    private var canConnect: Bool { partnerCodeInput.count == 6 }

    private func copyCode() {
        UIPasteboard.general.string = myCode
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        didCopy = true
        Task {
            try? await Task.sleep(for: .seconds(1.6))
            didCopy = false
        }
    }
}

#Preview {
    ZStack {
        PulseColor.backgroundBase.ignoresSafeArea()
        IdleConnectCard()
            .padding(20)
    }
    .environmentObject(PairingStore())
    .preferredColorScheme(.dark)
}
