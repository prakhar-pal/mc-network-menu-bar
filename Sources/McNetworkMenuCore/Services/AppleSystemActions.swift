import AppKit
import Foundation

/// URLs for the small set of System Settings destinations McNetworkMenu opens.
///
/// The Network extension identifier is an undocumented macOS 14+ destination.
/// Keep this mapping narrow: it exists because launching System Settings through
/// public APIs cannot select the Network pane.
enum SystemSettingsURL {
    private static let network = URL(
        string: "x-apple.systempreferences:com.apple.Network-Settings.extension"
    )!

    static func url(for destination: SystemSettingsDestination) -> URL {
        switch destination {
        case .network:
            network
        }
    }
}

@MainActor
public final class AppleSystemActions: SystemActions {
    public init() {}

    public func openSettings(_ destination: SystemSettingsDestination) {
        NSWorkspace.shared.open(SystemSettingsURL.url(for: destination))
    }

    public func showAbout() {
        NSApplication.shared.orderFrontStandardAboutPanel(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    public func quit() {
        NSApplication.shared.terminate(nil)
    }
}
