public enum PrimaryInterfaceIconKind: Equatable, Sendable {
    case system(String)
    case ethernet
}

public enum PrimaryInterface: Equatable, Sendable {
    case wifi(interfaceName: String, ssid: String?, ipv4Address: String?)
    case ethernet(name: String, ipv4Address: String?)
    case offline

    public var iconKind: PrimaryInterfaceIconKind {
        switch self {
        case .wifi:
            return .system("wifi")
        case .ethernet:
            return .ethernet
        case .offline:
            return .system("network.slash")
        }
    }

    public var accessibilityLabel: String {
        switch self {
        case .wifi:
            return "Wi-Fi is the primary network"
        case .ethernet:
            return "Ethernet is the primary network"
        case .offline:
            return "No network connection"
        }
    }
}
