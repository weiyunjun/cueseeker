import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
import CueSeekerCore
@testable import CueSeekerPlayback

@Test
func libraryCoverDisplayProfileFitsSourceInsideFixedBounds() throws {
    let profile = LibraryCoverDisplayProfile.current
    #expect(profile.version == 1)
    #expect(profile.maximumPixelWidth == 512)
    #expect(profile.maximumPixelHeight == 288)
    #expect(profile.jpegCompressionQuality == 0.90)
    #expect(!profile.allowsUpscaling)

    #expect(try fittedCoverSize(width: 3_000, height: 500) == .init(width: 512, height: 85))
    #expect(try fittedCoverSize(width: 1_920, height: 1_080) == .init(width: 512, height: 288))
    #expect(try fittedCoverSize(width: 1_440, height: 1_080) == .init(width: 384, height: 288))
    #expect(try fittedCoverSize(width: 500, height: 3_000) == .init(width: 48, height: 288))
    #expect(try fittedCoverSize(width: 100, height: 50) == .init(width: 100, height: 50))
    #expect(
        try fittedCoverSize(width: 1_200, height: 800, orientation: 6)
            == .init(width: 192, height: 288)
    )
    #expect(throws: LibraryCoverDisplayRenditionError.self) {
        try fittedCoverSize(width: 0, height: 100)
    }
}

@Test
func libraryCoverDisplayGeneratorWritesValidatedJPEGsWithoutUpscaling() throws {
    let directory = temporaryCoverTestDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

    let cases: [(name: String, width: Int, height: Int, orientation: UInt32, expected: LibraryCoverDisplayPixelSize)] = [
        ("wide", 3_000, 500, 1, .init(width: 512, height: 85)),
        ("sixteen-nine", 1_920, 1_080, 1, .init(width: 512, height: 288)),
        ("four-three", 1_440, 1_080, 1, .init(width: 384, height: 288)),
        ("tall", 500, 3_000, 1, .init(width: 48, height: 288)),
        ("small", 100, 50, 1, .init(width: 100, height: 50)),
        ("rotated", 1_200, 800, 6, .init(width: 192, height: 288))
    ]

    for testCase in cases {
        let masterURL = directory.appendingPathComponent("\(testCase.name)-master.jpg")
        let displayURL = directory.appendingPathComponent("\(testCase.name)-display.jpg")
        try writeTestJPEG(
            width: testCase.width,
            height: testCase.height,
            orientation: testCase.orientation,
            to: masterURL
        )

        let result = try LibraryCoverDisplayRenditionGenerator().generate(
            masterURL: masterURL,
            destinationURL: displayURL
        )
        #expect(result.pixelWidth == testCase.expected.width)
        #expect(result.pixelHeight == testCase.expected.height)
        #expect(result.byteCount > 0)

        let metadata = try imageMetadata(at: displayURL)
        #expect(metadata.type == UTType.jpeg.identifier)
        #expect(metadata.width == testCase.expected.width)
        #expect(metadata.height == testCase.expected.height)
        #expect(metadata.orientation == 1)
        #expect(metadata.width <= LibraryCoverDisplayProfile.current.maximumPixelWidth)
        #expect(metadata.height <= LibraryCoverDisplayProfile.current.maximumPixelHeight)
    }
}

@Test
func failedLibraryCoverDisplayGenerationPreservesExistingDestination() throws {
    let directory = temporaryCoverTestDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

    let masterURL = directory.appendingPathComponent("corrupt-master.jpg")
    let displayURL = directory.appendingPathComponent("existing-display.jpg")
    let existingData = Data("existing-display-must-survive".utf8)
    try Data("not-an-image".utf8).write(to: masterURL)
    try existingData.write(to: displayURL)

    #expect(throws: LibraryCoverDisplayRenditionError.self) {
        try LibraryCoverDisplayRenditionGenerator().generate(
            masterURL: masterURL,
            destinationURL: displayURL
        )
    }
    #expect(try Data(contentsOf: displayURL) == existingData)
}

