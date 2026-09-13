import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
import CueSeekerCore
@testable import CueSeekerApp

@Test
func libraryUserCoverProcessorUsesBinaryTwentyMegabyteLimit() throws {
    #expect(LibraryUserCoverProcessor.maximumSourceByteCount == 20 * 1_024 * 1_024)

    let directory = libraryUserCoverTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let oversizedURL = directory.appendingPathComponent("oversized.png")
    try Data(count: Int(LibraryUserCoverProcessor.maximumSourceByteCount) + 1)
        .write(to: oversizedURL)

    #expect(throws: LibraryUserCoverError.fileTooLarge(
        actualBytes: LibraryUserCoverProcessor.maximumSourceByteCount + 1,
        maximumBytes: LibraryUserCoverProcessor.maximumSourceByteCount
    )) {
        try LibraryUserCoverProcessor.validateSourceFile(at: oversizedURL)
    }
}

@Test
func libraryUserCoverProcessorAcceptsSupportedTypesAndUsesGIFFirstFrame() throws {
    let directory = libraryUserCoverTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

    let jpegURL = directory.appendingPathComponent("cover.jpeg")
    let pngURL = directory.appendingPathComponent("cover.png")
    let gifURL = directory.appendingPathComponent("cover.gif")
    try writeLibraryUserCoverImage(
        try makeLibraryUserCoverTestImage(red: 0.2, green: 0.4, blue: 0.8, alpha: 1),
        type: .jpeg,
        to: jpegURL
    )
    try writeLibraryUserCoverImage(
        try makeLibraryUserCoverTestImage(red: 1, green: 0, blue: 0, alpha: 0.5),
        type: .png,
        to: pngURL
    )
    try writeLibraryUserCoverGIF(
        first: try makeLibraryUserCoverTestImage(red: 1, green: 0, blue: 0, alpha: 1),
        second: try makeLibraryUserCoverTestImage(red: 0, green: 0, blue: 1, alpha: 1),
        to: gifURL
    )

    try LibraryUserCoverProcessor.validateSourceFile(at: jpegURL)
    try LibraryUserCoverProcessor.validateSourceFile(at: pngURL)
    try LibraryUserCoverProcessor.validateSourceFile(at: gifURL)

    let transparentPNG = try LibraryUserCoverProcessor.loadSource(at: pngURL)
    let mattePixel = try libraryUserCoverPixel(in: transparentPNG.image)
    #expect(mattePixel.red >= 245)
    #expect((115...140).contains(mattePixel.green))
    #expect((115...140).contains(mattePixel.blue))
    #expect(mattePixel.alpha == 255)

    let gifFirstFrame = try LibraryUserCoverProcessor.loadSource(at: gifURL)
    let gifPixel = try libraryUserCoverPixel(in: gifFirstFrame.image)
    #expect(gifPixel.red >= 245)
    #expect(gifPixel.green <= 10)
    #expect(gifPixel.blue <= 10)

    let unsupportedURL = directory.appendingPathComponent("cover.webp")
    try Data([0x00]).write(to: unsupportedURL)
    #expect(throws: LibraryUserCoverError.unsupportedFileExtension("webp")) {
        try LibraryUserCoverProcessor.validateSourceFile(at: unsupportedURL)
    }
}

@Test
func libraryUserCoverProcessorWritesExactDisplayJPEG() throws {
    let image = try makeLibraryUserCoverTestImage(
        width: 1_600,
        height: 900,
        red: 0.1,
        green: 0.6,
        blue: 0.3,
        alpha: 1
    )
    let source = LibraryUserCoverSource(image: image)
    let data = try LibraryUserCoverProcessor.jpegData(
        source: source,
        cropRect: CGRect(x: 0, y: 0, width: 1_600, height: 900)
    )

    let encodedSource = try #require(CGImageSourceCreateWithData(data as CFData, nil))
    #expect(CGImageSourceGetType(encodedSource) as String? == UTType.jpeg.identifier)
    let properties = try #require(
        CGImageSourceCopyPropertiesAtIndex(encodedSource, 0, nil) as? [CFString: Any]
    )
    #expect((properties[kCGImagePropertyPixelWidth] as? NSNumber)?.intValue == 512)
    #expect((properties[kCGImagePropertyPixelHeight] as? NSNumber)?.intValue == 288)

    #expect(throws: LibraryUserCoverError.invalidCropRect) {
        try LibraryUserCoverProcessor.jpegData(
            source: source,
            cropRect: CGRect(x: 0, y: 0, width: 800, height: 800)
        )
    }
}

