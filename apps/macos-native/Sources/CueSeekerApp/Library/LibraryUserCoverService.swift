import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers
import CueSeekerCore
import CueSeekerPlayback

enum LibraryUserCoverTarget: Equatable, Sendable {
    case video(path: String)
    case folder(path: String)

    var invalidationDescription: String {
        switch self {
        case .video:
            "video"
        case .folder:
            "folder"
        }
    }
}

struct LibraryUserCoverSource: @unchecked Sendable {
    let image: CGImage

    var pixelSize: CGSize {
        CGSize(width: image.width, height: image.height)
    }
}

struct LibraryUserCoverSaveResult: Equatable, Sendable {
    let displayCoverPath: String
    let coverRevision: String
    let replacedDisplayCoverPath: String?
}

enum LibraryUserCoverError: Error, Equatable, CustomStringConvertible {
    case unsupportedFileExtension(String)
    case fileUnavailable(String)
    case fileTooLarge(actualBytes: Int64, maximumBytes: Int64)
    case unsupportedImageType(String)
    case invalidImageMetadata(String)
    case imageDecodeFailed(String)
    case imageContextCreationFailed
    case invalidCropRect
    case jpegDestinationCreationFailed
    case jpegEncodingFailed
    case jpegValidationFailed
    case publishFailed(String)
    case persistenceFailed(String)
    case invalidStoredCoverPath(String)
    case oldCoverRemovalFailed(String)
    case rollbackFailed(String)

    var description: String {
        switch self {
        case .unsupportedFileExtension(let fileExtension):
            "unsupported cover file extension: \(fileExtension)"
        case .fileUnavailable(let path):
            "cover source is unavailable: \(path)"
        case .fileTooLarge(let actualBytes, let maximumBytes):
            "cover source is too large: \(actualBytes) bytes (maximum \(maximumBytes))"
        case .unsupportedImageType(let type):
            "unsupported cover image type: \(type)"
        case .invalidImageMetadata(let path):
            "invalid cover image metadata: \(path)"
        case .imageDecodeFailed(let path):
            "failed to decode cover image: \(path)"
        case .imageContextCreationFailed:
            "failed to create the cover image context"
        case .invalidCropRect:
            "invalid 16:9 cover crop rectangle"
        case .jpegDestinationCreationFailed:
            "failed to create the user cover JPEG destination"
        case .jpegEncodingFailed:
            "failed to encode the user cover JPEG"
        case .jpegValidationFailed:
            "the encoded user cover JPEG failed validation"
        case .publishFailed(let message):
            "failed to publish the user cover: \(message)"
        case .persistenceFailed(let message):
            "failed to persist the user cover: \(message)"
        case .invalidStoredCoverPath(let path):
            "stored user cover path is outside the user cover directory: \(path)"
        case .oldCoverRemovalFailed(let message):
            "failed to remove the replaced user cover: \(message)"
        case .rollbackFailed(let message):
            "failed to restore the previous user cover: \(message)"
        }
    }
}

enum LibraryUserCoverProcessor {
    static let maximumSourceByteCount: Int64 = 20 * 1_024 * 1_024
    static let outputPixelWidth = 512
    static let outputPixelHeight = 288
    static let jpegCompressionQuality = 0.90
    static let aspectRatio = Double(outputPixelWidth) / Double(outputPixelHeight)
    static let supportedFilenameExtensions: Set<String> = ["jpg", "jpeg", "png", "gif"]

    private static let maximumDecodePixelDimension = 8_192

    static func validateSourceFile(at url: URL) throws {
        let fileExtension = url.pathExtension.lowercased()
        guard supportedFilenameExtensions.contains(fileExtension) else {
            throw LibraryUserCoverError.unsupportedFileExtension(fileExtension)
        }

        let resourceValues: URLResourceValues
        do {
            resourceValues = try url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
        } catch {
            throw LibraryUserCoverError.fileUnavailable(url.path)
        }
        guard resourceValues.isRegularFile == true,
              let fileSize = resourceValues.fileSize,
              fileSize > 0
        else {
            throw LibraryUserCoverError.fileUnavailable(url.path)
        }
        guard Int64(fileSize) <= maximumSourceByteCount else {
            throw LibraryUserCoverError.fileTooLarge(
                actualBytes: Int64(fileSize),
                maximumBytes: maximumSourceByteCount
            )
        }

        guard let source = CGImageSourceCreateWithURL(
            url as CFURL,
            [kCGImageSourceShouldCache: false] as CFDictionary
        ),
              let sourceTypeIdentifier = CGImageSourceGetType(source) as String?,
              let sourceType = UTType(sourceTypeIdentifier),
              [UTType.jpeg, .png, .gif].contains(where: { sourceType.conforms(to: $0) })
        else {
            throw LibraryUserCoverError.unsupportedImageType(url.pathExtension.lowercased())
        }
    }

