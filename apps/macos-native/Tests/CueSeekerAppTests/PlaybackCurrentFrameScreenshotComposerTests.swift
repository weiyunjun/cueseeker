import CoreGraphics
import Testing
@testable import CueSeekerApp
@testable import CueSeekerPlayback

@Test
@MainActor
func simpleSubtitleScreenshotOverlayUsesNativeOutputDimensions() throws {
    let viewportOverlay = try #require(
        PlaybackCurrentFrameScreenshotComposer.renderSimpleSubtitleViewportOverlay(
            text: "Current subtitle",
            viewportSize: CGSize(width: 320, height: 200)
        )
    )
    let baseImage = try #require(makeOpaqueImage(width: 640, height: 360))
    let overlay = try PlaybackCurrentFrameScreenshotRenderer.compose(
        baseImage: baseImage,
        assSubtitleFrame: nil,
        simpleSubtitleViewportOverlay: viewportOverlay,
        geometry: PlaybackScreenshotGeometry(
            viewportSize: CGSize(width: 320, height: 200),
            videoRect: CGRect(x: 0, y: 10, width: 320, height: 180)
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

private func makeOpaqueImage(width: Int, height: Int) -> CGImage? {
    guard let context = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
    ) else {
        return nil
    }
    context.setFillColor(CGColor(gray: 0, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    return context.makeImage()
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
    return stride(from: 0, to: bytes.count, by: 4).contains { index in
        bytes[index] > 16
            || bytes[index + 1] > 16
            || bytes[index + 2] > 16
    }
}
