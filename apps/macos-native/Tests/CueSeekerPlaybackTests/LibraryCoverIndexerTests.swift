import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
import CueSeekerCore
@testable import CueSeekerPlayback

@Test
func fallbackCoverRetriesWithoutIndexedContentChanges() async throws {
    let fixture = try makeAutomaticCoverFixture()
    defer { try? FileManager.default.removeItem(at: fixture.root) }
    let sourceJPEG = fixture.root.appendingPathComponent("source.jpg")
    try writeAutomaticCoverTestJPEG(to: sourceJPEG)
    let ffmpeg = try writeAutomaticCoverFFmpeg(
        in: fixture.root,
        sourceJPEG: sourceJPEG
    )
    let video = try #require(
        fixture.coverDatabase.libraryCoverEligibleVideos(
            under: [fixture.mediaDirectory]
        ).first
    )
    try fixture.coverDatabase.upsertLibraryVideoCover(
        videoFileID: video.videoFileID,
        masterCoverPath: fixture.coverDirectory
            .appendingPathComponent("failed.jpg").path,
        sourceTimeMilliseconds: 0,
        score: nil,
        algorithmVersion: LibraryCoverIndexer.algorithmVersion,
        generatedFileSize: video.fileSize,
        generatedDuration: video.duration,
        status: .failed,
        errorMessage: "decoder unavailable"
    )

    let result = try await makeAutomaticCoverIndexer(
        coverDirectory: fixture.coverDirectory,
        ffmpeg: ffmpeg
    ).indexCovers(
        under: fixture.mediaDirectory,
        affectedVideoPaths: [],
        affectedFolderPaths: [],
        into: fixture.coverDatabase
    )

    #expect(result.generatedCoverCount == 1)
    #expect(result.failedCoverCount == 0)
    #expect(result.generatedDisplayCoverCount == 1)
    let stored = try #require(
        try fixture.coverDatabase.libraryVideoCover(
            forVideoFileID: video.videoFileID
        )
    )
    #expect(stored.status == .generated)
    #expect(FileManager.default.fileExists(atPath: stored.masterCoverPath))
    #expect(stored.displayProfileVersion == LibraryCoverDisplayProfile.current.version)
    #expect(
        stored.displayCoverPath.map(FileManager.default.fileExists(atPath:))
            == true
    )
}

@Test
func userVideoCoverPreventsAutomaticCoverModification() async throws {
    let fixture = try makeAutomaticCoverFixture()
    defer { try? FileManager.default.removeItem(at: fixture.root) }
    let ffmpeg = try writeFailingAutomaticCoverFFmpeg(in: fixture.root)
    let video = try #require(
        fixture.coverDatabase.libraryCoverEligibleVideos(
            under: [fixture.mediaDirectory]
        ).first
    )
    let masterURL = fixture.coverDirectory.appendingPathComponent("old-master.jpg")
    let displayURL = fixture.coverDirectory.appendingPathComponent("old-display.jpg")
    let userURL = fixture.coverDirectory.appendingPathComponent("user.jpg")
    try Data("old-master".utf8).write(to: masterURL)
    try Data("old-display".utf8).write(to: displayURL)
    try Data("user".utf8).write(to: userURL)
    try fixture.coverDatabase.upsertLibraryVideoCover(
        videoFileID: video.videoFileID,
        masterCoverPath: masterURL.path,
        displayCoverPath: displayURL.path,
        displayProfileVersion: LibraryCoverDisplayProfile.current.version,
        sourceTimeMilliseconds: 1_000,
        score: 75,
        algorithmVersion: LibraryCoverIndexer.algorithmVersion,
        generatedFileSize: video.fileSize,
        generatedDuration: video.duration,
        status: .generated,
        errorMessage: nil
    )
    try fixture.coverDatabase.upsertLibraryUserVideoCover(
        forVideoFile: fixture.videoURL,
        displayCoverPath: userURL.path
    )
    let coverBefore = try #require(
        try fixture.coverDatabase.libraryVideoCover(
            forVideoFileID: video.videoFileID
        )
    )

    let result = try await makeAutomaticCoverIndexer(
        coverDirectory: fixture.coverDirectory,
        ffmpeg: ffmpeg
    ).indexCovers(
        under: fixture.mediaDirectory,
        affectedVideoPaths: [fixture.videoURL.path],
        affectedFolderPaths: [fixture.mediaDirectory.path],
        into: fixture.coverDatabase
    )

    #expect(result.generatedCoverCount == 0)
    #expect(result.failedCoverCount == 0)
    #expect(result.generatedDisplayCoverCount == 0)
    #expect(
        try fixture.coverDatabase.libraryVideoCover(
            forVideoFileID: video.videoFileID
        ) == coverBefore
    )
}