    static func loadSource(at url: URL) throws -> LibraryUserCoverSource {
        try validateSourceFile(at: url)
        return try autoreleasepool {
            guard let source = CGImageSourceCreateWithURL(
                url as CFURL,
                [kCGImageSourceShouldCache: false] as CFDictionary
            ) else {
                throw LibraryUserCoverError.imageDecodeFailed(url.path)
            }
            guard let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil)
                as? [CFString: Any],
                  let width = (properties[kCGImagePropertyPixelWidth] as? NSNumber)?.intValue,
                  let height = (properties[kCGImagePropertyPixelHeight] as? NSNumber)?.intValue,
                  width > 0,
                  height > 0
            else {
                throw LibraryUserCoverError.invalidImageMetadata(url.path)
            }

            let decodeOptions: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: min(
                    maximumDecodePixelDimension,
                    max(width, height)
                ),
                kCGImageSourceShouldCacheImmediately: true
            ]
            guard let decodedImage = CGImageSourceCreateThumbnailAtIndex(
                source,
                0,
                decodeOptions as CFDictionary
            ) else {
                throw LibraryUserCoverError.imageDecodeFailed(url.path)
            }
            return LibraryUserCoverSource(image: try opaqueSRGBImage(from: decodedImage))
        }
    }

    static func jpegData(
        source: LibraryUserCoverSource,
        cropRect: CGRect
    ) throws -> Data {
        guard isValid(cropRect: cropRect, for: source.image) else {
            throw LibraryUserCoverError.invalidCropRect
        }
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                data: nil,
                width: outputPixelWidth,
                height: outputPixelHeight,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
              )
        else {
            throw LibraryUserCoverError.imageContextCreationFailed
        }

        context.setFillColor(gray: 1, alpha: 1)
        context.fill(
            CGRect(x: 0, y: 0, width: outputPixelWidth, height: outputPixelHeight)
        )
        context.interpolationQuality = .high
        let scaleX = CGFloat(outputPixelWidth) / cropRect.width
        let scaleY = CGFloat(outputPixelHeight) / cropRect.height
        context.draw(
            source.image,
            in: CGRect(
                x: -cropRect.minX * scaleX,
                y: -cropRect.minY * scaleY,
                width: CGFloat(source.image.width) * scaleX,
                height: CGFloat(source.image.height) * scaleY
            )
        )
        guard let outputImage = context.makeImage() else {
            throw LibraryUserCoverError.imageContextCreationFailed
        }

        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data,
            UTType.jpeg.identifier as CFString,
            1,
            nil
        ) else {
            throw LibraryUserCoverError.jpegDestinationCreationFailed
        }
        let properties: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: jpegCompressionQuality,
            kCGImagePropertyOrientation: 1
        ]
        CGImageDestinationAddImage(destination, outputImage, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else {
            throw LibraryUserCoverError.jpegEncodingFailed
        }
        let encodedData = data as Data
        try validateJPEGData(encodedData)
        return encodedData
    }

    private static func opaqueSRGBImage(from image: CGImage) throws -> CGImage {
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                data: nil,
                width: image.width,
                height: image.height,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
              )
        else {
            throw LibraryUserCoverError.imageContextCreationFailed
        }
        context.setFillColor(gray: 1, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: image.width, height: image.height))
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        guard let opaqueImage = context.makeImage() else {
            throw LibraryUserCoverError.imageContextCreationFailed
        }
        return opaqueImage
    }

    private static func isValid(cropRect: CGRect, for image: CGImage) -> Bool {
        let values = [
            cropRect.minX,
            cropRect.minY,
            cropRect.width,
            cropRect.height,
            cropRect.maxX,
            cropRect.maxY
        ]
        guard values.allSatisfy(\.isFinite),
              cropRect.minX >= 0,
              cropRect.minY >= 0,
              cropRect.width > 0,
              cropRect.height > 0,
              cropRect.maxX <= CGFloat(image.width),
              cropRect.maxY <= CGFloat(image.height)
        else {
            return false
        }
        return abs(Double(cropRect.width / cropRect.height) - aspectRatio) <= 0.001
    }

    private static func validateJPEGData(_ data: Data) throws {
        guard !data.isEmpty,
              let source = CGImageSourceCreateWithData(data as CFData, nil),
              CGImageSourceGetCount(source) == 1,
              CGImageSourceGetType(source) as String? == UTType.jpeg.identifier,
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil)
                as? [CFString: Any],
              (properties[kCGImagePropertyPixelWidth] as? NSNumber)?.intValue
                == outputPixelWidth,
              (properties[kCGImagePropertyPixelHeight] as? NSNumber)?.intValue
                == outputPixelHeight,
              ((properties[kCGImagePropertyOrientation] as? NSNumber)?.intValue ?? 1) == 1
        else {
            throw LibraryUserCoverError.jpegValidationFailed
        }
    }
}

