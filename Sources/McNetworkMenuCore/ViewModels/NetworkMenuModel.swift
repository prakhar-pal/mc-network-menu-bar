import Combine
import Foundation

public struct WiFiPasswordPrompt: Identifiable, Equatable, Sendable {
    public let network: WiFiNetwork
    public var id: String { network.id }

    public init(network: WiFiNetwork) {
        self.network = network
    }
}

@MainActor
public final class NetworkMenuModel: ObservableObject {
    @Published public private(set) var primaryInterface: PrimaryInterface = .offline
    @Published public private(set) var wifiStatus = WiFiStatus(isPoweredOn: false, connectedSSID: nil, rssi: nil)
    @Published public private(set) var sections: [WiFiNetworkSection] = []
    @Published public private(set) var operation: NetworkOperationState = .idle
    @Published public private(set) var locationPermission: LocationPermissionState = .notDetermined
    @Published public private(set) var launchAtLoginStatus: LaunchAtLoginStatus = .disabled
    @Published public private(set) var passwordPrompt: WiFiPasswordPrompt?

    private let pathMonitor: NetworkPathMonitoring
    private let wifi: WiFiControlling
    private let location: LocationAuthorizing
    private let launchAtLogin: LaunchAtLoginControlling
    private let systemActions: SystemActions
    private var pathTask: Task<Void, Never>?
    private var latestSnapshot: NetworkPathSnapshot?
    private var scanGeneration = 0

    public init(
        pathMonitor: NetworkPathMonitoring,
        wifi: WiFiControlling,
        location: LocationAuthorizing,
        launchAtLogin: LaunchAtLoginControlling,
        systemActions: SystemActions
    ) {
        self.pathMonitor = pathMonitor
        self.wifi = wifi
        self.location = location
        self.launchAtLogin = launchAtLogin
        self.systemActions = systemActions
    }

    public func start() {
        guard pathTask == nil else { return }
        pathMonitor.start()
        let stream = pathMonitor.snapshots
        pathTask = Task { [weak self] in
            for await snapshot in stream {
                guard !Task.isCancelled else { break }
                self?.apply(snapshot)
            }
        }
    }

    public func stop() {
        pathTask?.cancel()
        pathTask = nil
        pathMonitor.stop()
    }

    public func panelOpened() async {
        launchAtLoginStatus = await launchAtLogin.status()
        do {
            wifiStatus = try await wifi.status()
            mergeConnectedSSIDIntoPrimaryRoute()
            if wifiStatus.isPoweredOn { await refresh() }
        } catch {
            operation = .failed(displayError(error, fallback: "Wi-Fi status is unavailable."))
        }
    }

    public func refresh() async {
        scanGeneration += 1
        let generation = scanGeneration
        operation = .scanning

        var permission = await location.currentStatus()
        locationPermission = permission
        if permission == .notDetermined {
            locationPermission = .requesting
            permission = await location.requestAuthorization()
            locationPermission = permission
        }
        guard permission == .authorized else {
            if generation == scanGeneration { operation = .idle }
            return
        }

        do {
            let networks = try await wifi.scan()
            guard generation == scanGeneration else { return }
            sections = WiFiNetworkPresentation.sections(from: networks)
            wifiStatus = try await wifi.status()
            mergeConnectedSSIDIntoPrimaryRoute()
            operation = .idle
        } catch {
            guard generation == scanGeneration else { return }
            operation = .failed(displayError(error, fallback: "Wi-Fi networks could not be refreshed."))
        }
    }

    public func select(_ network: WiFiNetwork) {
        if network.isConnected {
            Task { await disconnect() }
        } else if network.isSecure && !network.isKnown {
            passwordPrompt = WiFiPasswordPrompt(network: network)
        } else {
            Task { await connect(network, password: nil) }
        }
    }

    public func dismissPasswordPrompt() {
        passwordPrompt = nil
    }

    public func connectPromptedNetwork(password: String) async {
        guard let network = passwordPrompt?.network else { return }
        passwordPrompt = nil
        await connect(network, password: password)
    }

    public func setWiFiEnabled(_ enabled: Bool) async {
        operation = .changingPower
        do {
            try await wifi.setPower(enabled)
            wifiStatus = WiFiStatus(
                isPoweredOn: enabled,
                connectedSSID: enabled ? wifiStatus.connectedSSID : nil,
                rssi: enabled ? wifiStatus.rssi : nil
            )
            if !enabled { sections = [] }
            operation = .idle
        } catch {
            operation = .failed(displayError(error, fallback: "Wi-Fi power could not be changed."))
        }
    }

    public func disconnect() async {
        operation = .disconnecting
        do {
            try await wifi.disconnect()
            wifiStatus = WiFiStatus(isPoweredOn: wifiStatus.isPoweredOn, connectedSSID: nil, rssi: nil)
            operation = .idle
        } catch {
            operation = .failed(displayError(error, fallback: "Wi-Fi could not be disconnected."))
        }
    }

    public func setLaunchAtLogin(_ enabled: Bool) async {
        do {
            launchAtLoginStatus = try await launchAtLogin.setEnabled(enabled)
        } catch {
            operation = .failed(displayError(error, fallback: "Launch at Login could not be changed."))
        }
    }

    public func openNetworkSettings() { systemActions.openSettings(.network) }
    public func showAbout() { systemActions.showAbout() }
    public func quit() { systemActions.quit() }

    private func connect(_ network: WiFiNetwork, password: String?) async {
        operation = .connecting(networkID: network.id)
        do {
            try await wifi.connect(to: network.id, password: password)
            operation = .idle
            await refresh()
        } catch {
            operation = .failed(displayError(error, fallback: "Could not join the Wi-Fi network."))
        }
    }

    private func apply(_ snapshot: NetworkPathSnapshot) {
        latestSnapshot = snapshot
        primaryInterface = PrimaryInterfaceResolver.resolve(snapshot)
        mergeConnectedSSIDIntoPrimaryRoute()
    }

    private func mergeConnectedSSIDIntoPrimaryRoute() {
        guard case let .wifi(interfaceName, _, ipv4Address) = primaryInterface else { return }
        primaryInterface = .wifi(
            interfaceName: interfaceName,
            ssid: wifiStatus.connectedSSID,
            ipv4Address: ipv4Address
        )
    }

    private func displayError(_ error: Error, fallback: String) -> DisplayError {
        (error as? DisplayError) ?? DisplayError(fallback)
    }
}
