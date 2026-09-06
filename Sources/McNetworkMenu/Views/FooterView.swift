import SwiftUI
import McNetworkMenuCore

struct FooterView: View {
    @ObservedObject var model: NetworkMenuModel

    var body: some View {
        VStack(spacing: 2) {
            footerButton("Network Settings…", symbol: "gear") { model.openNetworkSettings() }

            HStack(spacing: 8) {
                footerIcon("power")
                Text("Launch at Login")
                Spacer()
                Toggle("Launch at Login", isOn: Binding(
                    get: { model.launchAtLoginStatus == .enabled },
                    set: { value in Task { await model.setLaunchAtLogin(value) } }
                ))
                .labelsHidden()
                .toggleStyle(.switch)
                .accessibilityLabel("Launch at Login")
            }
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
            HStack(spacing: 8) {
                footerIcon(symbol)
                Text(title)
                Spacer()
            }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .padding(.horizontal, 4)
                .padding(.vertical, 5)
        }
        .buttonStyle(.plain)
    }

    private func footerIcon(_ symbol: String) -> some View {
        Image(systemName: symbol)
            .frame(width: 24, alignment: .center)
            .accessibilityHidden(true)
    }
}