@Test
func invalidatedLibraryCoverDisplayCommitCannotPublishStaleFile() throws {
    let directory = temporaryCoverTestDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

    let masterURL = directory.appendingPathComponent("master.jpg")
    let displayURL = directory.appendingPathComponent("display.jpg")
    try writeTestJPEG(width: 1_920, height: 1_080, orientation: 1, to: masterURL)
    let encodedRendition = try LibraryCoverDisplayRenditionGenerator().encode(masterURL: masterURL)

    let gate = LibraryCoverDisplayRenditionCommitGate()
    let staleToken = gate.beginGeneration()
    gate.invalidateCurrentGeneration()
    let staleCommit = try staleToken.commit {
        try LibraryCoverDisplayRenditionGenerator.publish(
            encodedRendition.data,
            to: displayURL
        )
        return true
    }
    #expect(staleCommit == nil)
    #expect(!FileManager.default.fileExists(atPath: displayURL.path))

    let currentToken = gate.beginGeneration()
    let currentCommit = try currentToken.commit {
        try LibraryCoverDisplayRenditionGenerator.publish(
            encodedRendition.data,
            to: displayURL
        )
        return true
    }
    #expect(currentCommit == true)
    #expect(FileManager.default.fileExists(atPath: displayURL.path))
}

@Test
func libraryCoverDisplayBackfillUsesMasterAndIsIdempotent() async throws {
    let directory = temporaryCoverTestDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let mediaDirectory = directory.appendingPathComponent("Media", isDirectory: true)
    let databaseURL = directory.appendingPathComponent("CueSeeker.sqlite")
    let coverDirectory = directory.appendingPathComponent("Covers", isDirectory: true)
    let masterURL = coverDirectory
        .appendingPathComponent("Videos", isDirectory: true)
        .appendingPathComponent("legacy-master.jpg")
    try FileManager.default.createDirectory(
        at: mediaDirectory,
        withIntermediateDirectories: true
    )
    try FileManager.default.createDirectory(
        at: masterURL.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )

    let subtitleURL = mediaDirectory.appendingPathComponent("Episode 1.srt")
    let videoURL = mediaDirectory.appendingPathComponent("Episode 1.mkv")
    try Data("subtitle".utf8).write(to: subtitleURL)
    try Data("not-a-video-and-never-read".utf8).write(to: videoURL)
    try writeTestJPEG(width: 1_440, height: 1_080, orientation: 1, to: masterURL)
    let masterDataBefore = try Data(contentsOf: masterURL)
    let masterModificationDateBefore = try modificationDate(at: masterURL)

    try DatabaseBootstrap.prepare(at: databaseURL)
    let database = try SubtitleDatabase(path: databaseURL)
    let coverDatabase = try LibraryCoverDatabase(path: databaseURL)
    try database.replaceEntries(
        subtitleFile: subtitleURL,
        videoFile: videoURL,
        entries: [
            SubtitleEntry(
                sequenceNumber: 1,
                startTimecode: "00:00:01,000",
                endTimecode: "00:00:02,000",
                startMilliseconds: 1_000,
                endMilliseconds: 2_000,
                text: "display backfill"
            )
        ]
    )
    let video = try #require(coverDatabase.libraryCoverEligibleVideos(under: [mediaDirectory]).first)
    try coverDatabase.upsertLibraryVideoCover(
        videoFileID: video.videoFileID,
        masterCoverPath: masterURL.path,
        sourceTimeMilliseconds: 1_000,
        score: 80,
        algorithmVersion: 1,
        generatedFileSize: video.fileSize,
        generatedDuration: video.duration,
        status: .generated,
        errorMessage: nil
    )

    let indexer = LibraryCoverDisplayRenditionIndexer(
        configuration: .init(coverDirectory: coverDirectory, maxConcurrentRenditions: 2)
    )
    let firstResult = try await indexer.backfillDisplayRenditions(
        under: [mediaDirectory],
        into: coverDatabase
    )
    #expect(firstResult.eligibleMasterCoverCount == 1)
    #expect(firstResult.skippedFreshDisplayCoverCount == 0)
    #expect(firstResult.generatedDisplayCoverCount == 1)
    #expect(firstResult.clearedInvalidDisplayCoverCount == 0)
    #expect(firstResult.failedDisplayCoverCount == 0)
    #expect(try Data(contentsOf: masterURL) == masterDataBefore)
    #expect(try modificationDate(at: masterURL) == masterModificationDateBefore)

    let storedCover = try #require(
        try coverDatabase.libraryVideoCover(forVideoFileID: video.videoFileID)
    )
    #expect(storedCover.masterCoverPath == masterURL.path)
    #expect(storedCover.displayProfileVersion == LibraryCoverDisplayProfile.current.version)
    let displayPath = try #require(storedCover.displayCoverPath)
    let displayURL = URL(fileURLWithPath: displayPath)
    let displayMetadata = try imageMetadata(at: displayURL)
    #expect(displayMetadata.type == UTType.jpeg.identifier)
    #expect(displayMetadata.width == 384)
    #expect(displayMetadata.height == 288)
    let displayModificationDateBefore = try modificationDate(at: displayURL)

    let secondResult = try await indexer.backfillDisplayRenditions(
        under: [mediaDirectory],
        into: coverDatabase
    )
    #expect(secondResult.eligibleMasterCoverCount == 1)
    #expect(secondResult.skippedFreshDisplayCoverCount == 1)
    #expect(secondResult.generatedDisplayCoverCount == 0)
    #expect(secondResult.clearedInvalidDisplayCoverCount == 0)
    #expect(secondResult.failedDisplayCoverCount == 0)
    #expect(try modificationDate(at: displayURL) == displayModificationDateBefore)

    try FileManager.default.removeItem(at: displayURL)
    try FileManager.default.removeItem(at: masterURL)
    let missingFilesResult = try await indexer.backfillDisplayRenditions(
        under: [mediaDirectory],
        into: coverDatabase
    )
    #expect(missingFilesResult.eligibleMasterCoverCount == 1)
    #expect(missingFilesResult.generatedDisplayCoverCount == 0)
    #expect(missingFilesResult.clearedInvalidDisplayCoverCount == 1)
    #expect(missingFilesResult.failedDisplayCoverCount == 1)
    let clearedCover = try #require(
        try coverDatabase.libraryVideoCover(forVideoFileID: video.videoFileID)
    )
    #expect(clearedCover.displayCoverPath == nil)
    #expect(clearedCover.displayProfileVersion == nil)
}

