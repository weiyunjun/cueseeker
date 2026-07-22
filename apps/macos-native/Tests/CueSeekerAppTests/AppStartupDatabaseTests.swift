import Foundation
import AppKit
import ImageIO
import Testing
import UniformTypeIdentifiers
import CueSeekerCore
@testable import CueSeekerApp

@MainActor
@Test
func appStartupDoesNotRunDatabaseMaintenanceWhenIdle() async throws {
    let suiteName = "CueSeekerAppStartupTests-\(UUID().uuidString)"
    let userDefaults = try #require(UserDefaults(suiteName: suiteName))
    let databaseURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("CueSeekerAppStartupTests-\(UUID().uuidString)")
        .appendingPathExtension("sqlite")
    defer {
        userDefaults.removePersistentDomain(forName: suiteName)
        try? FileManager.default.removeItem(at: databaseURL)
        try? FileManager.default.removeItem(atPath: databaseURL.path + "-wal")
        try? FileManager.default.removeItem(atPath: databaseURL.path + "-shm")
    }

    try DatabaseBootstrap.prepare(at: databaseURL)
    let preparedDatabase = try SubtitleDatabase(path: databaseURL)
    try preparedDatabase.replaceEntries(
        subtitleFile: URL(fileURLWithPath: "/Media/Startup.srt"),
        videoFile: URL(fileURLWithPath: "/Media/Startup.mkv"),
        entries: [
            SubtitleEntry(
                sequenceNumber: 1,
                startTimecode: "00:00:01,000",
                endTimecode: "00:00:02,000",
                startMilliseconds: 1_000,
                endMilliseconds: 2_000,
                text: "startup search should stay available"
            )
        ]
    )
    let cacheKey = AIChunkCacheKey(
        normalizedSentence: "startup cache should stay available",
        provider: "deepseek",
        model: "deepseek-chat",
        promptVersion: "startup-v1"
    )
    let cache = try AIChunkCacheDatabase(path: databaseURL)
    try cache.upsertAIChunkCacheEntry(
        key: cacheKey,
        chunks: [AIChunkItem(item: "startup", translation: "startup")]
    )
    #expect(try SearchDatabase(path: databaseURL).cueOccurrenceCount(for: "startup") == 1)

    _ = NSApplication.shared
    let app = AppCoordinator(userDefaults: userDefaults, databaseURL: databaseURL)

    #expect(app.startupDatabaseTask == nil)
    #expect(app.libraryDisplayRenditionTask == nil)
    #expect(try #require(app.searchDatabase).cueOccurrenceCount(for: "startup") == 1)
    #expect(try cache.aiChunkCacheEntry(for: cacheKey)?.chunks == [
        AIChunkItem(item: "startup", translation: "startup")
    ])
    #expect(app.indexing.databaseStorageStats == nil)
}

@MainActor
@Test
func explicitIndexFolderKeepsSearchAndLibraryReady() async throws {
    let suiteName = "CueSeekerAppExplicitIndexTests-\(UUID().uuidString)"
    let userDefaults = try #require(UserDefaults(suiteName: suiteName))
    let fixtureRoot = FileManager.default.temporaryDirectory
        .appendingPathComponent("CueSeekerAppExplicitIndexTests-\(UUID().uuidString)", isDirectory: true)
    let databaseURL = fixtureRoot
        .appendingPathComponent("CueSeekerAppExplicitIndexTests")
        .appendingPathExtension("sqlite")
    defer {
        userDefaults.removePersistentDomain(forName: suiteName)
        try? FileManager.default.removeItem(at: fixtureRoot)
    }

    try FileManager.default.createDirectory(
        at: fixtureRoot,
        withIntermediateDirectories: true
    )
    try """
    1
    00:00:01,000 --> 00:00:02,000
    explicit indexing keeps search ready

    """.write(
        to: fixtureRoot.appendingPathComponent("Episode.srt"),
        atomically: true,
        encoding: .utf8
    )
    #expect(FileManager.default.createFile(
        atPath: fixtureRoot.appendingPathComponent("Episode.mkv").path,
        contents: Data()
    ))

    _ = NSApplication.shared
    let app = AppCoordinator(userDefaults: userDefaults, databaseURL: databaseURL)
    #expect(app.startupDatabaseTask == nil)

    app.addFolder(fixtureRoot)
    await app.indexingTask?.value
    await app.libraryTask?.value
    await app.databaseStorageStatsTask?.value

    let page = try #require(app.searchDatabase).searchVisiblePage(
        "explicit",
        limit: 10,
        cursor: .start,
        under: [fixtureRoot]
    )
    #expect(page.results.count == 1)
    #expect(page.results[0].content == "explicit indexing keeps search ready")
    #expect(page.fileSummaries.count == 1)
    #expect(app.library.libraryVideos.count == 1)
    #expect(app.library.libraryFolderGroups.count == 1)
    #expect(app.indexing.databaseStorageStats != nil)
}

