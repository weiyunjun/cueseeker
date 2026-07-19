import CNativePlayback
import CoreGraphics
import CoreImage
import CoreVideo
import Foundation

struct PlaybackScreenshotGeometry: Equatable, Sendable {
    let viewportSize: CGSize
    let videoRect: CGRect

    init(viewportSize: CGSize, videoRect: CGRect) {
        self.viewportSize = viewportSize
        self.videoRect = videoRect
    }
}

public struct PlaybackScreenshotPresentation: @unchecked Sendable {
    let nativeSnapshot: SFXNativePlaybackFrameSnapshot
    let geometry: PlaybackScreenshotGeometry
    let assSubtitleFrame: ASSSparseFrame?

    public var viewportSize: CGSize {
        geometry.viewportSize
    }

    init(
        nativeSnapshot: SFXNativePlaybackFrameSnapshot,
        geometry: PlaybackScreenshotGeometry,
        assSubtitleFrame: ASSSparseFrame?
    ) {
        self.nativeSnapshot = nativeSnapshot
        self.geometry = geometry
        self.assSubtitleFrame = assSubtitleFrame
    }
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
        _ presentation: PlaybackScreenshotPresentation,
        simpleSubtitleViewportOverlay: CGImage? = nil
    ) throws -> CGImage {
        let base = try render(pixelBuffer: presentation.nativeSnapshot.pixelBuffer)
        return try compose(
            baseImage: base,
            assSubtitleFrame: presentation.assSubtitleFrame,
            simpleSubtitleViewportOverlay: simpleSubtitleViewportOverlay,
            geometry: presentation.geometry
        )
    }

    static func render(pixelBuffer: CVPixelBuffer) throws -> CGImage {
        guard CVPixelBufferGetWidth(pixelBuffer) > 0,
              CVPixelBufferGetHeight(pixelBuffer) > 0
        else {
            throw PlaybackCurrentFrameScreenshotError.invalidFrameSize
        }

        let image = CIImage(
            cvPixelBuffer: pixelBuffer,
            options: [.applyOrientationProperty: true]
        )
        let extent = image.extent.integral
        guard !extent.isEmpty,
              let renderedImage = context.createCGImage(
                image,
                from: extent,
                colorSpace: outputColorSpace
              )
        else {
            throw PlaybackCurrentFrameScreenshotError.imageConversionFailed
        }

        return renderedImage
    }

    static func compose(
        baseImage: CGImage,
        assSubtitleFrame: ASSSparseFrame?,
        simpleSubtitleViewportOverlay: CGImage?,
        geometry: PlaybackScreenshotGeometry
    ) throws -> CGImage {
        guard assSubtitleFrame?.surface != nil
                || simpleSubtitleViewportOverlay != nil
        else {
            return baseImage
        }
        guard let context = makeBitmapContext(
            width: baseImage.width,
            height: baseImage.height
        ) else {
            throw PlaybackCurrentFrameScreenshotError.imageConversionFailed
        }

        let fullRect = CGRect(
            x: 0,
            y: 0,
            width: baseImage.width,
            height: baseImage.height
        )
        context.draw(baseImage, in: fullRect)

        if let assSubtitleFrame,
           let surface = assSubtitleFrame.surface,
           let surfaceImage = makeASSImage(surface) {
            let frameWidth = max(1, assSubtitleFrame.frameWidth)
            let frameHeight = max(1, assSubtitleFrame.frameHeight)
            let scaleX = CGFloat(baseImage.width) / CGFloat(frameWidth)
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

        if let simpleSubtitleViewportOverlay,
           let croppedOverlay = cropToVideoRect(
               simpleSubtitleViewportOverlay,
               geometry: geometry
           ) {
            context.interpolationQuality = .high
            context.draw(croppedOverlay, in: fullRect)
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

    private static func cropToVideoRect(
        _ overlay: CGImage,
        geometry: PlaybackScreenshotGeometry
    ) -> CGImage? {
        let viewportSize = geometry.viewportSize
        guard viewportSize.width > 0, viewportSize.height > 0 else {
            return nil
        }

        let imageScaleX = CGFloat(overlay.width) / viewportSize.width
        let imageScaleY = CGFloat(overlay.height) / viewportSize.height
        let cropRect = CGRect(
            x: geometry.videoRect.minX * imageScaleX,
            y: (viewportSize.height - geometry.videoRect.maxY) * imageScaleY,
            width: geometry.videoRect.width * imageScaleX,
            height: geometry.videoRect.height * imageScaleY
        ).integral.intersection(
            CGRect(x: 0, y: 0, width: overlay.width, height: overlay.height)
        )
        guard !cropRect.isEmpty else {
            return nil
        }
        return overlay.cropping(to: cropRect)
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
