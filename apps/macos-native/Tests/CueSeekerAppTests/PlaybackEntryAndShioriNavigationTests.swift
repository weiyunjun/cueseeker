import Foundation
import AppKit
import Testing
@testable import CueSeekerCore
@testable import CueSeekerApp

@MainActor
@Test
func playbackChromeSnapshotUsesEntryMetadataAcrossSources() async throws {
    try await withTemporaryNavigationApp { app, database in
        let searchResult = SubtitleSearchResult(
            entryID: 10,
            subtitlePath: "/Media/Search.srt",
            subtitleFormat: .srt,
            videoPath: "/Media/Search.mkv",
            videoName: "Search.mkv",
            displayTitle: "Search Snapshot Title",
            startMilliseconds: 1_000,
            endMilliseconds: 2_000,
            content: "search cue",
            cueLines: ["search cue"]
        )

        app.openSearchResult(searchResult, displayTitle: "Search Row Title")
        #expect(app.playback.chromeSnapshot.displayTitle == "Search Row Title")
        #expect(app.playback.chromeSnapshot.hasPlaybackSelection)

        try indexFakeLibraryVideo(in: database, basename: "A")
        try indexFakeLibraryVideo(in: database, basename: "B")
        try indexFakeLibraryVideo(in: database, basename: "C")
        app.library.libraryVideos = try #require(app.libraryDatabase).libraryVideos(
            under: [URL(fileURLWithPath: "/Media")]
        )
        let videoB = try #require(app.library.libraryVideos.first {
            $0.videoPath == "/Media/B.mkv"
        })

        app.openLibraryVideo(videoB, displayTitle: "Library Row Title")
        #expect(app.playback.chromeSnapshot.displayTitle == "Library Row Title")
        #expect(app.playback.chromeSnapshot.canGoPrevious)
        #expect(app.playback.chromeSnapshot.canGoNext)

        let older = try insertNavigationShiori(
            in: database,
            content: "older shiori cue",
            startMilliseconds: 3_000,
            createdAt: Date(timeIntervalSince1970: 1_800_000_000)
        )
        let newer = try insertNavigationShiori(
            in: database,
            content: "newer shiori cue",
            startMilliseconds: 5_000,
            createdAt: Date(timeIntervalSince1970: 1_900_000_000)
        )

        app.openShiori(
            older,
            navigationScopeIDs: [newer.id, older.id],
            displayTitle: "Shiori Row Title"
        )
        #expect(app.playback.chromeSnapshot.displayTitle == "Shiori Row Title")
        #expect(app.playback.chromeSnapshot.canGoPrevious)
        #expect(!app.playback.chromeSnapshot.canGoNext)
    }
}

@MainActor
@Test
func playbackEntryClearsWorkbenchFocusAcrossSources() async throws {
    try await withTemporaryNavigationApp { app, database in
        let searchResult = SubtitleSearchResult(
            entryID: 10,
            subtitlePath: "/Media/Search.srt",
            subtitleFormat: .srt,
            videoPath: "/Media/Search.mkv",
            videoName: "Search.mkv",
            displayTitle: "Search Snapshot Title",
            startMilliseconds: 1_000,
            endMilliseconds: 2_000,
            content: "search cue",
            cueLines: ["search cue"]
        )

        app.workbenchLayout.isSearchFocused = true
        app.openSearchResult(searchResult)
        #expect(!app.workbenchLayout.isSearchFocused)

        try indexFakeLibraryVideo(in: database, basename: "Library")
        app.library.libraryVideos = try #require(app.libraryDatabase).libraryVideos(
            under: [URL(fileURLWithPath: "/Media")]
        )
        let libraryVideo = try #require(app.library.libraryVideos.first {
            $0.videoPath == "/Media/Library.mkv"
        })

        app.workbenchLayout.isSearchFocused = true
        app.openLibraryVideo(libraryVideo)
        #expect(!app.workbenchLayout.isSearchFocused)

        let shiori = try insertNavigationShiori(
            in: database,
            content: "saved cue",
            startMilliseconds: 3_000,
            createdAt: Date(timeIntervalSince1970: 1_800_000_000)
        )

        app.workbenchLayout.isSearchFocused = true
        app.openShiori(shiori)
        #expect(!app.workbenchLayout.isSearchFocused)
    }
}

