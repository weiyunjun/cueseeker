import Foundation
import AppKit
import Testing
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

    let preparedDatabase = try SubtitleDatabase(path: databaseURL)
    try preparedDatabase.migrate()
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
    try preparedDatabase.upsertAIChunkCacheEntry(
        key: cacheKey,
        chunks: [AIChunkItem(item: "startup", translation: "startup")]
    )
    #expect(try preparedDatabase.cueGroupOccurrenceCount(for: "startup") == 1)

    _ = NSApplication.shared
    let app = AppCoordinator(userDefaults: userDefaults, databaseURL: databaseURL)

    #expect(app.startupDatabaseTask == nil)
    let database = try #require(app.subtitleDatabase)
    #expect(try database.cueGroupOccurrenceCount(for: "startup") == 1)
    #expect(try database.aiChunkCacheEntry(for: cacheKey)?.chunks == [
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

    let database = try #require(app.subtitleDatabase)
    let page = try database.searchVisiblePage(
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
