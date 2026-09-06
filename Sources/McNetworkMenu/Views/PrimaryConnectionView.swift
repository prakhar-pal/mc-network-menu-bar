import SwiftUI
import McNetworkMenuCore

struct PrimaryConnectionView: View {
    let primary: PrimaryInterface

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: primary.symbolName)
                .font(.system(size: 24, weight: .medium))
                .frame(width: 34)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.headline)
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Circle()
                .fill(isOnline ? Color.green : Color.secondary)
                .frame(width: 8, height: 8)
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(primary.accessibilityLabel)
    }

    private var title: String {
        switch primary {
        case let .wifi(_, ssid, _): return ssid ?? "Wi-Fi"
        case .ethernet: return "Ethernet"
        case .offline: return "Offline"
        }
    }

    private var detail: String {
        switch primary {
        case let .wifi(interface, _, address): return ["Primary", interface, address].compactMap { $0 }.joined(separator: " · ")
        case let .ethernet(name, address): return ["Primary", name, address].compactMap { $0 }.joined(separator: " · ")
        case .offline: return "No active network route"
        }
    }

    private var isOnline: Bool { primary != .offline }
}