@MainActor
@Test
func libraryRouteBackfillsLegacyDisplayCoverWithoutStartupMaintenance() async throws {
    let suiteName = "CueSeekerLibraryDisplayBackfillTests-\(UUID().uuidString)"
    let userDefaults = try #require(UserDefaults(suiteName: suiteName))
    let fixtureRoot = FileManager.default.temporaryDirectory
        .appendingPathComponent("CueSeekerLibraryDisplayBackfillTests-\(UUID().uuidString)", isDirectory: true)
    let mediaDirectory = fixtureRoot.appendingPathComponent("Media", isDirectory: true)
    let databaseURL = fixtureRoot.appendingPathComponent("CueSeeker.sqlite")
    let masterURL = fixtureRoot
        .appendingPathComponent("Covers/Videos", isDirectory: true)
        .appendingPathComponent("legacy-master.jpg")
    defer {
        userDefaults.removePersistentDomain(forName: suiteName)
        try? FileManager.default.removeItem(at: fixtureRoot)
    }

    try FileManager.default.createDirectory(at: mediaDirectory, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(
        at: masterURL.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    let subtitleURL = mediaDirectory.appendingPathComponent("Episode 1.srt")
    let videoURL = mediaDirectory.appendingPathComponent("Episode 1.mkv")
    let missingMasterSubtitleURL = mediaDirectory.appendingPathComponent("Episode 2.srt")
    let missingMasterVideoURL = mediaDirectory.appendingPathComponent("Episode 2.mkv")
    try Data("subtitle".utf8).write(to: subtitleURL)
    try Data("not-a-video".utf8).write(to: videoURL)
    try Data("subtitle".utf8).write(to: missingMasterSubtitleURL)
    try Data("not-a-video".utf8).write(to: missingMasterVideoURL)
    try writeStartupTestJPEG(width: 1_440, height: 1_080, to: masterURL)
    let masterDataBefore = try Data(contentsOf: masterURL)

    try DatabaseBootstrap.prepare(at: databaseURL)
    let preparedDatabase = try SubtitleDatabase(path: databaseURL)
    let preparedLibraryDatabase = try LibraryDatabase(path: databaseURL)
    let preparedCoverDatabase = try LibraryCoverDatabase(path: databaseURL)
    try preparedDatabase.replaceEntries(
        subtitleFile: subtitleURL,
        videoFile: videoURL,
        entries: [
            SubtitleEntry(
                sequenceNumber: 1,
                startTimecode: "00:00:01,000",
                endTimecode: "00:00:02,000",
                startMilliseconds: 1_000,
                endMilliseconds: 2_000,
                text: "route display backfill"
            )
        ]
    )
    try preparedDatabase.replaceEntries(
        subtitleFile: missingMasterSubtitleURL,
        videoFile: missingMasterVideoURL,
        entries: [
            SubtitleEntry(
                sequenceNumber: 1,
                startTimecode: "00:00:01,000",
                endTimecode: "00:00:02,000",
                startMilliseconds: 1_000,
                endMilliseconds: 2_000,
                text: "missing master does not retrigger route backfill"
            )
        ]
    )
    try preparedLibraryDatabase.rebuildLibraryPresentationSnapshot()
    try preparedLibraryDatabase.upsertLibraryPlaybackHistory(
        videoFile: videoURL,
        positionMilliseconds: 1_000,
        duration: 100
    )
    let candidates = try preparedCoverDatabase.libraryCoverEligibleVideos(under: [mediaDirectory])
    let candidate = try #require(candidates.first { $0.videoPath == videoURL.path })
    let missingMasterCandidate = try #require(
        candidates.first { $0.videoPath == missingMasterVideoURL.path }
    )
    try preparedCoverDatabase.upsertLibraryVideoCover(
        videoFileID: candidate.videoFileID,
        masterCoverPath: masterURL.path,
        sourceTimeMilliseconds: 1_000,
        score: 80,
        algorithmVersion: 1,
        generatedFileSize: candidate.fileSize,
        generatedDuration: candidate.duration,
        status: .generated,
        errorMessage: nil
    )
    try preparedCoverDatabase.upsertLibraryVideoCover(
        videoFileID: missingMasterCandidate.videoFileID,
        masterCoverPath: fixtureRoot.appendingPathComponent("missing-master.jpg").path,
        sourceTimeMilliseconds: 1_000,
        score: 70,
        algorithmVersion: 1,
        generatedFileSize: missingMasterCandidate.fileSize,
        generatedDuration: missingMasterCandidate.duration,
        status: .generated,
        errorMessage: nil
    )
    userDefaults.set([mediaDirectory.path], forKey: "selectedFolderPaths")

    _ = NSApplication.shared
    let app = AppCoordinator(userDefaults: userDefaults, databaseURL: databaseURL)
    #expect(app.startupDatabaseTask == nil)
    #expect(app.libraryDisplayRenditionTask == nil)
    #expect(
        try app.libraryCoverDatabase?.libraryVideoCover(forVideoFileID: candidate.videoFileID)?
            .displayCoverPath == nil
    )

    app.hydrateTestRecentWatchingAsync()
    let backfillTask = try #require(app.libraryDisplayRenditionTask)
    await backfillTask.value
    await app.testRecentWatchingTask?.value

    let storedCover = try #require(
        try app.libraryCoverDatabase?.libraryVideoCover(forVideoFileID: candidate.videoFileID)
    )
    let displayPath = try #require(storedCover.displayCoverPath)
    #expect(storedCover.displayProfileVersion == LibraryCoverDisplayProfileVersion.current)
    #expect(FileManager.default.fileExists(atPath: displayPath))
    #expect(try Data(contentsOf: masterURL) == masterDataBefore)
    #expect(app.library.testRecentWatchingItems.first?.coverPath == displayPath)
    #expect(app.indexingTask == nil)
    #expect(app.libraryDisplayRenditionAttemptedScopeKey != nil)
    #expect(
        try app.libraryCoverDatabase?.libraryVideoCover(
            forVideoFileID: missingMasterCandidate.videoFileID
        )?.displayCoverPath == nil
    )

    let displayModificationDate = try #require(
        try FileManager.default.attributesOfItem(atPath: displayPath)[.modificationDate] as? Date
    )
    app.hydrateTestRecentWatchingAsync()
    #expect(app.libraryDisplayRenditionTask == nil)
    await app.testRecentWatchingTask?.value
    #expect(
        try FileManager.default.attributesOfItem(atPath: displayPath)[.modificationDate] as? Date
            == displayModificationDate
    )
}

