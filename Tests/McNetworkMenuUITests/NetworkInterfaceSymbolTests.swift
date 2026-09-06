import AppKit
import SwiftUI
import Testing
@testable import McNetworkMenu

@Suite("Network interface symbols")
@MainActor
struct NetworkInterfaceSymbolTests {
    @Test("Ethernet menu-bar image avoids template retinting in dark appearance")
    func ethernetMenuBarImageUsesAdaptiveNonTemplatePixels() throws {
        let image = EthernetMenuBarImage.make(for: .dark)
        let data = try #require(image.tiffRepresentation)
        let bitmap = try #require(NSBitmapImageRep(data: data))

        let brightestPixel = (0 ..< bitmap.pixelsWide).flatMap { x in
            (0 ..< bitmap.pixelsHigh).compactMap { y -> CGFloat? in
                guard let color = bitmap.colorAt(x: x, y: y), color.alphaComponent > 0.05 else { return nil }
                return max(color.redComponent, color.greenComponent, color.blueComponent)
            }
        }.max() ?? 0

        #expect(brightestPixel > 0.8)
        #expect(image.isTemplate == false)
    }
}
