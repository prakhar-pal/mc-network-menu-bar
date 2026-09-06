import Foundation

public protocol NetworkPathMonitoring: AnyObject {
    var snapshots: AsyncStream<NetworkPathSnapshot> { get }
    func start()
    func stop()
}

public protocol WiFiControlling: Sendable {
    func status() async throws -> WiFiStatus
    func scan() async throws -> [WiFiNetwork]
    func setPower(_ enabled: Bool) async throws
    func connect(to networkID: String, password: String?) async throws
    func disconnect() async throws
}

public protocol LocationAuthorizing: Sendable {
    func currentStatus() async -> LocationPermissionState
    func requestAuthorization() async -> LocationPermissionState
}

public enum LaunchAtLoginStatus: Equatable, Sendable {
    case enabled
    case requiresApproval
    case disabled
    case notFound
}

public protocol LaunchAtLoginControlling: Sendable {
    func status() async -> LaunchAtLoginStatus
    func setEnabled(_ enabled: Bool) async throws -> LaunchAtLoginStatus
}

public enum SystemSettingsDestination: Sendable {
    case network
}

@MainActor
public protocol SystemActions: AnyObject {
    func openSettings(_ destination: SystemSettingsDestination)
    func showAbout()
    func quit()
}
