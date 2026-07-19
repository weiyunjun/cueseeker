import CoreVideo
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
