import AppKit
import SwiftUI
import McNetworkMenuCore

struct NetworkInterfaceIcon: View {
    let primary: PrimaryInterface

    @ViewBuilder
    var body: some View {
        switch primary.iconKind {
        case let .system(name):
            Image(systemName: name)
        case .ethernet:
            Image(nsImage: EthernetMenuBarImage.make())
                .resizable()
                .scaledToFit()
        }
    }
}

@MainActor
enum EthernetMenuBarImage {
    private static let cachedImage: NSImage = {
        let size = CGSize(width: 20, height: 14)
        let renderer = ImageRenderer(content:
            EthernetGlyph()
                .foregroundStyle(Color.black)
                .frame(width: size.width, height: size.height)
        )
        renderer.proposedSize = ProposedViewSize(size)
        renderer.scale = 2

        let image = renderer.nsImage ?? NSImage(size: size)
        image.size = size
        image.isTemplate = true
        return image
    }()

    static func make() -> NSImage { cachedImage }
}

private struct EthernetGlyph: View {
    var body: some View {
        Canvas { context, size in
            let lineWidth = max(1.2, min(size.width, size.height) * 0.12)
            let top = size.height * 0.18
            let middle = size.height * 0.5
            let bottom = size.height * 0.82

            var brackets = Path()
            brackets.move(to: CGPoint(x: size.width * 0.20, y: top))
            brackets.addLine(to: CGPoint(x: size.width * 0.06, y: middle))
            brackets.addLine(to: CGPoint(x: size.width * 0.20, y: bottom))
            brackets.move(to: CGPoint(x: size.width * 0.80, y: top))
            brackets.addLine(to: CGPoint(x: size.width * 0.94, y: middle))
            brackets.addLine(to: CGPoint(x: size.width * 0.80, y: bottom))
            context.stroke(
                brackets,
                with: .foreground,
                style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
            )

            let diameter = lineWidth * 1.55
            for position in [0.36, 0.50, 0.64] {
                let dot = Path(ellipseIn: CGRect(
                    x: size.width * position - diameter / 2,
                    y: middle - diameter / 2,
                    width: diameter,
                    height: diameter
                ))
                context.fill(dot, with: .foreground)
            }
        }
        .aspectRatio(1.8, contentMode: .fit)
    }
}
