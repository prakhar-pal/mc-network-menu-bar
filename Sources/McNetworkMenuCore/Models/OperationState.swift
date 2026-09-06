public struct DisplayError: Error, Equatable, Sendable {
    public let message: String

    public init(_ message: String) {
        self.message = message
    }
}

public enum NetworkOperationState: Equatable, Sendable {
    case idle
    case scanning
    case connecting(networkID: String)
    case disconnecting
    case changingPower
    case failed(DisplayError)

    public var displayMessage: String? {
        guard case let .failed(error) = self else { return nil }
        return error.message
    }

    public var progressLabel: String? {
        switch self {
        case .scanning: return "Looking for networks…"
        case .connecting: return "Joining network…"
        case .disconnecting: return "Disconnecting…"
        case .changingPower: return "Changing Wi-Fi power…"
        case .idle, .failed: return nil
        }
    }
}

public enum LocationPermissionState: Equatable, Sendable {
    case notDetermined
    case requesting
    case authorized
    case denied
    case restricted
}

public struct WiFiStatus: Equatable, Sendable {
    public let isPoweredOn: Bool
    public let connectedSSID: String?
    public let rssi: Int?

    public init(isPoweredOn: Bool, connectedSSID: String?, rssi: Int?) {
        self.isPoweredOn = isPoweredOn
        self.connectedSSID = connectedSSID
        self.rssi = rssi
    }
}
