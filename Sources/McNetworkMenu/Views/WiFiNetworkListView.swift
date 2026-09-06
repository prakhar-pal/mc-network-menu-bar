import SwiftUI
import McNetworkMenuCore

struct WiFiNetworkListView: View {
    let sections: [WiFiNetworkSection]
    let onSelect: (WiFiNetwork) -> Void

    var body: some View {
        LazyVStack(spacing: 4) {
            ForEach(WiFiNetworkPresentation.flattenedNetworks(from: sections)) { network in
                NetworkRowView(network: network) { onSelect(network) }
            }
        }
    }
}
