import CoreGraphics
import CueSeekerPlayback
import SwiftUI

enum PlaybackCurrentFrameScreenshotComposer {
    @MainActor
    static func render(
        presentation: PlaybackScreenshotPresentation,
        simpleSubtitleText: String?
    ) throws -> CGImage {
        let overlay = simpleSubtitleText.flatMap {
            renderSimpleSubtitleOverlay(
                text: $0,
                geometry: presentation.geometry,
                outputWidth: presentation.frame.width,
                outputHeight: presentation.frame.height
            )
        }
        return try render(
            presentation,
            simpleSubtitleOverlay: overlay
        )
    }

    static func render(
        _ presentation: PlaybackScreenshotPresentation,
        simpleSubtitleOverlay: CGImage?
    ) throws -> CGImage {
        try PlaybackCurrentFrameScreenshotRenderer.render(
            presentation,
            simpleSubtitleOverlay: simpleSubtitleOverlay
        )
    }

    @MainActor
    static func renderSimpleSubtitleOverlay(
        text: String,
        geometry: PlaybackScreenshotGeometry,
        outputWidth: Int,
        outputHeight: Int
    ) -> CGImage? {
        let viewportSize = geometry.viewportSize
        guard viewportSize.width > 1,
              viewportSize.height > 1,
              outputWidth > 0,
              outputHeight > 0
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
        guard let viewportImage = renderer.cgImage else {
            return nil
        }

        let imageScaleX = CGFloat(viewportImage.width) / viewportSize.width
        let imageScaleY = CGFloat(viewportImage.height) / viewportSize.height
        let topOriginVideoRect = CGRect(
            x: geometry.videoRect.minX * imageScaleX,
            y: (viewportSize.height - geometry.videoRect.maxY) * imageScaleY,
            width: geometry.videoRect.width * imageScaleX,
            height: geometry.videoRect.height * imageScaleY
        ).integral.intersection(
            CGRect(x: 0, y: 0, width: viewportImage.width, height: viewportImage.height)
        )
        guard !topOriginVideoRect.isEmpty,
              let croppedOverlay = viewportImage.cropping(to: topOriginVideoRect),
              let context = makeTransparentContext(
                width: outputWidth,
                height: outputHeight
              )
        else {
            return nil
        }

        context.interpolationQuality = .high
        context.draw(
            croppedOverlay,
            in: CGRect(x: 0, y: 0, width: outputWidth, height: outputHeight)
        )
        return context.makeImage()
    }

    private static func makeTransparentContext(
        width: Int,
        height: Int
    ) -> CGContext? {
        CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(
                rawValue: CGImageAlphaInfo.premultipliedLast.rawValue
                    | CGBitmapInfo.byteOrder32Big.rawValue
            ).rawValue
        )
    }
}