@Test
func libraryUserCoverServiceReplacesFileAndInvalidatesOnlyOldCache() async throws {
    let directory = libraryUserCoverTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let databaseURL = directory.appendingPathComponent("test.sqlite")
    try DatabaseBootstrap.prepare(at: databaseURL)
    let database = try IndexingDatabase(path: databaseURL)
    let coverDatabase = try LibraryCoverDatabase(path: databaseURL)
    let videoFile = URL(fileURLWithPath: "/Media/Show/Episode 1.mkv")
    try database.replaceEntries(
        subtitleFile: URL(fileURLWithPath: "/Media/Show/Episode 1.srt"),
        videoFile: videoFile,
        entries: [libraryUserCoverDatabaseEntry()]
    )

    let pipeline = LibraryCoverImagePipeline(
        configuration: .init(
            costLimitBytes: 16 * 1_024 * 1_024,
            countLimit: 64,
            maxConcurrentDecodes: 2
        )
    )
    let service = LibraryUserCoverService(
        database: coverDatabase,
        coverDirectory: directory.appendingPathComponent("Covers"),
        imagePipeline: pipeline
    )
    let source = LibraryUserCoverSource(
        image: try makeLibraryUserCoverTestImage(
            width: 1_600,
            height: 900,
            red: 0.2,
            green: 0.5,
            blue: 0.8,
            alpha: 1
        )
    )
    let cropRect = CGRect(x: 0, y: 0, width: 1_600, height: 900)

    let first = try await service.save(
        source: source,
        cropRect: cropRect,
        target: .video(path: videoFile.path)
    )
    #expect(FileManager.default.fileExists(atPath: first.displayCoverPath))
    let firstCover = try #require(try coverDatabase.libraryUserVideoCover(forVideoFile: videoFile))
    #expect(first.coverRevision == firstCover.revision)
    let firstKey = LibraryCoverImageKey(
        path: first.displayCoverPath,
        revision: firstCover.revision
    )
    #expect(try await pipeline.image(for: firstKey) != nil)

    let retainedURL = directory.appendingPathComponent("retained.jpg")
    try Data(contentsOf: URL(fileURLWithPath: first.displayCoverPath)).write(to: retainedURL)
    let retainedKey = LibraryCoverImageKey(path: retainedURL.path, revision: "retained")
    #expect(try await pipeline.image(for: retainedKey) != nil)

    let second = try await service.save(
        source: source,
        cropRect: cropRect,
        target: .video(path: videoFile.path)
    )
    #expect(second.replacedDisplayCoverPath == first.displayCoverPath)
    #expect(!FileManager.default.fileExists(atPath: first.displayCoverPath))
    #expect(FileManager.default.fileExists(atPath: second.displayCoverPath))
    let secondCover = try #require(try coverDatabase.libraryUserVideoCover(forVideoFile: videoFile))
    #expect(secondCover.displayCoverPath == second.displayCoverPath)
    #expect(secondCover.revision == second.coverRevision)
    let cachedKeys = await pipeline.diagnostics().cachedKeys
    #expect(!cachedKeys.contains(firstKey))
    #expect(cachedKeys.contains(retainedKey))
}

@Test
func libraryUserCoverServiceRestoresOldCoverWhenOldFileCannotBeSafelyRemoved() async throws {
    let directory = libraryUserCoverTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let databaseURL = directory.appendingPathComponent("test.sqlite")
    try DatabaseBootstrap.prepare(at: databaseURL)
    let database = try IndexingDatabase(path: databaseURL)
    let coverDatabase = try LibraryCoverDatabase(path: databaseURL)
    let videoFile = URL(fileURLWithPath: "/Media/Show/Episode 1.mkv")
    try database.replaceEntries(
        subtitleFile: URL(fileURLWithPath: "/Media/Show/Episode 1.srt"),
        videoFile: videoFile,
        entries: [libraryUserCoverDatabaseEntry()]
    )
    let externalOldURL = directory.appendingPathComponent("must-remain.jpg")
    try Data([0x01]).write(to: externalOldURL)
    try coverDatabase.upsertLibraryUserVideoCover(
        forVideoFile: videoFile,
        displayCoverPath: externalOldURL.path
    )

    let service = LibraryUserCoverService(
        database: coverDatabase,
        coverDirectory: directory.appendingPathComponent("Covers")
    )
    let source = LibraryUserCoverSource(
        image: try makeLibraryUserCoverTestImage(
            width: 1_600,
            height: 900,
            red: 0.3,
            green: 0.4,
            blue: 0.5,
            alpha: 1
        )
    )

    await #expect(throws: LibraryUserCoverError.self) {
        try await service.save(
            source: source,
            cropRect: CGRect(x: 0, y: 0, width: 1_600, height: 900),
            target: .video(path: videoFile.path)
        )
    }
    #expect(FileManager.default.fileExists(atPath: externalOldURL.path))
    #expect(
        try coverDatabase.libraryUserVideoCover(forVideoFile: videoFile)?.displayCoverPath
            == externalOldURL.path
    )
}

