public enum NetworkInterfaceKind: Equatable, Sendable {
    case wifi
    case ethernet
    case other
}

public struct PathInterface: Equatable, Sendable {
    public let name: String
    public let kind: NetworkInterfaceKind
    public let ipv4Address: String?

    public init(name: String, kind: NetworkInterfaceKind, ipv4Address: String?) {
        self.name = name
        self.kind = kind
        self.ipv4Address = ipv4Address
    }
}

public struct NetworkPathSnapshot: Equatable, Sendable {
    public let isSatisfied: Bool
    public let interfaces: [PathInterface]

    public init(isSatisfied: Bool, interfaces: [PathInterface]) {
        self.isSatisfied = isSatisfied
        self.interfaces = interfaces
    }
}

public enum PrimaryInterfaceResolver {
    public static func resolve(_ snapshot: NetworkPathSnapshot) -> PrimaryInterface {
        guard snapshot.isSatisfied else {
            return .offline
        }

        for interface in snapshot.interfaces {
            switch interface.kind {
            case .wifi:
                return .wifi(
                    interfaceName: interface.name,
                    ssid: nil,
                    ipv4Address: interface.ipv4Address
                )
            case .ethernet:
                return .ethernet(
                    name: interface.name,
                    ipv4Address: interface.ipv4Address
                )
            case .other:
                continue
            }
        }

        return .offline
    }
}
