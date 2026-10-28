import CNativePlayback
import CoreVideo
import CoreGraphics
import ImageIO
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
func displayMatrixOrientationMappingCoversAllEightOrthogonalOrientations() {
    let fixedOne = Int32(1 << 16)
    let makeMatrix = { (a: Int32, b: Int32, c: Int32, d: Int32) -> [Int32] in
        [a * fixedOne, b * fixedOne, 0, c * fixedOne, d * fixedOne, 0, 0, 0, 1 << 30]
    }

    let cases: [([Int32], SFXVideoOrientation, Bool)] = [
        (makeMatrix(1, 0, 0, 1), .up, false),
        (makeMatrix(-1, 0, 0, 1), .upMirrored, false),
        (makeMatrix(-1, 0, 0, -1), .down, false),
        (makeMatrix(1, 0, 0, -1), .downMirrored, false),
        (makeMatrix(0, 1, 1, 0), .leftMirrored, true),
        (makeMatrix(0, 1, -1, 0), .right, true),
        (makeMatrix(0, -1, -1, 0), .rightMirrored, true),
        (makeMatrix(0, -1, 1, 0), .left, true)
    ]

    for (matrix, expectedOrientation, expectsSwap) in cases {
        let resolved = matrix.withUnsafeBufferPointer { pointer in
            SFXResolveVideoOrientationFromDisplayMatrix(pointer.baseAddress)
        }
        #expect(resolved == expectedOrientation)
        #expect(SFXVideoOrientationSwapsDimensions(resolved) == expectsSwap)
    }
}

@Test
func currentFrameScreenshotRendererAppliesRotationFlipAndAnamorphicSARTogether() throws {
    // 4x2 quadrant buffer:
    // top-left: Red, top-right: Green
    // bottom-left: Blue, bottom-right: Yellow
    let makeQuadrantBuffer = { (orientation: SFXVideoOrientation) throws -> CVPixelBuffer in
        let buffer = try makeScreenshotPixelBuffer(width: 4, height: 2)
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        let bytesPerRow = CVPixelBufferGetBytesPerRow(buffer)
        let base = try #require(CVPixelBufferGetBaseAddress(buffer)).assumingMemoryBound(to: UInt8.self)
        for y in 0..<2 {
            for x in 0..<4 {
                let offset = y * bytesPerRow + x * 4
                let isTop = y == 0
                let isLeft = x < 2
                if isTop && isLeft {
                    // BGRA Red
                    base[offset + 0] = 0
                    base[offset + 1] = 0
                    base[offset + 2] = 255
                    base[offset + 3] = 255
                } else if isTop && !isLeft {
                    // BGRA Green
                    base[offset + 0] = 0
                    base[offset + 1] = 255
                    base[offset + 2] = 0
                    base[offset + 3] = 255
                } else if !isTop && isLeft {
                    // BGRA Blue
                    base[offset + 0] = 255
                    base[offset + 1] = 0
                    base[offset + 2] = 0
                    base[offset + 3] = 255
                } else {
                    // BGRA Yellow
                    base[offset + 0] = 0
                    base[offset + 1] = 255
                    base[offset + 2] = 255
                    base[offset + 3] = 255
                }
            }
        }
        CVBufferSetAttachment(
            buffer,
            kCGImagePropertyOrientation,
            NSNumber(value: orientation.rawValue),
            .shouldPropagate
        )
        return buffer
    }

    // 90° CW (.right): width 4 x height 2 -> width 2 x height 4.
    // Original bottom-left (Blue) moves to top-left; original top-left (Red) moves to top-right.
    let rotated90Buffer = try makeQuadrantBuffer(.right)
    let rotated90Image = try PlaybackCurrentFrameScreenshotRenderer.render(pixelBuffer: rotated90Buffer)
    #expect(rotated90Image.width == 2)
    #expect(rotated90Image.height == 4)
    let topLeft90 = try #require(pixelRGBA(in: rotated90Image, x: 0, y: 0))
    let topRight90 = try #require(pixelRGBA(in: rotated90Image, x: 1, y: 0))
    #expect(topLeft90.b > 200 && topLeft90.r < 40 && topLeft90.g < 40)
    #expect(topRight90.r > 200 && topRight90.g < 40 && topRight90.b < 40)

    // Horizontal flip (.upMirrored): width 4 x height 2 stays 4 x 2.
    // Original top-right (Green) moves to top-left.
    let mirroredBuffer = try makeQuadrantBuffer(.upMirrored)
    let mirroredImage = try PlaybackCurrentFrameScreenshotRenderer.render(pixelBuffer: mirroredBuffer)
    #expect(mirroredImage.width == 4)
    #expect(mirroredImage.height == 2)
    let topLeftMirrored = try #require(pixelRGBA(in: mirroredImage, x: 0, y: 0))
    #expect(topLeftMirrored.g > 200 && topLeftMirrored.r < 40 && topLeftMirrored.b < 40)

    // Anamorphic SAR (4:3 on 144x108 -> 192x108) + 90° CW (.right) -> 108x192
    let anamorphicRotatedBuffer = try makeScreenshotPixelBuffer(width: 144, height: 108)
    let stretchDict: [CFString: Any] = [
        kCVImageBufferPixelAspectRatioHorizontalSpacingKey: 4,
        kCVImageBufferPixelAspectRatioVerticalSpacingKey: 3
    ]
    CVBufferSetAttachment(
        anamorphicRotatedBuffer,
        kCVImageBufferPixelAspectRatioKey,
        stretchDict as CFDictionary,
        .shouldPropagate
    )
    CVBufferSetAttachment(
        anamorphicRotatedBuffer,
        kCGImagePropertyOrientation,
        NSNumber(value: SFXVideoOrientation.right.rawValue),
        .shouldPropagate
    )
    #expect(SFXUnrotatedDisplayVideoWidthForPixelBuffer(anamorphicRotatedBuffer) == 192)
    #expect(SFXDisplayVideoWidthForPixelBuffer(anamorphicRotatedBuffer) == 108)
    #expect(SFXDisplayVideoHeightForPixelBuffer(anamorphicRotatedBuffer) == 192)
    let anamorphicRotatedImage = try PlaybackCurrentFrameScreenshotRenderer.render(
        pixelBuffer: anamorphicRotatedBuffer
    )
    #expect(anamorphicRotatedImage.width == 108)
    #expect(anamorphicRotatedImage.height == 192)
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

private func pixelRGBA(in image: CGImage, x: Int, y: Int) -> (r: UInt8, g: UInt8, b: UInt8, a: UInt8)? {
    guard x >= 0, x < image.width, y >= 0, y < image.height else {
        return nil
    }
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
        return nil
    }
    context.draw(
        image,
        in: CGRect(x: 0, y: 0, width: image.width, height: image.height)
    )
    let offset = y * bytesPerRow + x * 4
    return (bytes[offset], bytes[offset + 1], bytes[offset + 2], bytes[offset + 3])
}
