import CoreVideo
import CoreGraphics
import Testing
@testable import CueSeekerPlayback

@Test
func currentFrameScreenshotRendererPreservesPixelDimensions() throws {
    let pixelBuffer = try makeScreenshotPixelBuffer(width: 6, height: 4)

    let image = try PlaybackCurrentFrameScreenshotRenderer.render(
        pixelBuffer: pixelBuffer
    )

    #expect(image.width == 6)
    #expect(image.height == 4)
}

@Test
func currentFrameScreenshotRendererAcceptsBiPlanarHardwareFrame() throws {
    let pixelBuffer = try makeBiPlanarScreenshotPixelBuffer(width: 8, height: 6)

    let image = try PlaybackCurrentFrameScreenshotRenderer.render(
        pixelBuffer: pixelBuffer
    )

    #expect(image.width == 8)
    #expect(image.height == 6)
}

@Test
func currentFrameScreenshotRendererComposesCurrentASSSurface() throws {
    let pixelBuffer = try makeScreenshotPixelBuffer(width: 6, height: 4)
    let baseImage = try PlaybackCurrentFrameScreenshotRenderer.render(
        pixelBuffer: pixelBuffer
    )
    let surface = ASSCroppedSurface(
        rgbaData: Data([
            0xFF, 0x00, 0x00, 0xFF,
            0xFF, 0x00, 0x00, 0xFF
        ]),
        width: 2,
        height: 1,
        stride: 8,
        destinationX: 2,
        destinationY: 2
    )
    let frame = ASSSparseFrame(
        surface: surface,
        frameWidth: 6,
        frameHeight: 4,
        timestampMilliseconds: 1_000
    )

    let composedImage = try PlaybackCurrentFrameScreenshotRenderer.compose(
        baseImage: baseImage,
        assSubtitleFrame: frame,
        simpleSubtitleViewportOverlay: nil,
        geometry: PlaybackScreenshotGeometry(
            viewportSize: CGSize(width: 6, height: 4),
            videoRect: CGRect(x: 0, y: 0, width: 6, height: 4)
        )
    )

    #expect(composedImage.width == 6)
    #expect(composedImage.height == 4)
    #expect(containsOpaqueRedPixel(composedImage))
}

private func makeScreenshotPixelBuffer(width: Int, height: Int) throws -> CVPixelBuffer {
    var pixelBuffer: CVPixelBuffer?
    let attributes: [CFString: Any] = [
        kCVPixelBufferCGImageCompatibilityKey: true,
        kCVPixelBufferCGBitmapContextCompatibilityKey: true,
        kCVPixelBufferIOSurfacePropertiesKey: [:]
    ]
    let result = CVPixelBufferCreate(
        kCFAllocatorDefault,
        width,
        height,
        kCVPixelFormatType_32BGRA,
        attributes as CFDictionary,
        &pixelBuffer
    )
    guard result == kCVReturnSuccess, let pixelBuffer else {
        throw PlaybackCurrentFrameScreenshotError.imageConversionFailed
    }

    CVPixelBufferLockBaseAddress(pixelBuffer, [])
    defer {
        CVPixelBufferUnlockBaseAddress(pixelBuffer, [])
    }
    guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else {
        throw PlaybackCurrentFrameScreenshotError.imageConversionFailed
    }
    memset(
        baseAddress,
        0x7F,
        CVPixelBufferGetBytesPerRow(pixelBuffer) * height
    )
    return pixelBuffer
}

private func makeBiPlanarScreenshotPixelBuffer(
    width: Int,
    height: Int
) throws -> CVPixelBuffer {
    var pixelBuffer: CVPixelBuffer?
    let result = CVPixelBufferCreate(
        kCFAllocatorDefault,
        width,
        height,
        kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange,
        [kCVPixelBufferIOSurfacePropertiesKey: [:]] as CFDictionary,
        &pixelBuffer
    )
    guard result == kCVReturnSuccess, let pixelBuffer else {
        throw PlaybackCurrentFrameScreenshotError.imageConversionFailed
    }

    CVPixelBufferLockBaseAddress(pixelBuffer, [])
    defer {
        CVPixelBufferUnlockBaseAddress(pixelBuffer, [])
    }
    for planeIndex in 0 ..< CVPixelBufferGetPlaneCount(pixelBuffer) {
        guard let baseAddress = CVPixelBufferGetBaseAddressOfPlane(
            pixelBuffer,
            planeIndex
        ) else {
            throw PlaybackCurrentFrameScreenshotError.imageConversionFailed
        }
        memset(
            baseAddress,
            0x80,
            CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, planeIndex)
                * CVPixelBufferGetHeightOfPlane(pixelBuffer, planeIndex)
        )
    }
    return pixelBuffer
}

private func containsOpaqueRedPixel(_ image: CGImage) -> Bool {
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
        bytes[index] > 240
            && bytes[index + 1] < 16
            && bytes[index + 2] < 16
            && bytes[index + 3] > 240
    }
}
