import SwiftUI
import McNetworkMenuCore

struct FooterView: View {
    @ObservedObject var model: NetworkMenuModel

    var body: some View {
        VStack(spacing: 2) {
            footerButton("Network Settings…", symbol: "gear") { model.openNetworkSettings() }

            Toggle(isOn: Binding(
                get: { model.launchAtLoginStatus == .enabled },
                set: { value in Task { await model.setLaunchAtLogin(value) } }
            )) {
                Label("Launch at Login", systemImage: "power")
            }
            .toggleStyle(.switch)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 4)
            .padding(.vertical, 5)

            if model.launchAtLoginStatus == .requiresApproval {
                Text("Approval is required in Login Items settings.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 10)
            }

            footerButton("About McNetworkMenu", symbol: "info.circle") { model.showAbout() }
            footerButton("Quit McNetworkMenu", symbol: "xmark.circle") { model.quit() }
        }
        .padding(8)
    }

    private func footerButton(_ title: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .padding(.horizontal, 4)
                .padding(.vertical, 5)
        }
        .buttonStyle(.plain)
    }
}
