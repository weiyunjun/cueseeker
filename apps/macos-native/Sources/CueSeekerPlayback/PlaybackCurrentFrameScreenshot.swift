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

    public var milliseconds: Int {
        nativeSnapshot.milliseconds
    }

    public var presentationGeneration: UInt {
        nativeSnapshot.presentationGeneration
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

public struct PlaybackScreenshotImage: @unchecked Sendable {
    public let image: CGImage
    public let milliseconds: Int
    public let presentationGeneration: UInt

    public var width: Int {
        image.width
    }

    public var height: Int {
        image.height
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
    ) throws -> PlaybackScreenshotImage {
        let image = try render(pixelBuffer: frame.pixelBuffer)
        return PlaybackScreenshotImage(
            image: image,
            milliseconds: frame.milliseconds,
            presentationGeneration: frame.presentationGeneration
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
}
