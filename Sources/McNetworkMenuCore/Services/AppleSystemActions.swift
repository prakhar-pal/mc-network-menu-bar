import AppKit
import Foundation

@MainActor
public final class AppleSystemActions: SystemActions {
    public init() {}

    public func openSettings(_ destination: SystemSettingsDestination) {
        guard let settingsURL = NSWorkspace.shared.urlForApplication(
            withBundleIdentifier: "com.apple.systempreferences"
        ) else { return }
        NSWorkspace.shared.openApplication(at: settingsURL, configuration: .init())
    }

    public func showAbout() {
        NSApplication.shared.orderFrontStandardAboutPanel(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    public func quit() {
        NSApplication.shared.terminate(nil)
    }
}
