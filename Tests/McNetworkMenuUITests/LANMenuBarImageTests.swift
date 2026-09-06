import AppKit
import Testing
@testable import McNetworkMenu

@Suite("LAN menu-bar image")
@MainActor
struct LANMenuBarImageTests {
    @Test("LAN image has intrinsic size, template rendering, and visible pixels")
    func intrinsicTemplateImage() throws {
        let image = LANMenuBarImage.make()

        #expect(image.size == NSSize(width: 18, height: 16))
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
