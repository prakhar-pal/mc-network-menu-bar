import Testing
@testable import McNetworkMenuCore

@Suite("Wi-Fi network presentation")
struct WiFiNetworkPresentationTests {
    @Test("Networks are deduplicated before connected, known, and nearby grouping")
    func groupingAndDeduplication() throws {
        let networks = [
            WiFiNetwork(ssid: "Cafe", bssid: "AA:BB", rssi: -75, isSecure: false),
            WiFiNetwork(ssid: "Cafe", bssid: "AA:BB", rssi: -42, isSecure: true, isKnown: true),
            WiFiNetwork(ssid: "Office", bssid: "CC:DD", rssi: -55, isSecure: true, isConnected: true),
            WiFiNetwork(ssid: "Guest", bssid: nil, rssi: -60, isSecure: false),
            WiFiNetwork(ssid: "   ", bssid: "EE:FF", rssi: -20, isSecure: true)
        ]

        let sections = WiFiNetworkPresentation.sections(from: networks)

        #expect(sections.map(\.kind) == [.connected, .known, .nearby])
        #expect(sections.map { $0.networks.map(\.ssid) } == [["Office"], ["Cafe"], ["Guest"]])
        let cafe = try #require(sections[1].networks.first)
        #expect(cafe.rssi == -42)
        #expect(cafe.isKnown)
        #expect(cafe.isSecure)
    }

    @Test("Networks sort by descending signal and then localized SSID")
    func sorting() {
        let sections = WiFiNetworkPresentation.sections(from: [
            WiFiNetwork(ssid: "Zulu", bssid: nil, rssi: -70, isSecure: true),
            WiFiNetwork(ssid: "beta", bssid: nil, rssi: -50, isSecure: false),
            WiFiNetwork(ssid: "Alpha", bssid: nil, rssi: -50, isSecure: true)
        ])

        #expect(sections.count == 1)
        #expect(sections[0].kind == .nearby)
        #expect(sections[0].networks.map(\.ssid) == ["Alpha", "beta", "Zulu"])
        #expect(sections[0].networks.map(\.isSecure) == [true, false, true])
    }

    @Test("Signal levels use stable RSSI thresholds", arguments: [
        (-45, 4), (-60, 3), (-72, 2), (-90, 1)
    ])
    func signalLevels(rssi: Int, level: Int) {
        let network = WiFiNetwork(ssid: "Test", bssid: nil, rssi: rssi, isSecure: true)
        #expect(network.signalLevel == level)
    }
}
