import SwiftUI
import McNetworkMenuCore

struct MenuPanelView: View {
    @ObservedObject var model: NetworkMenuModel

    var body: some View {
        VStack(spacing: 0) {
            PrimaryConnectionView(primary: model.primaryInterface)
                .padding(16)

            Divider()

            wifiContent

            Divider()

            FooterView(model: model)
        }
        .frame(width: 360)
        .frame(maxHeight: 620)
        .onAppear {
            Task { await model.panelOpened() }
        }
        .sheet(item: passwordPromptBinding) { prompt in
            PasswordPromptView(
                network: prompt.network,
                onJoin: { password in await model.connectPromptedNetwork(password: password) },
                onCancel: model.dismissPasswordPrompt
            )
        }
    }

    private var wifiContent: some View {
        VStack(spacing: 10) {
            HStack {
                Text("Wi-Fi").font(.headline)
                Spacer()
                Button {
                    Task { await model.refresh() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Refresh Wi-Fi networks")
                .disabled(!model.wifiStatus.isPoweredOn)

                Toggle("Wi-Fi", isOn: Binding(
                    get: { model.wifiStatus.isPoweredOn },
                    set: { value in Task { await model.setWiFiEnabled(value) } }
                ))
                .labelsHidden()
            }

            if let progress = model.operation.progressLabel {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text(progress).foregroundStyle(.secondary)
                    Spacer()
                }
            }

            if let error = model.operation.displayMessage {
                Text(error)
                    .font(.callout)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if model.locationPermission == .denied || model.locationPermission == .restricted {
                Text("Allow Location access in System Settings to show nearby network names.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if model.sections.isEmpty && model.wifiStatus.isPoweredOn && model.operation.progressLabel == nil {
                Text("No Wi-Fi networks found")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ScrollView {
                    WiFiNetworkListView(sections: model.sections, onSelect: model.select)
                }
                .frame(maxHeight: 310)
            }
        }
        .padding(16)
    }

    private var passwordPromptBinding: Binding<WiFiPasswordPrompt?> {
        Binding(
            get: { model.passwordPrompt },
            set: { if $0 == nil { model.dismissPasswordPrompt() } }
        )
    }
}
