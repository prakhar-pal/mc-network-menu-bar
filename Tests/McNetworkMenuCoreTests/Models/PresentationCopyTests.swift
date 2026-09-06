import Testing
@testable import McNetworkMenuCore

@Suite("Presentation copy")
struct PresentationCopyTests {
    @Test("Primary symbols have distinct nonempty accessibility labels")
    func routeAccessibility() {
        let states: [PrimaryInterface] = [
            .wifi(interfaceName: "en0", ssid: nil, ipv4Address: nil),
            .ethernet(name: "en7", ipv4Address: nil),
            .offline
        ]
        #expect(states.map(\.symbolName) == [
            "wifi",
            "point.3.connected.trianglepath.dotted",
            "network.slash"
        ])
        #expect(Set(states.map(\.accessibilityLabel)).count == 3)
        #expect(states.allSatisfy { !$0.accessibilityLabel.isEmpty })
    }

    @Test("Wi-Fi sections use compact native titles")
    func sectionTitles() {
        #expect(WiFiSectionKind.allCases.map(\.title) == ["Connected", "Known Networks", "Other Networks"])
    }

    @Test("Only sanitized display errors reach operation copy")
    func operationCopy() {
        let error = DisplayError("Could not join the Wi-Fi network.")
        #expect(NetworkOperationState.failed(error).displayMessage == error.message)
        #expect(NetworkOperationState.scanning.progressLabel == "Looking for networks…")
    }
}