@MainActor
@Test
func shioriPlaybackNavigationUsesDatabaseWhenStoreIsNotHydrated() async throws {
    try await withTemporaryNavigationApp { app, database in
        let old = try insertNavigationShiori(
            in: database,
            content: "old saved cue",
            startMilliseconds: 1_000,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        let middle = try insertNavigationShiori(
            in: database,
            content: "middle saved cue",
            startMilliseconds: 3_000,
            createdAt: Date(timeIntervalSince1970: 1_800_000_000)
        )
        let newest = try insertNavigationShiori(
            in: database,
            content: "newest saved cue",
            startMilliseconds: 5_000,
            createdAt: Date(timeIntervalSince1970: 1_900_000_000)
        )

        #expect(app.shiori.residentRelations.isEmpty)

        app.openShiori(middle)
        #expect(app.canOpenPreviousShiori)
        #expect(app.canOpenNextShiori)

        app.openPreviousShiori()
        #expect(app.shiori.selectedShiori?.id == old.id)
        #expect(!app.canOpenPreviousShiori)

        app.openNextShiori()
        #expect(app.shiori.selectedShiori?.id == middle.id)

        app.openNextShiori()
        #expect(app.shiori.selectedShiori?.id == newest.id)
        #expect(!app.canOpenNextShiori)
    }
}

@MainActor
@Test
func shioriPlaybackNavigationUsesProvidedTableScope() async throws {
    try await withTemporaryNavigationApp { app, database in
        let outsideScope = try insertNavigationShiori(
            in: database,
            content: "outside filtered shiori",
            startMilliseconds: 1_000,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        let filteredMiddle = try insertNavigationShiori(
            in: database,
            content: "filtered middle shiori",
            startMilliseconds: 3_000,
            createdAt: Date(timeIntervalSince1970: 1_800_000_000)
        )
        let filteredNewest = try insertNavigationShiori(
            in: database,
            content: "filtered newest shiori",
            startMilliseconds: 5_000,
            createdAt: Date(timeIntervalSince1970: 1_900_000_000)
        )

        #expect(app.shiori.residentRelations.isEmpty)
        app.openShiori(
            filteredMiddle,
            navigationScopeIDs: [filteredNewest.id, filteredMiddle.id]
        )
        #expect(app.canOpenPreviousShiori)
        #expect(!app.canOpenNextShiori)

        app.openPreviousShiori()
        #expect(app.shiori.selectedShiori?.id == filteredNewest.id)
        #expect(!app.canOpenPreviousShiori)

        app.openNextShiori()
        #expect(app.shiori.selectedShiori?.id == filteredMiddle.id)
        #expect(!app.canOpenNextShiori)
        #expect(app.shiori.selectedShiori?.id != outsideScope.id)
    }
}

@MainActor
@Test
func shioriPlaybackNavigationAvailabilityUsesCachedScope() async throws {
    try await withTemporaryNavigationApp { app, database in
        let filteredMiddle = try insertNavigationShiori(
            in: database,
            content: "filtered middle shiori",
            startMilliseconds: 3_000,
            createdAt: Date(timeIntervalSince1970: 1_800_000_000)
        )
        let filteredNewest = try insertNavigationShiori(
            in: database,
            content: "filtered newest shiori",
            startMilliseconds: 5_000,
            createdAt: Date(timeIntervalSince1970: 1_900_000_000)
        )

        app.openShiori(
            filteredMiddle,
            navigationScopeIDs: [filteredNewest.id, filteredMiddle.id]
        )
        app.indexingDatabase = nil

        #expect(app.canOpenPreviousShiori)
        #expect(!app.canOpenNextShiori)
    }
}

@MainActor
@Test
func shioriPlaybackNavigationAvailabilityUsesCachedDatabaseSnapshot() async throws {
    try await withTemporaryNavigationApp { app, database in
        _ = try insertNavigationShiori(
            in: database,
            content: "old saved cue",
            startMilliseconds: 1_000,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        let middle = try insertNavigationShiori(
            in: database,
            content: "middle saved cue",
            startMilliseconds: 3_000,
            createdAt: Date(timeIntervalSince1970: 1_800_000_000)
        )
        _ = try insertNavigationShiori(
            in: database,
            content: "newest saved cue",
            startMilliseconds: 5_000,
            createdAt: Date(timeIntervalSince1970: 1_900_000_000)
        )

        app.openShiori(middle)
        app.indexingDatabase = nil

        #expect(app.canOpenPreviousShiori)
        #expect(app.canOpenNextShiori)
    }
}

@MainActor
private func indexFakeLibraryVideo(in database: IndexingDatabase, basename: String) throws {
    try database.replaceEntries(
        subtitleFile: URL(fileURLWithPath: "/Media/\(basename).srt"),
        videoFile: URL(fileURLWithPath: "/Media/\(basename).mkv"),
        entries: [
            SubtitleEntry(
                sequenceNumber: 1,
                startTimecode: "00:00:01,000",
                endTimecode: "00:00:02,000",
                startMilliseconds: 1_000,
                endMilliseconds: 2_000,
                text: "placeholder \(basename)"
            )
        ]
    )
}

private func insertNavigationShiori(
    in database: IndexingDatabase,
    content: String,
    startMilliseconds: Int,
    createdAt: Date
) throws -> Shiori {
    let subtitleFile = URL(
        fileURLWithPath: "/Media/ShioriNavigation-\(startMilliseconds).srt"
    )
    let videoFile = URL(
        fileURLWithPath: "/Media/ShioriNavigation-\(startMilliseconds).mkv"
    )
    try database.replaceEntries(
        subtitleFile: subtitleFile,
        videoFile: videoFile,
        entries: [
            SubtitleEntry(
                sequenceNumber: 1,
                startTimecode: "00:00:00,000",
                endTimecode: "00:00:01,000",
                startMilliseconds: startMilliseconds,
                endMilliseconds: startMilliseconds + 1_000,
                text: content
            )
        ]
    )
    let selection = try #require(try PlaybackSubtitleDatabase(path: database.path).cueTextSelection(
        forSubtitleFile: subtitleFile,
        atMilliseconds: startMilliseconds
    ))
    return try ShioriDatabase(path: database.path).upsertShiori(
        selection: selection,
        createdAt: createdAt
    )
}

@MainActor
private func withTemporaryNavigationApp(
    _ body: @MainActor (AppCoordinator, IndexingDatabase) throws -> Void
) async throws {
    let suiteName = "CueSeekerAppNavigationTests-\(UUID().uuidString)"
    let userDefaults = try #require(UserDefaults(suiteName: suiteName))
    let databaseURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("CueSeekerAppNavigationTests-\(UUID().uuidString)")
        .appendingPathExtension("sqlite")
    defer {
        userDefaults.removePersistentDomain(forName: suiteName)
        try? FileManager.default.removeItem(at: databaseURL)
        try? FileManager.default.removeItem(atPath: databaseURL.path + "-wal")
        try? FileManager.default.removeItem(atPath: databaseURL.path + "-shm")
    }

    _ = NSApplication.shared
    let app = AppCoordinator(userDefaults: userDefaults, databaseURL: databaseURL)
    await app.startupDatabaseTask?.value
    let database = try #require(app.indexingDatabase)
    try body(app, database)
}
