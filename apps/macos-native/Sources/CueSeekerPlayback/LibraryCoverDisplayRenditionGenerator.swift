import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers
import CueSeekerCore

public struct LibraryCoverDisplayProfile: Equatable, Sendable {
    public static let current = LibraryCoverDisplayProfile(
        version: LibraryCoverDisplayProfileVersion.current,
        maximumPixelWidth: 512,
        maximumPixelHeight: 288,
        jpegCompressionQuality: 0.90,
        allowsUpscaling: false
    )

    public let version: Int
    public let maximumPixelWidth: Int
    public let maximumPixelHeight: Int
    public let jpegCompressionQuality: Double
    public let allowsUpscaling: Bool
}

public struct LibraryCoverDisplayRenditionResult: Equatable, Sendable {
    public let pixelWidth: Int
    public let pixelHeight: Int
    public let byteCount: Int
}

struct LibraryCoverDisplayPixelSize: Equatable, Sendable {
    let width: Int
    let height: Int
}

struct LibraryCoverEncodedDisplayRendition: Sendable {
    let result: LibraryCoverDisplayRenditionResult
    let data: Data
}

struct LibraryCoverDisplayRenditionGenerator: Sendable {
    static let profile = LibraryCoverDisplayProfile.current

    func generate(
        masterURL: URL,
        destinationURL: URL
    ) throws -> LibraryCoverDisplayRenditionResult {
        let encodedRendition = try encode(masterURL: masterURL)
        try Task.checkCancellation()
        try Self.publish(encodedRendition.data, to: destinationURL)
        return encodedRendition.result
    }

