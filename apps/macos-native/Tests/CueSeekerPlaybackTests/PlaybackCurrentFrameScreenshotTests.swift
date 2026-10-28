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
func currentFrameScreenshotRendererAppliesPixelAspectRatioStretchAndSqueeze() throws {
    let stretchedBuffer = try makeScreenshotPixelBuffer(width: 144, height: 108)
    let stretchDict: [CFString: Any] = [
        kCVImageBufferPixelAspectRatioHorizontalSpacingKey: 4,
        kCVImageBufferPixelAspectRatioVerticalSpacingKey: 3
    ]
    CVBufferSetAttachment(
        stretchedBuffer,
        kCVImageBufferPixelAspectRatioKey,
        stretchDict as CFDictionary,
        .shouldPropagate
    )
    let stretchedImage = try PlaybackCurrentFrameScreenshotRenderer.render(
        pixelBuffer: stretchedBuffer
    )
    #expect(stretchedImage.width == 192)
    #expect(stretchedImage.height == 108)

    let squeezedBuffer = try makeBiPlanarScreenshotPixelBuffer(width: 180, height: 120)
    let squeezeDict: [CFString: Any] = [
        kCVImageBufferPixelAspectRatioHorizontalSpacingKey: 8,
        kCVImageBufferPixelAspectRatioVerticalSpacingKey: 9
    ]
    CVBufferSetAttachment(
        squeezedBuffer,
        kCVImageBufferPixelAspectRatioKey,
        squeezeDict as CFDictionary,
        .shouldPropagate
    )
    let squeezedImage = try PlaybackCurrentFrameScreenshotRenderer.render(
        pixelBuffer: squeezedBuffer
    )
    #expect(squeezedImage.width == 160)
    #expect(squeezedImage.height == 120)
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
        srtSubtitleImage: nil
    )

    #expect(composedImage.width == 6)
    #expect(composedImage.height == 4)
    #expect(containsOpaqueRedPixel(composedImage))
}

@Test
func currentFrameScreenshotRendererComposesSharedSRTImage() throws {
    let pixelBuffer = try makeScreenshotPixelBuffer(width: 640, height: 360)
    let baseImage = try PlaybackCurrentFrameScreenshotRenderer.render(
        pixelBuffer: pixelBuffer
    )
    let layout = try #require(
        SRTSubtitleRenderer.makeLayout(
            cues: [
                PlaybackSubtitleCue(
                    sourceOrdinal: 0,
                    startMilliseconds: 1_000,
                    endMilliseconds: 3_000,
                    text: "（ミコト）はい"
                )
            ],
            canvasSize: CGSize(width: 640, height: 360),
            style: SRTSubtitleStyle()
        )
    )
    let subtitleImage = try #require(
        SRTSubtitleRenderer.image(
            layout: layout,
            atMilliseconds: 2_000
        )
    )

    let composedImage = try PlaybackCurrentFrameScreenshotRenderer.compose(
        baseImage: baseImage,
        assSubtitleFrame: nil,
        srtSubtitleImage: subtitleImage
    )

    #expect(composedImage.width == 640)
    #expect(composedImage.height == 360)
    #expect(containsBrightPixel(composedImage))
    let topHalf = try #require(
        composedImage.cropping(
            to: CGRect(x: 0, y: 0, width: 640, height: 180)
        )
    )
    let bottomHalf = try #require(
        composedImage.cropping(
            to: CGRect(x: 0, y: 180, width: 640, height: 180)
        )
    )
    #expect(!containsBrightPixel(topHalf))
    #expect(containsBrightPixel(bottomHalf))
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

private func containsBrightPixel(_ image: CGImage) -> Bool {
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
    return stride(from: 0, to: bytes.count, by: 4).contains {
        bytes[$0] > 180 && bytes[$0 + 1] > 180 && bytes[$0 + 2] > 180
    }
}