private func fittedCoverSize(
    width: Int,
    height: Int,
    orientation: UInt32 = 1
) throws -> LibraryCoverDisplayPixelSize {
    try LibraryCoverDisplayRenditionGenerator.fittedPixelSize(
        sourceWidth: width,
        sourceHeight: height,
        orientation: orientation
    )
}

private func temporaryCoverTestDirectory() -> URL {
    FileManager.default.temporaryDirectory
        .appendingPathComponent("CueSeekerCoverDisplayTests-\(UUID().uuidString)", isDirectory: true)
}

private func writeTestJPEG(
    width: Int,
    height: Int,
    orientation: UInt32,
    to url: URL
) throws {
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
    context.setFillColor(red: 0.08, green: 0.24, blue: 0.72, alpha: 1)
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    context.setFillColor(red: 0.92, green: 0.35, blue: 0.12, alpha: 1)
    context.fill(CGRect(x: 0, y: 0, width: max(1, width / 4), height: max(1, height / 4)))
    let image = try #require(context.makeImage())

    guard let destination = CGImageDestinationCreateWithURL(
        url as CFURL,
        UTType.jpeg.identifier as CFString,
        1,
        nil
    ) else {
        throw CoverDisplayTestError.destinationCreationFailed
    }
    let properties: [CFString: Any] = [
        kCGImageDestinationLossyCompressionQuality: 0.95,
        kCGImagePropertyOrientation: orientation
    ]
    CGImageDestinationAddImage(destination, image, properties as CFDictionary)
    guard CGImageDestinationFinalize(destination) else {
        throw CoverDisplayTestError.encodingFailed
    }
}

private func imageMetadata(
    at url: URL
) throws -> (type: String, width: Int, height: Int, orientation: Int) {
    let source = try #require(CGImageSourceCreateWithURL(url as CFURL, nil))
    let type = try #require(CGImageSourceGetType(source) as String?)
    let properties = try #require(
        CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
    )
    let width = try #require((properties[kCGImagePropertyPixelWidth] as? NSNumber)?.intValue)
    let height = try #require((properties[kCGImagePropertyPixelHeight] as? NSNumber)?.intValue)
    let orientation = (properties[kCGImagePropertyOrientation] as? NSNumber)?.intValue ?? 1
    return (type, width, height, orientation)
}

private func modificationDate(at url: URL) throws -> Date {
    let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
    return try #require(attributes[.modificationDate] as? Date)
}

private enum CoverDisplayTestError: Error {
    case destinationCreationFailed
    case encodingFailed
}
