import CoreGraphics
import Testing
@testable import CueSeekerApp
import CueSeekerPlayback

@Test
@MainActor
func simpleSubtitleScreenshotOverlayUsesNativeOutputDimensions() throws {
    let overlay = try #require(
        PlaybackCurrentFrameScreenshotComposer.renderSimpleSubtitleOverlay(
            text: "Current subtitle",
            geometry: PlaybackScreenshotGeometry(
                viewportSize: CGSize(width: 320, height: 200),
                videoRect: CGRect(x: 0, y: 10, width: 320, height: 180)
            ),
            outputWidth: 640,
            outputHeight: 360
        )
    )

    #expect(overlay.width == 640)
    #expect(overlay.height == 360)
    #expect(containsVisibleSubtitlePixels(overlay))
    let topHalf = try #require(
        overlay.cropping(to: CGRect(x: 0, y: 0, width: 640, height: 180))
    )
    let bottomHalf = try #require(
        overlay.cropping(to: CGRect(x: 0, y: 180, width: 640, height: 180))
    )
    #expect(!containsVisibleSubtitlePixels(topHalf))
    #expect(containsVisibleSubtitlePixels(bottomHalf))
}

private func containsVisibleSubtitlePixels(_ image: CGImage) -> Bool {
    let bytesPerRow = image.width * 4
    var bytes = [UInt8](repeating: 0, count: bytesPerRow * image.height)
    guard let context = CGContext(
        data: &bytes,
        width: image.width,
        height: image.height,
        bitsPerComponent: 8,
        bytesPerRow: bytesPerRow,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGBitmapInfo(
            rawValue: CGImageAlphaInfo.premultipliedLast.rawValue
                | CGBitmapInfo.byteOrder32Big.rawValue
        ).rawValue
    ) else {
        return false
    }
    context.draw(
        image,
        in: CGRect(x: 0, y: 0, width: image.width, height: image.height)
    )
    return stride(from: 3, to: bytes.count, by: 4).contains {
        bytes[$0] > 0
    }
}
