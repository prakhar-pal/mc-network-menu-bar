import AppKit
import Testing
import McNetworkMenuCore

@Suite("Network interface symbols")
struct NetworkInterfaceSymbolTests {
    @Test("Ethernet symbol is available as a native template image")
    func ethernetSymbolIsAvailable() throws {
        let ethernet = PrimaryInterface.ethernet(name: "en9", ipv4Address: nil)
        let image = try #require(NSImage(
            systemSymbolName: ethernet.symbolName,
            accessibilityDescription: ethernet.accessibilityLabel
        ))

        #expect(image.isTemplate)
    }
}
