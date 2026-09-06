import SwiftUI
import McNetworkMenuCore

struct NetworkRowView: View {
    let network: WiFiNetwork
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: network.isConnected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(network.isConnected ? Color.accentColor : Color.clear)
                    .accessibilityHidden(true)
                Text(network.ssid).lineLimit(1)
                Spacer()
                if network.isSecure {
                    Image(systemName: "lock.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("Secured")
                }
                Image(systemName: signalSymbol)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Signal level \(network.signalLevel) of 4")
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var signalSymbol: String {
        switch network.signalLevel {
        case 4: return "wifi"
        case 3: return "wifi"
        case 2: return "wifi.exclamationmark"
        default: return "wifi.slash"
        }
    }
}
