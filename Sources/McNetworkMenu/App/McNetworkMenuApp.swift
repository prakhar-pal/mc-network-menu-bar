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
            NetworkInterfaceIcon(
                primary: model.primaryInterface,
                usesIntrinsicLANImage: true
            )
                .font(.system(size: 15, weight: .medium))
                .frame(width: 18, height: 16)
                .accessibilityLabel(model.primaryInterface.accessibilityLabel)
        }
        .menuBarExtraStyle(.window)
    }
}