@Test
func failedAutomaticCoverRefreshPreservesPreviousAutomaticCover() async throws {
    let fixture = try makeAutomaticCoverFixture()
    defer { try? FileManager.default.removeItem(at: fixture.root) }
    let ffmpeg = try writeFailingAutomaticCoverFFmpeg(in: fixture.root)
    let video = try #require(
        fixture.coverDatabase.libraryCoverEligibleVideos(
            under: [fixture.mediaDirectory]
        ).first
    )
    let masterURL = fixture.coverDirectory.appendingPathComponent("old-master.jpg")
    let displayURL = fixture.coverDirectory.appendingPathComponent("old-display.jpg")
    let oldMasterData = Data("old-master".utf8)
    let oldDisplayData = Data("old-display".utf8)
    try oldMasterData.write(to: masterURL)
    try oldDisplayData.write(to: displayURL)
    try fixture.coverDatabase.upsertLibraryVideoCover(
        videoFileID: video.videoFileID,
        masterCoverPath: masterURL.path,
        displayCoverPath: displayURL.path,
        displayProfileVersion: LibraryCoverDisplayProfile.current.version,
        sourceTimeMilliseconds: 1_000,
        score: 75,
        algorithmVersion: LibraryCoverIndexer.algorithmVersion,
        generatedFileSize: video.fileSize,
        generatedDuration: video.duration,
        status: .generated,
        errorMessage: nil
    )
    try fixture.coverDatabase.upsertLibraryFolderCover(
        folderPath: video.folderPath,
        masterCoverPath: masterURL.path,
        sourceVideoFileID: video.videoFileID
    )
    let coverBefore = try #require(
        try fixture.coverDatabase.libraryVideoCover(
            forVideoFileID: video.videoFileID
        )
    )

    let result = try await makeAutomaticCoverIndexer(
        coverDirectory: fixture.coverDirectory,
        ffmpeg: ffmpeg
    ).indexCovers(
        under: fixture.mediaDirectory,
        affectedVideoPaths: [fixture.videoURL.path],
        affectedFolderPaths: [fixture.mediaDirectory.path],
        into: fixture.coverDatabase
    )

    #expect(result.generatedCoverCount == 0)
    #expect(result.failedCoverCount == 1)
    #expect(
        try fixture.coverDatabase.libraryVideoCover(
            forVideoFileID: video.videoFileID
        ) == coverBefore
    )
    #expect(try Data(contentsOf: masterURL) == oldMasterData)
    #expect(try Data(contentsOf: displayURL) == oldDisplayData)
    #expect(
        try fixture.coverDatabase.libraryFolderCover(
            folderPath: video.folderPath
        )?.masterCoverPath == masterURL.path
    )
}

@Test
func unchangedAutomaticCoverRemainsFreshDuringFallbackRetryScan() async throws {
    let fixture = try makeAutomaticCoverFixture()
    defer { try? FileManager.default.removeItem(at: fixture.root) }
    let ffmpeg = try writeFailingAutomaticCoverFFmpeg(in: fixture.root)
    let video = try #require(
        fixture.coverDatabase.libraryCoverEligibleVideos(
            under: [fixture.mediaDirectory]
        ).first
    )
    let masterURL = fixture.coverDirectory.appendingPathComponent("master.jpg")
    let displayURL = fixture.coverDirectory.appendingPathComponent("display.jpg")
    try Data("master".utf8).write(to: masterURL)
    try Data("display".utf8).write(to: displayURL)
    try fixture.coverDatabase.upsertLibraryVideoCover(
        videoFileID: video.videoFileID,
        masterCoverPath: masterURL.path,
        displayCoverPath: displayURL.path,
        displayProfileVersion: LibraryCoverDisplayProfile.current.version,
        sourceTimeMilliseconds: 1_000,
        score: 75,
        algorithmVersion: LibraryCoverIndexer.algorithmVersion,
        generatedFileSize: video.fileSize,
        generatedDuration: video.duration,
        status: .generated,
        errorMessage: nil
    )

    let result = try await makeAutomaticCoverIndexer(
        coverDirectory: fixture.coverDirectory,
        ffmpeg: ffmpeg
    ).indexCovers(
        under: fixture.mediaDirectory,
        affectedVideoPaths: [],
        affectedFolderPaths: [],
        into: fixture.coverDatabase
    )

    #expect(result.skippedFreshCoverCount == 1)
    #expect(result.generatedCoverCount == 0)
    #expect(result.failedCoverCount == 0)
}

