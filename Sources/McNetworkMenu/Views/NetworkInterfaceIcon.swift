import AppKit
import SwiftUI
import McNetworkMenuCore

struct NetworkInterfaceIcon: View {
    let primary: PrimaryInterface
    var usesIntrinsicLANImage = false

    @ViewBuilder
    var body: some View {
        switch primary.iconKind {
        case let .system(name):
            Image(systemName: name)
        case .lanTree:
            if usesIntrinsicLANImage {
                Image(nsImage: LANMenuBarImage.make())
                    .resizable()
                    .scaledToFit()
            } else {
                LANTreeIcon()
                    .padding(1)
            }
        }
    }
}

@MainActor
enum LANMenuBarImage {
    private static let cachedImage: NSImage = {
        let size = CGSize(width: 18, height: 16)
        let renderer = ImageRenderer(content:
            LANTreeIcon()
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

private struct LANTreeIcon: View {
    var body: some View {
        GeometryReader { proxy in
            LANTreeShape()
                .stroke(
                    style: StrokeStyle(
                        lineWidth: max(1.25, min(proxy.size.width, proxy.size.height) * 0.085),
                        lineCap: .round,
                        lineJoin: .round
                    )
                )
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

private struct LANTreeShape: Shape {
    func path(in rect: CGRect) -> Path {
        let side = min(rect.width, rect.height) * 0.20
        let radius = side * 0.18
        let topY = rect.minY + rect.height * 0.05
        let branchY = rect.minY + rect.height * 0.47
        let bottomY = rect.minY + rect.height * 0.72
        let centers = [0.16, 0.50, 0.84].map { rect.minX + rect.width * $0 }
        let topCenterX = rect.midX

        var path = Path()
        path.move(to: CGPoint(x: topCenterX, y: topY + side))
        path.addLine(to: CGPoint(x: topCenterX, y: branchY))
        path.addLine(to: CGPoint(x: centers[0], y: branchY))
        path.move(to: CGPoint(x: centers[2], y: branchY))
        path.addLine(to: CGPoint(x: topCenterX, y: branchY))
        for centerX in centers {
            path.move(to: CGPoint(x: centerX, y: branchY))
            path.addLine(to: CGPoint(x: centerX, y: bottomY))
        }

        path.addRoundedRect(
            in: CGRect(x: topCenterX - side / 2, y: topY, width: side, height: side),
            cornerSize: CGSize(width: radius, height: radius)
        )
        for centerX in centers {
            path.addRoundedRect(
                in: CGRect(x: centerX - side / 2, y: bottomY, width: side, height: side),
                cornerSize: CGSize(width: radius, height: radius)
            )
        }
        return path
    }
}
