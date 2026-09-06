import Darwin
import Foundation
import Network

public enum InterfaceAddressFamily: Equatable, Sendable {
    case ipv4
    case ipv6
}

public struct InterfaceAddressRecord: Equatable, Sendable {
    public let interfaceName: String
    public let family: InterfaceAddressFamily
    public let address: String

    public init(interfaceName: String, family: InterfaceAddressFamily, address: String) {
        self.interfaceName = interfaceName
        self.family = family
        self.address = address
    }
}

public enum IPv4AddressLookup {
    public static func address(for interfaceName: String, in records: [InterfaceAddressRecord]) -> String? {
        records.first { $0.interfaceName == interfaceName && $0.family == .ipv4 }?.address
    }

    static func systemRecords() -> [InterfaceAddressRecord] {
        var head: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&head) == 0, let first = head else { return [] }
        defer { freeifaddrs(head) }

        return sequence(first: first, next: { $0.pointee.ifa_next }).compactMap { pointer in
            guard let socketAddress = pointer.pointee.ifa_addr else { return nil }
            let familyValue = Int32(socketAddress.pointee.sa_family)
            let family: InterfaceAddressFamily
            let length: socklen_t

            switch familyValue {
            case AF_INET:
                family = .ipv4
                length = socklen_t(MemoryLayout<sockaddr_in>.size)
            case AF_INET6:
                family = .ipv6
                length = socklen_t(MemoryLayout<sockaddr_in6>.size)
            default:
                return nil
            }

            var buffer = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            guard getnameinfo(socketAddress, length, &buffer, socklen_t(buffer.count), nil, 0, NI_NUMERICHOST) == 0 else {
                return nil
            }
            return InterfaceAddressRecord(
                interfaceName: String(cString: pointer.pointee.ifa_name),
                family: family,
                address: String(cString: buffer)
            )
        }
    }
}

public final class AppleNetworkPathMonitor: NetworkPathMonitoring, @unchecked Sendable {
    public let snapshots: AsyncStream<NetworkPathSnapshot>

    private let monitor: NWPathMonitor
    private let queue = DispatchQueue(label: "com.prakharpal.McNetworkMenu.path-monitor")
    private let continuation: AsyncStream<NetworkPathSnapshot>.Continuation
    private let lock = NSLock()
    private var hasStarted = false
    private var hasStopped = false

    public init() {
        let pair = AsyncStream<NetworkPathSnapshot>.makeStream()
        snapshots = pair.stream
        continuation = pair.continuation
        monitor = NWPathMonitor()

        monitor.pathUpdateHandler = { [continuation] path in
            let addresses = IPv4AddressLookup.systemRecords()
            let interfaces = path.availableInterfaces.map { interface in
                PathInterface(
                    name: interface.name,
                    kind: Self.kind(for: interface.type),
                    ipv4Address: IPv4AddressLookup.address(for: interface.name, in: addresses)
                )
            }
            continuation.yield(NetworkPathSnapshot(status: path.status, interfaces: interfaces))
        }
    }

    public func start() {
        lock.lock()
        defer { lock.unlock() }
        guard !hasStarted, !hasStopped else { return }
        hasStarted = true
        monitor.start(queue: queue)
    }

    public func stop() {
        lock.lock()
        guard !hasStopped else {
            lock.unlock()
            return
        }
        hasStopped = true
        lock.unlock()
        monitor.cancel()
        continuation.finish()
    }

    deinit {
        monitor.cancel()
        continuation.finish()
    }

    private static func kind(for type: NWInterface.InterfaceType) -> NetworkInterfaceKind {
        switch type {
        case .wifi: return .wifi
        case .wiredEthernet: return .ethernet
        default: return .other
        }
    }
}

private extension NetworkPathSnapshot {
    init(status: NWPath.Status, interfaces: [PathInterface]) {
        self.init(isSatisfied: status == .satisfied, interfaces: interfaces)
    }
}
