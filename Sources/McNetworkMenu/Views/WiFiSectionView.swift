import SwiftUI
import McNetworkMenuCore

struct WiFiSectionView: View {
    let section: WiFiNetworkSection
    let onSelect: (WiFiNetwork) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(section.kind.title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .padding(.horizontal, 4)

            ForEach(section.networks) { network in
                NetworkRowView(network: network) { onSelect(network) }
            }
        }
    }
}
