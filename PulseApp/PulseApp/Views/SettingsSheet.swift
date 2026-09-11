import SwiftUI

/// Modal sheet with the user's own code, a push-notification toggle, and the
/// unpair/disconnect action.
struct SettingsSheet: View {
    @EnvironmentObject private var store: PairingStore
    @Environment(\.dismiss) private var dismiss

    @State private var pushEnabled = PulseSharedStore.pushNotificationsEnabled
    @State private var showDisconnectConfirm = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Text("Tu código")
                            .foregroundStyle(PulseColor.textPrimary)
                        Spacer()
                        Text(store.session?.connectionCode ?? "------")
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(PulseColor.textMuted)
                    }
                } header: {
                    Text("Cuenta")
                }
                .listRowBackground(PulseColor.backgroundSurface)

                Section {
                    Toggle(isOn: $pushEnabled) {
                        Text("Notificaciones push")
                            .foregroundStyle(PulseColor.textPrimary)
                    }
                    .tint(PulseColor.primaryAccent)
                    .onChange(of: pushEnabled) { _, newValue in
                        Task {
                            if newValue {
                                let granted = await PulseNotificationService.shared.requestAuthorization()
                                pushEnabled = granted
                            } else {
                                PulseSharedStore.pushNotificationsEnabled = false
                            }
                        }
                    }
                } header: {
                    Text("Notificaciones")
                }
                .listRowBackground(PulseColor.backgroundSurface)

                if store.connectionState.isConnected {
                    Section {
                        Button(role: .destructive) {
                            showDisconnectConfirm = true
                        } label: {
                            Text("Desconectar")
                                .foregroundStyle(PulseColor.danger)
                        }
                    }
                    .listRowBackground(PulseColor.backgroundSurface)
                }
            }
            .scrollContentBackground(.hidden)
            .background(PulseColor.backgroundBase.ignoresSafeArea())
            .navigationTitle("Ajustes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Listo") { dismiss() }
                }
            }
            .confirmationDialog(
                "¿Desconectar de tu pareja?",
                isPresented: $showDisconnectConfirm,
                titleVisibility: .visible
            ) {
                Button("Desconectar", role: .destructive) {
                    Task {
                        await store.disconnect()
                        dismiss()
                    }
                }
                Button("Cancelar", role: .cancel) {}
            }
        }
        .preferredColorScheme(.dark)
    }
}

#Preview {
    SettingsSheet()
        .environmentObject(PairingStore())
}