actor LibraryUserCoverService {
    private let database: LibraryCoverDatabase
    private let userDisplayDirectory: URL
    private let imagePipeline: LibraryCoverImagePipeline
    private let fileManager: FileManager

    init(
        database: LibraryCoverDatabase,
        coverDirectory: URL,
        imagePipeline: LibraryCoverImagePipeline = .shared,
        fileManager: FileManager = .default
    ) {
        self.database = database
        self.userDisplayDirectory = coverDirectory
            .appendingPathComponent("User", isDirectory: true)
            .appendingPathComponent("Display", isDirectory: true)
            .appendingPathComponent(
                "v\(LibraryCoverDisplayProfileVersion.current)",
                isDirectory: true
            )
        self.imagePipeline = imagePipeline
        self.fileManager = fileManager
    }

    func save(
        source: LibraryUserCoverSource,
        cropRect: CGRect,
        target: LibraryUserCoverTarget
    ) async throws -> LibraryUserCoverSaveResult {
        let encodedData = try LibraryUserCoverProcessor.jpegData(
            source: source,
            cropRect: cropRect
        )
        let destinationURL = userDisplayDirectory
            .appendingPathComponent(UUID().uuidString.lowercased())
            .appendingPathExtension("jpg")

        do {
            try fileManager.createDirectory(
                at: userDisplayDirectory,
                withIntermediateDirectories: true
            )
            try encodedData.write(to: destinationURL, options: .atomic)
        } catch {
            throw LibraryUserCoverError.publishFailed(String(describing: error))
        }

        let previousCover: LibraryUserCover?
        let savedCover: LibraryUserCover
        do {
            previousCover = try storedCover(for: target)
            try persist(displayCoverPath: destinationURL.path, for: target)
            guard let persistedCover = try storedCover(for: target),
                  persistedCover.displayCoverPath == destinationURL.path
            else {
                try restore(previousCover: previousCover, for: target)
                throw LibraryUserCoverError.persistenceFailed(
                    "persisted cover could not be read back"
                )
            }
            savedCover = persistedCover
        } catch {
            try? fileManager.removeItem(at: destinationURL)
            throw LibraryUserCoverError.persistenceFailed(String(describing: error))
        }

        if let previousPath = previousCover?.displayCoverPath,
           previousPath != destinationURL.path {
            do {
                try removeReplacedCover(atPath: previousPath)
            } catch {
                do {
                    try restore(previousCover: previousCover, for: target)
                } catch {
                    throw LibraryUserCoverError.rollbackFailed(String(describing: error))
                }
                try? fileManager.removeItem(at: destinationURL)
                throw error
            }
            await imagePipeline.remove(path: previousPath)
        }

        return LibraryUserCoverSaveResult(
            displayCoverPath: destinationURL.path,
            coverRevision: savedCover.revision,
            replacedDisplayCoverPath: previousCover?.displayCoverPath
        )
    }

    private func storedCover(for target: LibraryUserCoverTarget) throws -> LibraryUserCover? {
        switch target {
        case .video(let path):
            try database.libraryUserVideoCover(forVideoFile: URL.fromMediaPath(path))
        case .folder(let path):
            try database.libraryUserFolderCover(folderPath: path)
        }
    }

    private func persist(
        displayCoverPath: String,
        for target: LibraryUserCoverTarget
    ) throws {
        switch target {
        case .video(let path):
            try database.upsertLibraryUserVideoCover(
                forVideoFile: URL.fromMediaPath(path),
                displayCoverPath: displayCoverPath
            )
        case .folder(let path):
            try database.upsertLibraryUserFolderCover(
                folderPath: path,
                displayCoverPath: displayCoverPath
            )
        }
    }

    private func restore(
        previousCover: LibraryUserCover?,
        for target: LibraryUserCoverTarget
    ) throws {
        if let previousCover {
            try persist(displayCoverPath: previousCover.displayCoverPath, for: target)
            return
        }

        switch target {
        case .video(let path):
            try database.deleteLibraryUserVideoCover(forVideoFile: URL.fromMediaPath(path))
        case .folder(let path):
            try database.deleteLibraryUserFolderCover(folderPath: path)
        }
    }

    private func removeReplacedCover(atPath path: String) throws {
        let oldURL = URL(fileURLWithPath: path).standardizedFileURL
        let directory = userDisplayDirectory.standardizedFileURL
        guard oldURL.deletingLastPathComponent() == directory else {
            throw LibraryUserCoverError.invalidStoredCoverPath(path)
        }
        guard fileManager.fileExists(atPath: oldURL.path) else {
            return
        }
        do {
            try fileManager.removeItem(at: oldURL)
        } catch {
            throw LibraryUserCoverError.oldCoverRemovalFailed(String(describing: error))
        }
    }
}
