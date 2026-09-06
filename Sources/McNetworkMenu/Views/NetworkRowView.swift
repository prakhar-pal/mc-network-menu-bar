import SwiftUI
import McNetworkMenuCore

struct NetworkRowView: View {
    let network: WiFiNetwork
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(network.ssid)
                    .lineLimit(1)
                    .layoutPriority(1)

                if network.isConnected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.accentColor)
                        .accessibilityHidden(true)
                }

                Spacer(minLength: 12)

                if network.isSecure {
                    Image(systemName: "lock.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 16)
                        .accessibilityLabel("Secured")
                } else {
                    Color.clear
                        .frame(width: 16, height: 1)
                    .accessibilityHidden(true)
                }

                Image(systemName: signalSymbol)
                    .foregroundStyle(.secondary)
                    .frame(width: 24)
                    .accessibilityLabel("Signal level \(network.signalLevel) of 4")
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityValue(network.isConnected ? "Connected" : "")
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
