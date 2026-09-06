public enum PrimaryInterface: Equatable, Sendable {
    case wifi(interfaceName: String, ssid: String?, ipv4Address: String?)
    case ethernet(name: String, ipv4Address: String?)
    case offline

    public var symbolName: String {
        switch self {
        case .wifi:
            return "wifi"
        case .ethernet:
            return "network"
        case .offline:
            return "network.slash"
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