@Test
func excerptListCoverStoragePublishesAndSafelyRemovesCroppedCovers() async throws {
    let directory = libraryUserCoverTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let service = ExcerptListCoverStorage(coverDirectory: directory)
    let source = LibraryUserCoverSource(
        image: try makeLibraryUserCoverTestImage(
            width: 1_600,
            height: 900,
            red: 0.3,
            green: 0.5,
            blue: 0.7,
            alpha: 1
        )
    )

    let path = try await service.publish(
        source: source,
        cropRect: CGRect(x: 0, y: 0, width: 1_600, height: 900)
    )
    #expect(FileManager.default.fileExists(atPath: path))
    #expect(path.contains("/Shiori/Display/v1/"))

    try await service.remove(path: path)
    #expect(!FileManager.default.fileExists(atPath: path))

    let externalPath = directory.appendingPathComponent("external.jpg").path
    await #expect(throws: LibraryUserCoverError.invalidStoredCoverPath(externalPath)) {
        try await service.remove(path: externalPath)
    }
}

private func libraryUserCoverTemporaryDirectory() -> URL {
    FileManager.default.temporaryDirectory
        .appendingPathComponent("CueSeekerLibraryUserCoverTests-\(UUID().uuidString)")
}

private func makeLibraryUserCoverTestImage(
    width: Int = 8,
    height: Int = 8,
    red: CGFloat,
    green: CGFloat,
    blue: CGFloat,
    alpha: CGFloat
) throws -> CGImage {
    let colorSpace = try #require(CGColorSpace(name: CGColorSpace.sRGB))
    let context = try #require(
        CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
    )
    context.clear(CGRect(x: 0, y: 0, width: width, height: height))
    context.setFillColor(red: red, green: green, blue: blue, alpha: alpha)
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    return try #require(context.makeImage())
}

private func writeLibraryUserCoverImage(
    _ image: CGImage,
    type: UTType,
    to url: URL
) throws {
    let destination = try #require(
        CGImageDestinationCreateWithURL(url as CFURL, type.identifier as CFString, 1, nil)
    )
    CGImageDestinationAddImage(destination, image, nil)
    #expect(CGImageDestinationFinalize(destination))
}

private func writeLibraryUserCoverGIF(
    first: CGImage,
    second: CGImage,
    to url: URL
) throws {
    let destination = try #require(
        CGImageDestinationCreateWithURL(url as CFURL, UTType.gif.identifier as CFString, 2, nil)
    )
    CGImageDestinationAddImage(destination, first, nil)
    CGImageDestinationAddImage(destination, second, nil)
    #expect(CGImageDestinationFinalize(destination))
}

private func libraryUserCoverPixel(
    in image: CGImage
) throws -> (red: UInt8, green: UInt8, blue: UInt8, alpha: UInt8) {
    var bytes = [UInt8](repeating: 0, count: 4)
    let colorSpace = try #require(CGColorSpace(name: CGColorSpace.sRGB))
    let context = try #require(
        CGContext(
            data: &bytes,
            width: 1,
            height: 1,
            bitsPerComponent: 8,
            bytesPerRow: 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
    )
    context.interpolationQuality = .none
    context.draw(image, in: CGRect(x: 0, y: 0, width: 1, height: 1))
    return (bytes[0], bytes[1], bytes[2], bytes[3])
}

private func libraryUserCoverDatabaseEntry() -> SubtitleEntry {
    SubtitleEntry(
        sequenceNumber: 1,
        startTimecode: "00:00:00,000",
        endTimecode: "00:00:01,000",
        startMilliseconds: 0,
        endMilliseconds: 1_000,
        text: "Library user cover"
    )
}
