import SwiftUI

@main
struct McNetworkMenuApp: App {
    var body: some Scene {
        MenuBarExtra("McNetworkMenu", systemImage: "network.slash") {
            MenuPanelView()
        }
        .menuBarExtraStyle(.window)
    }
}
