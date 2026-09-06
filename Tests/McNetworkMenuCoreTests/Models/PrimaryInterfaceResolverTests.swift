import Testing
@testable import McNetworkMenuCore

@Suite("Primary interface resolver")
struct PrimaryInterfaceResolverTests {
    @Test("Ethernet is primary when it is first on a satisfied path")
    func ethernetWinsWhenFirst() {
        let snapshot = NetworkPathSnapshot(
            isSatisfied: true,
            interfaces: [
                PathInterface(name: "en7", kind: .ethernet, ipv4Address: "192.168.1.24"),
                PathInterface(name: "en0", kind: .wifi, ipv4Address: "192.168.1.25")
            ]
        )

        #expect(
            PrimaryInterfaceResolver.resolve(snapshot)
                == .ethernet(name: "en7", ipv4Address: "192.168.1.24")
        )
    }

    @Test("Wi-Fi is primary when it is first on a satisfied path")
    func wifiWinsWhenFirst() {
        let snapshot = NetworkPathSnapshot(
            isSatisfied: true,
            interfaces: [
                PathInterface(name: "en0", kind: .wifi, ipv4Address: "10.0.0.8"),
                PathInterface(name: "en7", kind: .ethernet, ipv4Address: "10.0.0.9")
            ]
        )

        #expect(
            PrimaryInterfaceResolver.resolve(snapshot)
                == .wifi(interfaceName: "en0", ssid: nil, ipv4Address: "10.0.0.8")
        )
    }

    @Test("Unsatisfied and unsupported paths are offline", arguments: [
        NetworkPathSnapshot(isSatisfied: false, interfaces: []),
        NetworkPathSnapshot(
            isSatisfied: true,
            interfaces: [PathInterface(name: "utun0", kind: .other, ipv4Address: nil)]
        )
    ])
    func unavailablePathsAreOffline(snapshot: NetworkPathSnapshot) {
        #expect(PrimaryInterfaceResolver.resolve(snapshot) == .offline)
    }

    @Test("Symbols and accessibility labels match interface state")
    func presentationMatchesInterfaceState() {
        let wifi = PrimaryInterface.wifi(interfaceName: "en0", ssid: "Home", ipv4Address: nil)
        let ethernet = PrimaryInterface.ethernet(name: "en7", ipv4Address: nil)

        #expect(wifi.symbolName == "wifi")
        #expect(ethernet.symbolName == "point.3.connected.trianglepath.dotted")
        #expect(PrimaryInterface.offline.symbolName == "network.slash")
        #expect(wifi.accessibilityLabel == "Wi-Fi is the primary network")
        #expect(ethernet.accessibilityLabel == "Ethernet is the primary network")
        #expect(PrimaryInterface.offline.accessibilityLabel == "No network connection")
    }
}
