import Foundation
import Testing
@testable import CueSeekerCore

@Test
func reportsStorageStatsAndCompactsFreelistPages() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
        try? FileManager.default.removeItem(atPath: databaseURL.path + "-wal")
        try? FileManager.default.removeItem(atPath: databaseURL.path + "-shm")
    }

    let database = try IndexingDatabase(path: databaseURL)
    try DatabaseBootstrap.prepare(at: databaseURL)

    let subtitleFile = URL(fileURLWithPath: "/Media/Large.srt")
    let videoFile = URL(fileURLWithPath: "/Media/Large.mkv")
    let entries = (0..<5_000).map { index in
        SubtitleEntry(
            sequenceNumber: index + 1,
            startTimecode: "00:00:00,000",
            endTimecode: "00:00:01,000",
            startMilliseconds: index * 1_000,
            endMilliseconds: index * 1_000 + 500,
            text: "Searchable storage compaction line \(index) " + String(repeating: "payload ", count: 12)
        )
    }

    try database.replaceEntries(
        subtitleFile: subtitleFile,
        videoFile: videoFile,
        entries: entries
    )
    try database.reconcileIndexedContent(activeFolders: [])

    let maintenance = try DatabaseMaintenanceDatabase(path: databaseURL)
    let statsAfterClear = try maintenance.storageStats()
    #expect(statsAfterClear.pageSize > 0)
    #expect(statsAfterClear.pageCount > 0)
    #expect(statsAfterClear.freelistCount > 0)
    #expect(statsAfterClear.freelistBytes > 0)
    #expect(statsAfterClear.databaseFileBytes > 0)

    try maintenance.compactStorage()

    let statsAfterCompact = try maintenance.storageStats()
    #expect(statsAfterCompact.freelistCount == 0)
    #expect(statsAfterCompact.freelistBytes == 0)
    #expect(statsAfterCompact.databaseFileBytes <= statsAfterClear.databaseFileBytes)
}
