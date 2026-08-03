import AppKit
import SwiftUI
import Testing
@testable import CueSeekerApp

@MainActor
@Test
func libraryCoverFrameIgnoresLoadedImageIntrinsicAspectRatio() {
    let sourceSizes = [
        NSSize(width: 512, height: 288),
        NSSize(width: 384, height: 288),
        NSSize(width: 512, height: 512),
        NSSize(width: 288, height: 512),
    ]

    for sourceSize in sourceSizes {
        let hostingView = NSHostingView(
            rootView: LibraryCoverFrame {
                Image(nsImage: NSImage(size: sourceSize))
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(width: 224)
        )
        hostingView.layoutSubtreeIfNeeded()

        #expect(abs(hostingView.fittingSize.width - 224) < 0.001)
        #expect(abs(hostingView.fittingSize.height - 126) < 0.001)
    }
}

@MainActor
@Test
func libraryCoverFrameKeepsBadgeInsideTheCoverRegion() {
    let probe = LibraryCoverFrameSizeProbeView()
    let hostingView = NSHostingView(
        rootView: LibraryCoverFrame {
            ZStack(alignment: .bottomTrailing) {
                GeometryReader { _ in
                    Color.clear
                }
                LibraryCoverFrameSizeProbe(probe: probe)
            }
        }
        .frame(width: 224)
    )
    hostingView.frame = CGRect(x: 0, y: 0, width: 224, height: 126)
    hostingView.layoutSubtreeIfNeeded()

    #expect(probe.frame.minX >= 0)
    #expect(probe.frame.minY >= 0)
    #expect(probe.frame.maxX <= 224)
    #expect(probe.frame.maxY <= 126)
    #expect(abs(probe.frame.maxX - 224) < 0.001)
}

@Test
func libraryCoverImageFillLayoutCropsOnlyTheExpectedEdges() {
    let containerSize = CGSize(width: 160, height: 90)

    let fourByThree = LibraryCoverImageFillLayout.resolve(
        sourceSize: CGSize(width: 4, height: 3),
        containerSize: containerSize
    )
    #expect(fourByThree.renderedSize == CGSize(width: 160, height: 120))
    #expect(fourByThree.offset == .zero)

    let ultrawide = LibraryCoverImageFillLayout.resolve(
        sourceSize: CGSize(width: 21, height: 9),
        containerSize: containerSize
    )
    #expect(ultrawide.renderedSize == CGSize(width: 210, height: 90))
    #expect(ultrawide.offset == CGSize(width: -25, height: 0))

    let sixteenByNine = LibraryCoverImageFillLayout.resolve(
        sourceSize: CGSize(width: 16, height: 9),
        containerSize: containerSize
    )
    #expect(sixteenByNine.renderedSize == containerSize)
    #expect(sixteenByNine.offset == .zero)
}

@MainActor
private final class LibraryCoverFrameSizeProbeView: NSView {
    override var intrinsicContentSize: NSSize {
        NSSize(width: 48, height: 24)
    }
}

private struct LibraryCoverFrameSizeProbe: NSViewRepresentable {
    let probe: LibraryCoverFrameSizeProbeView

    func makeNSView(context _: Context) -> LibraryCoverFrameSizeProbeView {
        probe
    }

    func updateNSView(
        _ nsView: LibraryCoverFrameSizeProbeView,
        context _: Context
    ) {}
}