private struct AutomaticCoverFixture {
    let root: URL
    let mediaDirectory: URL
    let coverDirectory: URL
    let videoURL: URL
    let coverDatabase: LibraryCoverDatabase
}

private func makeAutomaticCoverFixture() throws -> AutomaticCoverFixture {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(
        "CueSeekerAutomaticCoverTests-\(UUID().uuidString)",
        isDirectory: true
    )
    let mediaDirectory = root.appendingPathComponent("Media", isDirectory: true)
    let coverDirectory = root.appendingPathComponent("Covers", isDirectory: true)
    let databaseURL = root.appendingPathComponent("CueSeeker.sqlite")
    let subtitleURL = mediaDirectory.appendingPathComponent("Episode 1.srt")
    let videoURL = mediaDirectory.appendingPathComponent("Episode 1.mkv")
    try FileManager.default.createDirectory(
        at: mediaDirectory,
        withIntermediateDirectories: true
    )
    try FileManager.default.createDirectory(
        at: coverDirectory,
        withIntermediateDirectories: true
    )
    try Data("subtitle".utf8).write(to: subtitleURL)
    try Data("video".utf8).write(to: videoURL)
    try DatabaseBootstrap.prepare(at: databaseURL)
    let indexingDatabase = try IndexingDatabase(path: databaseURL)
    try indexingDatabase.replaceEntries(
        subtitleFile: subtitleURL,
        videoFile: videoURL,
        entries: [
            SubtitleEntry(
                sequenceNumber: 1,
                startTimecode: "00:00:01,000",
                endTimecode: "00:00:02,000",
                startMilliseconds: 1_000,
                endMilliseconds: 2_000,
                text: "automatic cover"
            )
        ]
    )
    try LibraryDatabase(path: databaseURL).updateVideoDuration(
        videoFile: videoURL,
        duration: 100
    )
    return AutomaticCoverFixture(
        root: root,
        mediaDirectory: mediaDirectory,
        coverDirectory: coverDirectory,
        videoURL: videoURL,
        coverDatabase: try LibraryCoverDatabase(path: databaseURL)
    )
}

private func makeAutomaticCoverIndexer(
    coverDirectory: URL,
    ffmpeg: URL
) -> LibraryCoverIndexer {
    LibraryCoverIndexer(
        configuration: .init(
            candidatePercentages: [0.5],
            scoringWidth: 64,
            scoringHeight: 36,
            maxConcurrentVideos: 1,
            coverDirectory: coverDirectory,
            ffmpegPath: ffmpeg.path
        )
    )
}

private func writeAutomaticCoverFFmpeg(
    in directory: URL,
    sourceJPEG: URL
) throws -> URL {
    let url = directory.appendingPathComponent("ffmpeg-success")
    let script = """
        #!/bin/sh
        last_argument=""
        for argument in "$@"; do
            last_argument="$argument"
        done
        if [ "$last_argument" = "pipe:1" ]; then
            dd if=/dev/zero bs=6912 count=1 2>/dev/null
        else
            cp "\(sourceJPEG.path)" "$last_argument"
        fi
        """
    try Data(script.utf8).write(to: url)
    try FileManager.default.setAttributes(
        [.posixPermissions: 0o755],
        ofItemAtPath: url.path
    )
    return url
}

private func writeFailingAutomaticCoverFFmpeg(in directory: URL) throws -> URL {
    let url = directory.appendingPathComponent("ffmpeg-failure")
    try Data("#!/bin/sh\nexit 69\n".utf8).write(to: url)
    try FileManager.default.setAttributes(
        [.posixPermissions: 0o755],
        ofItemAtPath: url.path
    )
    return url
}

private func writeAutomaticCoverTestJPEG(to url: URL) throws {
    let colorSpace = try #require(CGColorSpace(name: CGColorSpace.sRGB))
    let context = try #require(
        CGContext(
            data: nil,
            width: 640,
            height: 360,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
    )
    context.setFillColor(red: 0.12, green: 0.38, blue: 0.72, alpha: 1)
    context.fill(CGRect(x: 0, y: 0, width: 640, height: 360))
    let image = try #require(context.makeImage())
    let destination = try #require(
        CGImageDestinationCreateWithURL(
            url as CFURL,
            UTType.jpeg.identifier as CFString,
            1,
            nil
        )
    )
    CGImageDestinationAddImage(destination, image, nil)
    #expect(CGImageDestinationFinalize(destination))
}
