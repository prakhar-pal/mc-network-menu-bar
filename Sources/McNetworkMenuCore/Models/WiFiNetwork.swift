import Foundation

public struct WiFiNetwork: Identifiable, Equatable, Sendable {
    public let ssid: String
    public let bssid: String?
    public let rssi: Int
    public let isSecure: Bool
    public let isKnown: Bool
    public let isConnected: Bool

    public init(
        ssid: String,
        bssid: String?,
        rssi: Int,
        isSecure: Bool,
        isKnown: Bool = false,
        isConnected: Bool = false
    ) {
        self.ssid = ssid
        self.bssid = bssid
        self.rssi = rssi
        self.isSecure = isSecure
        self.isKnown = isKnown
        self.isConnected = isConnected
    }

    public var id: String {
        if let bssid, !bssid.isEmpty {
            return "bssid:\(bssid.lowercased())"
        }
        return "ssid:\(ssid.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current))"
    }

    public var signalLevel: Int {
        if rssi >= -50 { return 4 }
        if rssi >= -65 { return 3 }
        if rssi >= -80 { return 2 }
        return 1
    }
}

public enum WiFiSectionKind: String, CaseIterable, Equatable, Sendable {
    case connected = "Connected"
    case known = "Known Networks"
    case nearby = "Other Networks"

    public var title: String { rawValue }
}

public struct WiFiNetworkSection: Identifiable, Equatable, Sendable {
    public let kind: WiFiSectionKind
    public let networks: [WiFiNetwork]

    public init(kind: WiFiSectionKind, networks: [WiFiNetwork]) {
        self.kind = kind
        self.networks = networks
    }

    public var id: WiFiSectionKind { kind }
}

public enum WiFiNetworkPresentation {
    public static func sections(from networks: [WiFiNetwork]) -> [WiFiNetworkSection] {
        let visible = networks.filter { !$0.ssid.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        var deduplicated: [String: WiFiNetwork] = [:]

        for network in visible {
            guard let current = deduplicated[network.id] else {
                deduplicated[network.id] = network
                continue
            }

            let strongest = network.rssi > current.rssi ? network : current
            deduplicated[network.id] = WiFiNetwork(
                ssid: strongest.ssid,
                bssid: strongest.bssid,
                rssi: strongest.rssi,
                isSecure: current.isSecure || network.isSecure,
                isKnown: current.isKnown || network.isKnown,
                isConnected: current.isConnected || network.isConnected
            )
        }

        let sorted = deduplicated.values.sorted {
            if $0.rssi != $1.rssi { return $0.rssi > $1.rssi }
            return $0.ssid.localizedCaseInsensitiveCompare($1.ssid) == .orderedAscending
        }

        return WiFiSectionKind.allCases.compactMap { kind in
            let matches = sorted.filter { network in
                switch kind {
                case .connected: return network.isConnected
                case .known: return !network.isConnected && network.isKnown
                case .nearby: return !network.isConnected && !network.isKnown
                }
            }
            return matches.isEmpty ? nil : WiFiNetworkSection(kind: kind, networks: matches)
        }
    }
}