    func encode(masterURL: URL) throws -> LibraryCoverEncodedDisplayRendition {
        try autoreleasepool {
            guard let source = CGImageSourceCreateWithURL(
                masterURL as CFURL,
                [kCGImageSourceShouldCache: false] as CFDictionary
            ) else {
                throw LibraryCoverDisplayRenditionError.sourceOpenFailed(masterURL.path)
            }

            let sourceProperties = try Self.sourceProperties(source, path: masterURL.path)
            let targetSize = try Self.fittedPixelSize(
                sourceWidth: sourceProperties.pixelWidth,
                sourceHeight: sourceProperties.pixelHeight,
                orientation: sourceProperties.orientation,
                profile: Self.profile
            )
            let thumbnailOptions: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: max(targetSize.width, targetSize.height),
                kCGImageSourceShouldCacheImmediately: true
            ]
            guard let decodedThumbnail = CGImageSourceCreateThumbnailAtIndex(
                source,
                0,
                thumbnailOptions as CFDictionary
            ) else {
                throw LibraryCoverDisplayRenditionError.decodeFailed(masterURL.path)
            }

            let outputImage = try Self.imageFittedToProfileIfNeeded(decodedThumbnail)
            let encodedData = try Self.jpegData(from: outputImage)
            try Self.validateJPEGData(encodedData)
            try Task.checkCancellation()

            return LibraryCoverEncodedDisplayRendition(
                result: LibraryCoverDisplayRenditionResult(
                    pixelWidth: outputImage.width,
                    pixelHeight: outputImage.height,
                    byteCount: encodedData.count
                ),
                data: encodedData
            )
        }
    }

    static func publish(_ data: Data, to destinationURL: URL) throws {
        try FileManager.default.createDirectory(
            at: destinationURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        do {
            try data.write(to: destinationURL, options: .atomic)
        } catch {
            throw LibraryCoverDisplayRenditionError.publishFailed(
                destinationURL.path,
                String(describing: error)
            )
        }
    }

    static func fittedPixelSize(
        sourceWidth: Int,
        sourceHeight: Int,
        orientation: UInt32,
        profile: LibraryCoverDisplayProfile = .current
    ) throws -> LibraryCoverDisplayPixelSize {
        guard sourceWidth > 0, sourceHeight > 0 else {
            throw LibraryCoverDisplayRenditionError.invalidSourceDimensions(
                sourceWidth,
                sourceHeight
            )
        }

        let swapsAxes = (5...8).contains(Int(orientation))
        let orientedWidth = swapsAxes ? sourceHeight : sourceWidth
        let orientedHeight = swapsAxes ? sourceWidth : sourceHeight
        let widthScale = Double(profile.maximumPixelWidth) / Double(orientedWidth)
        let heightScale = Double(profile.maximumPixelHeight) / Double(orientedHeight)
        let scale = profile.allowsUpscaling
            ? min(widthScale, heightScale)
            : min(1, widthScale, heightScale)
        let width = min(
            profile.maximumPixelWidth,
            max(1, Int((Double(orientedWidth) * scale).rounded()))
        )
        let height = min(
            profile.maximumPixelHeight,
            max(1, Int((Double(orientedHeight) * scale).rounded()))
        )
        return LibraryCoverDisplayPixelSize(width: width, height: height)
    }

    private static func sourceProperties(
        _ source: CGImageSource,
        path: String
    ) throws -> (pixelWidth: Int, pixelHeight: Int, orientation: UInt32) {
        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil)
            as? [CFString: Any],
              let pixelWidth = (properties[kCGImagePropertyPixelWidth] as? NSNumber)?.intValue,
              let pixelHeight = (properties[kCGImagePropertyPixelHeight] as? NSNumber)?.intValue,
              pixelWidth > 0,
              pixelHeight > 0
        else {
            throw LibraryCoverDisplayRenditionError.invalidSourceMetadata(path)
        }

        let orientation = (properties[kCGImagePropertyOrientation] as? NSNumber)?.uint32Value ?? 1
        return (pixelWidth, pixelHeight, orientation)
    }

    private static func imageFittedToProfileIfNeeded(_ image: CGImage) throws -> CGImage {
        let profile = Self.profile
        guard image.width > profile.maximumPixelWidth
                || image.height > profile.maximumPixelHeight
        else {
            return image
        }

        let fittedSize = try fittedPixelSize(
            sourceWidth: image.width,
            sourceHeight: image.height,
            orientation: 1,
            profile: profile
        )
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                data: nil,
                width: fittedSize.width,
                height: fittedSize.height,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              )
        else {
            throw LibraryCoverDisplayRenditionError.scalingContextCreationFailed
        }

        context.interpolationQuality = .high
        context.draw(
            image,
            in: CGRect(x: 0, y: 0, width: fittedSize.width, height: fittedSize.height)
        )
        guard let fittedImage = context.makeImage() else {
            throw LibraryCoverDisplayRenditionError.scalingFailed
        }
        return fittedImage
    }

    private static func jpegData(from image: CGImage) throws -> Data {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data,
            UTType.jpeg.identifier as CFString,
            1,
            nil
        ) else {
            throw LibraryCoverDisplayRenditionError.destinationCreationFailed
        }

        let properties: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: Self.profile.jpegCompressionQuality,
            kCGImagePropertyOrientation: 1
        ]
        CGImageDestinationAddImage(destination, image, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else {
            throw LibraryCoverDisplayRenditionError.encodingFailed
        }
        return data as Data
    }

    private static func validateJPEGData(_ data: Data) throws {
        guard !data.isEmpty,
              let source = CGImageSourceCreateWithData(data as CFData, nil),
              CGImageSourceGetCount(source) == 1,
              CGImageSourceGetType(source) as String? == UTType.jpeg.identifier,
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil)
                as? [CFString: Any],
              let width = (properties[kCGImagePropertyPixelWidth] as? NSNumber)?.intValue,
              let height = (properties[kCGImagePropertyPixelHeight] as? NSNumber)?.intValue,
              width > 0,
              height > 0,
              width <= Self.profile.maximumPixelWidth,
              height <= Self.profile.maximumPixelHeight,
              ((properties[kCGImagePropertyOrientation] as? NSNumber)?.intValue ?? 1) == 1
        else {
            throw LibraryCoverDisplayRenditionError.outputValidationFailed
        }
    }
}

enum LibraryCoverDisplayRenditionError: Error, CustomStringConvertible, Equatable {
    case sourceOpenFailed(String)
    case invalidSourceMetadata(String)
    case invalidSourceDimensions(Int, Int)
    case decodeFailed(String)
    case scalingContextCreationFailed
    case scalingFailed
    case destinationCreationFailed
    case encodingFailed
    case outputValidationFailed
    case publishFailed(String, String)

    var description: String {
        switch self {
        case .sourceOpenFailed(let path):
            "failed to open cover master: \(path)"
        case .invalidSourceMetadata(let path):
            "invalid cover master metadata: \(path)"
        case .invalidSourceDimensions(let width, let height):
            "invalid cover master dimensions: \(width)x\(height)"
        case .decodeFailed(let path):
            "failed to decode cover master: \(path)"
        case .scalingContextCreationFailed:
            "failed to create cover scaling context"
        case .scalingFailed:
            "failed to scale cover display rendition"
        case .destinationCreationFailed:
            "failed to create JPEG destination"
        case .encodingFailed:
            "failed to encode cover display JPEG"
        case .outputValidationFailed:
            "cover display JPEG failed validation"
        case .publishFailed(let path, let message):
            "failed to publish cover display JPEG at \(path): \(message)"
        }
    }
}
