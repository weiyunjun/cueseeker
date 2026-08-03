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
