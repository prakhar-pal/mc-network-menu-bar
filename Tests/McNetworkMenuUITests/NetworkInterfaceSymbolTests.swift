import AppKit
import Testing
@testable import McNetworkMenu

@Suite("Network interface symbols")
@MainActor
struct NetworkInterfaceSymbolTests {
    @Test("Ethernet menu-bar image has template pixels at its intended size")
    func ethernetMenuBarImageIsVisible() throws {
        let image = EthernetMenuBarImage.make()

        #expect(image.size == NSSize(width: 20, height: 14))
        #expect(image.isTemplate)

        let data = try #require(image.tiffRepresentation)
        let bitmap = try #require(NSBitmapImageRep(data: data))
        var visiblePixelCount = 0
        for x in 0 ..< bitmap.pixelsWide {
            for y in 0 ..< bitmap.pixelsHigh where bitmap.colorAt(x: x, y: y)?.alphaComponent ?? 0 > 0.05 {
                visiblePixelCount += 1
            }
        }
        #expect(visiblePixelCount > 20)
    }
}
