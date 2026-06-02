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
