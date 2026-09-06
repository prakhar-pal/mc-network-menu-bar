import AppKit
import SwiftUI
import Testing
@testable import McNetworkMenu

@Suite("Network interface symbols")
@MainActor
struct NetworkInterfaceSymbolTests {
    @Test("Ethernet glyph uses the bright foreground in a dark menu bar")
    func ethernetGlyphAdaptsToDarkAppearance() throws {
        let image = try renderedEthernetGlyph(for: .dark)
        let data = try #require(image.tiffRepresentation)
        let bitmap = try #require(NSBitmapImageRep(data: data))

        let brightestPixel = (0 ..< bitmap.pixelsWide).flatMap { x in
            (0 ..< bitmap.pixelsHigh).compactMap { y -> CGFloat? in
                guard let color = bitmap.colorAt(x: x, y: y), color.alphaComponent > 0.05 else { return nil }
                return max(color.redComponent, color.greenComponent, color.blueComponent)
            }
        }.max() ?? 0

        #expect(brightestPixel > 0.8)
    }

    private func renderedEthernetGlyph(for colorScheme: ColorScheme) throws -> NSImage {
        let renderer = ImageRenderer(content:
            NetworkInterfaceIcon(primary: .ethernet(name: "en9", ipv4Address: nil))
                .frame(width: 20, height: 14)
                .environment(\.colorScheme, colorScheme)
        )
        renderer.proposedSize = .init(width: 20, height: 14)
        renderer.scale = 2
        return try #require(renderer.nsImage)
    }
}
