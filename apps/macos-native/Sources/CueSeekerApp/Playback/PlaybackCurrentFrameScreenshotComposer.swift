import CoreGraphics
import CueSeekerPlayback
import SwiftUI

enum PlaybackCurrentFrameScreenshotComposer {
    @MainActor
    static func renderSimpleSubtitleViewportOverlay(
        text: String,
        viewportSize: CGSize
    ) -> CGImage? {
        guard viewportSize.width > 1,
              viewportSize.height > 1
        else {
            return nil
        }

        let content = PlaybackSubtitleOverlay(
            text: text,
            bottomPadding: 28
        )
        .frame(width: viewportSize.width, height: viewportSize.height)
        let renderer = ImageRenderer(content: content)
        renderer.proposedSize = ProposedViewSize(viewportSize)
        renderer.scale = 1
        renderer.isOpaque = false
        return renderer.cgImage
    }
}
