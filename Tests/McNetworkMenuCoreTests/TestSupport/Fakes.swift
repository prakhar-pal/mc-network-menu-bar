import Foundation
@testable import McNetworkMenuCore

final class FakePathMonitor: NetworkPathMonitoring {
    let snapshots: AsyncStream<NetworkPathSnapshot>
    private let continuation: AsyncStream<NetworkPathSnapshot>.Continuation
    private(set) var startCount = 0
    private(set) var stopCount = 0

    init() {
        let pair = AsyncStream<NetworkPathSnapshot>.makeStream()
        snapshots = pair.stream
        continuation = pair.continuation
    }

    func start() { startCount += 1 }
    func stop() { stopCount += 1; continuation.finish() }
    func send(_ snapshot: NetworkPathSnapshot) { continuation.yield(snapshot) }
}

actor FakeWiFiController: WiFiControlling {
    struct ScanPlan: Sendable {
        let delayNanoseconds: UInt64
        let result: Result<[WiFiNetwork], DisplayError>
    }
    struct ConnectCall: Equatable, Sendable {
        let networkID: String
        let hadCredential: Bool
    }

    var configuredStatus: Result<WiFiStatus, DisplayError>
    var scanPlans: [ScanPlan]
    private(set) var scanCount = 0
    private(set) var powerValues: [Bool] = []
    private(set) var connectCalls: [ConnectCall] = []
    private(set) var disconnectCount = 0
    var connectError: DisplayError?

    init(
        status: Result<WiFiStatus, DisplayError> = .success(.init(isPoweredOn: true, connectedSSID: nil, rssi: nil)),
        scanPlans: [ScanPlan] = []
    ) {
        configuredStatus = status
        self.scanPlans = scanPlans
    }

    func status() async throws -> WiFiStatus { try configuredStatus.get() }

    func scan() async throws -> [WiFiNetwork] {
        let index = scanCount
        scanCount += 1
        guard scanPlans.indices.contains(index) else { return [] }
        let plan = scanPlans[index]
        if plan.delayNanoseconds > 0 {
            try? await Task.sleep(nanoseconds: plan.delayNanoseconds)
        }
        return try plan.result.get()
    }

    func setPower(_ enabled: Bool) async throws { powerValues.append(enabled) }

    func connect(to networkID: String, password: String?) async throws {
        connectCalls.append(.init(networkID: networkID, hadCredential: !(password ?? "").isEmpty))
        if let connectError { throw connectError }
    }

    func disconnect() async throws { disconnectCount += 1 }

    func calls() -> (scans: Int, powers: [Bool], connections: [ConnectCall], disconnects: Int) {
        (scanCount, powerValues, connectCalls, disconnectCount)
    }
}

@MainActor
final class FakeLocationAuthorizer: LocationAuthorizing {
    var current: LocationPermissionState
    var requested: LocationPermissionState
    private(set) var requestCount = 0

    init(current: LocationPermissionState, requested: LocationPermissionState = .authorized) {
        self.current = current
        self.requested = requested
    }

    func currentStatus() async -> LocationPermissionState { current }
    func requestAuthorization() async -> LocationPermissionState {
        requestCount += 1
        current = requested
        return requested
    }
}

@MainActor
final class FakeLaunchAtLoginController: LaunchAtLoginControlling {
    var current: LaunchAtLoginStatus
    private(set) var values: [Bool] = []

    init(_ current: LaunchAtLoginStatus = .disabled) { self.current = current }
    func status() async -> LaunchAtLoginStatus { current }
    func setEnabled(_ enabled: Bool) async throws -> LaunchAtLoginStatus {
        values.append(enabled)
        current = enabled ? .enabled : .disabled
        return current
    }
}

@MainActor
final class FakeSystemActions: SystemActions {
    private(set) var settingsCount = 0
    private(set) var aboutCount = 0
    private(set) var quitCount = 0
    func openSettings(_ destination: SystemSettingsDestination) { settingsCount += 1 }
    func showAbout() { aboutCount += 1 }
    func quit() { quitCount += 1 }
}