@MainActor
@Test
func cancelDatabaseReadsResetsLibraryLoadingStates() throws {
    let suiteName = "CueSeekerLibraryCancelTests-\(UUID().uuidString)"
    let userDefaults = try #require(UserDefaults(suiteName: suiteName))
    let databaseURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("CueSeekerLibraryCancelTests-\(UUID().uuidString)")
        .appendingPathExtension("sqlite")
    defer {
        userDefaults.removePersistentDomain(forName: suiteName)
        try? FileManager.default.removeItem(at: databaseURL)
        try? FileManager.default.removeItem(atPath: databaseURL.path + "-wal")
        try? FileManager.default.removeItem(atPath: databaseURL.path + "-shm")
    }

    _ = NSApplication.shared
    let app = AppCoordinator(userDefaults: userDefaults, databaseURL: databaseURL)
    app.library.recentWatchingStatus = .loading
    app.library.testRecentWatchingStatus = .loading
    app.library.completeLibraryStatus = .loading

    app.cancelDatabaseReadTasksBeforeIndexing()

    #expect(app.library.recentWatchingStatus == .idle)
    #expect(app.library.testRecentWatchingStatus == .idle)
    #expect(app.library.completeLibraryStatus == .idle)
    #expect(app.canCompactDatabase)
}

private func writeStartupTestJPEG(width: Int, height: Int, to url: URL) throws {
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
    context.setFillColor(red: 0.12, green: 0.42, blue: 0.78, alpha: 1)
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    let image = try #require(context.makeImage())
    let destination = try #require(
        CGImageDestinationCreateWithURL(
            url as CFURL,
            UTType.jpeg.identifier as CFString,
            1,
            nil
        )
    )
    CGImageDestinationAddImage(
        destination,
        image,
        [kCGImageDestinationLossyCompressionQuality: 0.95] as CFDictionary
    )
    #expect(CGImageDestinationFinalize(destination))
}
