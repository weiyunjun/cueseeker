import CNativePlayback
import CoreGraphics
import CoreImage
import CoreVideo
import Foundation

public final class PlaybackSubmittedVideoFrame: @unchecked Sendable {
    let nativeSnapshot: SFXNativePlaybackFrameSnapshot

    init(nativeSnapshot: SFXNativePlaybackFrameSnapshot) {
        self.nativeSnapshot = nativeSnapshot
    }

    public var width: Int {
        nativeSnapshot.width
    }

    public var height: Int {
        nativeSnapshot.height
    }

    var pixelBuffer: CVPixelBuffer {
        nativeSnapshot.pixelBuffer
    }
}

public struct PlaybackScreenshotGeometry: Equatable, Sendable {
    public let viewportSize: CGSize
    public let videoRect: CGRect

    public init(viewportSize: CGSize, videoRect: CGRect) {
        self.viewportSize = viewportSize
        self.videoRect = videoRect
    }
}

public struct PlaybackASSSubtitleSurface: Equatable, Sendable {
    public let rgbaData: Data
    public let width: Int
    public let height: Int
    public let stride: Int
    public let destinationX: Int
    public let destinationY: Int
    public let frameWidth: Int
    public let frameHeight: Int

    public init(
        rgbaData: Data,
        width: Int,
        height: Int,
        stride: Int,
        destinationX: Int,
        destinationY: Int,
        frameWidth: Int,
        frameHeight: Int
    ) {
        self.rgbaData = rgbaData
        self.width = width
        self.height = height
        self.stride = stride
        self.destinationX = destinationX
        self.destinationY = destinationY
        self.frameWidth = frameWidth
        self.frameHeight = frameHeight
    }
}

public struct PlaybackScreenshotPresentation: @unchecked Sendable {
    public let frame: PlaybackSubmittedVideoFrame
    public let geometry: PlaybackScreenshotGeometry
    public let assSubtitleSurface: PlaybackASSSubtitleSurface?

    public init(
        frame: PlaybackSubmittedVideoFrame,
        geometry: PlaybackScreenshotGeometry,
        assSubtitleSurface: PlaybackASSSubtitleSurface?
    ) {
        self.frame = frame
        self.geometry = geometry
        self.assSubtitleSurface = assSubtitleSurface
    }
}

public enum PlaybackCurrentFrameScreenshotError: Error, CustomStringConvertible {
    case invalidFrameSize
    case imageConversionFailed

    public var description: String {
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
        _ frame: PlaybackSubmittedVideoFrame
    ) throws -> CGImage {
        try render(pixelBuffer: frame.pixelBuffer)
    }

    public static func render(
        _ presentation: PlaybackScreenshotPresentation,
        simpleSubtitleOverlay: CGImage? = nil
    ) throws -> CGImage {
        let base = try render(presentation.frame)
        return try compose(
            baseImage: base,
            assSubtitleSurface: presentation.assSubtitleSurface,
            simpleSubtitleOverlay: simpleSubtitleOverlay
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
        assSubtitleSurface: PlaybackASSSubtitleSurface?,
        simpleSubtitleOverlay: CGImage?
    ) throws -> CGImage {
        guard assSubtitleSurface != nil || simpleSubtitleOverlay != nil else {
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

        if let assSubtitleSurface,
           let surfaceImage = makeASSImage(assSubtitleSurface) {
            let frameWidth = max(1, assSubtitleSurface.frameWidth)
            let frameHeight = max(1, assSubtitleSurface.frameHeight)
            let scaleX = CGFloat(baseImage.width) / CGFloat(frameWidth)
            let scaleY = CGFloat(baseImage.height) / CGFloat(frameHeight)
            let destinationHeight = CGFloat(assSubtitleSurface.height) * scaleY
            let destinationRect = CGRect(
                x: CGFloat(assSubtitleSurface.destinationX) * scaleX,
                y: CGFloat(baseImage.height)
                    - CGFloat(assSubtitleSurface.destinationY) * scaleY
                    - destinationHeight,
                width: CGFloat(assSubtitleSurface.width) * scaleX,
                height: destinationHeight
            )
            context.draw(surfaceImage, in: destinationRect)
        }

        if let simpleSubtitleOverlay {
            context.draw(simpleSubtitleOverlay, in: fullRect)
        }

        guard let image = context.makeImage() else {
            throw PlaybackCurrentFrameScreenshotError.imageConversionFailed
        }
        return image
    }

    private static func makeASSImage(
        _ surface: PlaybackASSSubtitleSurface
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
