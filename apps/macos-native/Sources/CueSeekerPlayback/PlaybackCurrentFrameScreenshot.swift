import CNativePlayback
import CoreGraphics
import CoreImage
import CoreVideo
import Foundation

public struct PlaybackScreenshotPresentation: @unchecked Sendable {
    let nativeSnapshot: SFXNativePlaybackFrameSnapshot
    let assSubtitleFrame: ASSSparseFrame?
    let srtSubtitleImage: CGImage?
}

enum PlaybackCurrentFrameScreenshotError: Error, CustomStringConvertible {
    case invalidFrameSize
    case imageConversionFailed

    var description: String {
        switch self {
        case .invalidFrameSize:
            "The submitted playback frame has an invalid pixel size."
        case .imageConversionFailed:
            "The submitted playback frame could not be converted to an image."
        }
    }
}

public enum PlaybackCurrentFrameScreenshotRenderer {
    private final class LockedContext: @unchecked Sendable {
        private let context = CIContext(options: [
            .cacheIntermediates: false
        ])
        private let lock = NSLock()

        func createCGImage(
            _ image: CIImage,
            from extent: CGRect,
            colorSpace: CGColorSpace
        ) -> CGImage? {
            lock.lock()
            defer {
                lock.unlock()
            }
            return context.createCGImage(
                image,
                from: extent,
                format: .RGBA8,
                colorSpace: colorSpace
            )
        }
    }

    private static let context = LockedContext()
    private static let outputColorSpace = CGColorSpace(name: CGColorSpace.sRGB)
        ?? CGColorSpaceCreateDeviceRGB()

    public static func render(
        _ presentation: PlaybackScreenshotPresentation
    ) throws -> CGImage {
        let hasSubtitles = presentation.assSubtitleFrame?.surface != nil
            || presentation.srtSubtitleImage != nil
        let base = try render(
            pixelBuffer: presentation.nativeSnapshot.pixelBuffer,
            applyAspectRatio: !hasSubtitles
        )
        return try compose(
            baseImage: base,
            targetWidth: presentation.nativeSnapshot.width,
            assSubtitleFrame: presentation.assSubtitleFrame,
            srtSubtitleImage: presentation.srtSubtitleImage
        )
    }

    static func render(
        pixelBuffer: CVPixelBuffer,
        applyAspectRatio: Bool = true
    ) throws -> CGImage {
        let storageWidth = CVPixelBufferGetWidth(pixelBuffer)
        let storageHeight = CVPixelBufferGetHeight(pixelBuffer)
        guard storageWidth > 0,
              storageHeight > 0
        else {
            throw PlaybackCurrentFrameScreenshotError.invalidFrameSize
        }

        var image = CIImage(
            cvPixelBuffer: pixelBuffer,
            options: [.applyOrientationProperty: true]
        )
        let rawExtent = image.extent.integral
        guard !rawExtent.isEmpty else {
            throw PlaybackCurrentFrameScreenshotError.imageConversionFailed
        }

        let targetWidth = applyAspectRatio
            ? max(1, SFXDisplayVideoWidthForPixelBuffer(pixelBuffer))
            : Int(rawExtent.width)
        let targetExtent: CGRect
        if targetWidth != Int(rawExtent.width) {
            let scaleX = CGFloat(targetWidth) / rawExtent.width
            targetExtent = CGRect(
                x: 0,
                y: 0,
                width: CGFloat(targetWidth),
                height: rawExtent.height
            )
            image = image
                .clampedToExtent()
                .transformed(
                    by: CGAffineTransform(
                        translationX: -rawExtent.minX,
                        y: -rawExtent.minY
                    ).scaledBy(x: scaleX, y: 1)
                )
                .cropped(to: targetExtent)
        } else {
            targetExtent = rawExtent
        }

        guard let renderedImage = context.createCGImage(
            image,
            from: targetExtent,
            colorSpace: outputColorSpace
        ) else {
            throw PlaybackCurrentFrameScreenshotError.imageConversionFailed
        }
        return renderedImage
    }

    static func compose(
        baseImage: CGImage,
        targetWidth: Int? = nil,
        assSubtitleFrame: ASSSparseFrame?,
        srtSubtitleImage: CGImage?
    ) throws -> CGImage {
        let outputWidth = max(1, targetWidth ?? baseImage.width)
        guard assSubtitleFrame?.surface != nil
                || srtSubtitleImage != nil
                || outputWidth != baseImage.width
        else {
            return baseImage
        }
        guard let context = makeBitmapContext(
            width: outputWidth,
            height: baseImage.height
        ) else {
            throw PlaybackCurrentFrameScreenshotError.imageConversionFailed
        }

        let fullRect = CGRect(
            x: 0,
            y: 0,
            width: outputWidth,
            height: baseImage.height
        )
        if outputWidth != baseImage.width {
            context.interpolationQuality = .high
        }
        context.draw(baseImage, in: fullRect)

        if let assSubtitleFrame,
           let surface = assSubtitleFrame.surface,
           let surfaceImage = makeASSImage(surface) {
            let frameWidth = max(1, assSubtitleFrame.frameWidth)
            let frameHeight = max(1, assSubtitleFrame.frameHeight)
            let scaleX = CGFloat(outputWidth) / CGFloat(frameWidth)
            let scaleY = CGFloat(baseImage.height) / CGFloat(frameHeight)
            let destinationHeight = CGFloat(surface.height) * scaleY
            let destinationRect = CGRect(
                x: CGFloat(surface.destinationX) * scaleX,
                y: CGFloat(baseImage.height)
                    - CGFloat(surface.destinationY) * scaleY
                    - destinationHeight,
                width: CGFloat(surface.width) * scaleX,
                height: destinationHeight
            )
            context.draw(surfaceImage, in: destinationRect)
        }

        if let srtSubtitleImage {
            context.interpolationQuality = .high
            context.draw(srtSubtitleImage, in: fullRect)
        }

        guard let image = context.makeImage() else {
            throw PlaybackCurrentFrameScreenshotError.imageConversionFailed
        }
        return image
    }

    private static func makeASSImage(
        _ surface: ASSCroppedSurface
    ) -> CGImage? {
        guard surface.width > 0,
              surface.height > 0,
              surface.stride >= surface.width * 4,
              surface.rgbaData.count >= surface.stride * surface.height,
              let provider = CGDataProvider(data: surface.rgbaData as CFData)
        else {
            return nil
        }

        return CGImage(
            width: surface.width,
            height: surface.height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: surface.stride,
            space: outputColorSpace,
            bitmapInfo: CGBitmapInfo(
                rawValue: CGImageAlphaInfo.premultipliedLast.rawValue
                    | CGBitmapInfo.byteOrder32Big.rawValue
            ),
            provider: provider,
            decode: nil,
            shouldInterpolate: true,
            intent: .defaultIntent
        )
    }

    private static func makeBitmapContext(width: Int, height: Int) -> CGContext? {
        guard width > 0, height > 0 else {
            return nil
        }
        return CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: outputColorSpace,
            bitmapInfo: CGBitmapInfo(
                rawValue: CGImageAlphaInfo.premultipliedLast.rawValue
                    | CGBitmapInfo.byteOrder32Big.rawValue
            ).rawValue
        )
    }
}
