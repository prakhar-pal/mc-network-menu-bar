import SwiftUI
import McNetworkMenuCore

@main
struct McNetworkMenuApp: App {
    @StateObject private var model: NetworkMenuModel

    init() {
        _model = StateObject(wrappedValue: NetworkMenuModel(
            pathMonitor: AppleNetworkPathMonitor(),
            wifi: CoreWLANController(),
            location: AppleLocationAuthorizer(),
            launchAtLogin: AppleLaunchAtLoginController(),
            systemActions: AppleSystemActions()
        ))
    }

    var body: some Scene {
        MenuBarExtra {
            MenuPanelView(model: model)
        } label: {
            Image(systemName: model.primaryInterface.symbolName)
                .accessibilityLabel(model.primaryInterface.accessibilityLabel)
        }
        .menuBarExtraStyle(.window)
    }
}
