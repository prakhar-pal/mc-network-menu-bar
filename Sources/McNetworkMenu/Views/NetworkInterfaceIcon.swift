import SwiftUI
import McNetworkMenuCore

struct NetworkInterfaceIcon: View {
    let primary: PrimaryInterface

    var body: some View {
        Image(systemName: primary.symbolName)
    }
}
