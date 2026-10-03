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

        // A video the database holds reads its own Display Title, whatever
        // title the entry passes.
        app.openLibraryVideo(videoB, displayTitle: "Library Row Title")
        #expect(app.playback.chromeSnapshot.displayTitle == "Media - 02")
        #expect(app.playback.chromeSnapshot.canGoPrevious)
        #expect(app.playback.chromeSnapshot.canGoNext)

        let older = try insertNavigationExcerpt(
            in: database,
            content: "older excerpt cue",
            startMilliseconds: 3_000,
            createdAt: Date(timeIntervalSince1970: 1_800_000_000)
        )
        let newer = try insertNavigationExcerpt(
            in: database,
            content: "newer excerpt cue",
            startMilliseconds: 5_000,
            createdAt: Date(timeIntervalSince1970: 1_900_000_000)
        )

        app.openExcerpt(
            older,
            navigationScopeIDs: [newer.id, older.id],
            displayTitle: "Excerpt Row Title"
        )
        #expect(app.playback.chromeSnapshot.displayTitle == "Media - 04")
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

        let excerpt = try insertNavigationExcerpt(
            in: database,
            content: "saved cue",
            startMilliseconds: 3_000,
            createdAt: Date(timeIntervalSince1970: 1_800_000_000)
        )

        app.workbenchLayout.isSearchFocused = true
        app.openExcerpt(excerpt)
        #expect(!app.workbenchLayout.isSearchFocused)
    }
}

@MainActor
@Test
func excerptPlaybackNavigationUsesDatabaseWhenStoreIsNotHydrated() async throws {
    try await withTemporaryNavigationApp { app, database in
        let old = try insertNavigationExcerpt(
            in: database,
            content: "old saved cue",
            startMilliseconds: 1_000,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        let middle = try insertNavigationExcerpt(
            in: database,
            content: "middle saved cue",
            startMilliseconds: 3_000,
            createdAt: Date(timeIntervalSince1970: 1_800_000_000)
        )
        let newest = try insertNavigationExcerpt(
            in: database,
            content: "newest saved cue",
            startMilliseconds: 5_000,
            createdAt: Date(timeIntervalSince1970: 1_900_000_000)
        )

        #expect(app.excerpt.residentRelations.isEmpty)

        app.openExcerpt(middle)
        #expect(app.canOpenPreviousExcerpt)
        #expect(app.canOpenNextExcerpt)

        app.openPreviousExcerpt()
        #expect(app.excerpt.selectedExcerpt?.id == old.id)
        #expect(!app.canOpenPreviousExcerpt)

        app.openNextExcerpt()
        #expect(app.excerpt.selectedExcerpt?.id == middle.id)

        app.openNextExcerpt()
        #expect(app.excerpt.selectedExcerpt?.id == newest.id)
        #expect(!app.canOpenNextExcerpt)
    }
}

@MainActor
@Test
func excerptPlaybackNavigationUsesProvidedTableScope() async throws {
    try await withTemporaryNavigationApp { app, database in
        let outsideScope = try insertNavigationExcerpt(
            in: database,
            content: "outside filtered excerpt",
            startMilliseconds: 1_000,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        let filteredMiddle = try insertNavigationExcerpt(
            in: database,
            content: "filtered middle excerpt",
            startMilliseconds: 3_000,
            createdAt: Date(timeIntervalSince1970: 1_800_000_000)
        )
        let filteredNewest = try insertNavigationExcerpt(
            in: database,
            content: "filtered newest excerpt",
            startMilliseconds: 5_000,
            createdAt: Date(timeIntervalSince1970: 1_900_000_000)
        )

        #expect(app.excerpt.residentRelations.isEmpty)
        app.openExcerpt(
            filteredMiddle,
            navigationScopeIDs: [filteredNewest.id, filteredMiddle.id]
        )
        #expect(app.canOpenPreviousExcerpt)
        #expect(!app.canOpenNextExcerpt)

        app.openPreviousExcerpt()
        #expect(app.excerpt.selectedExcerpt?.id == filteredNewest.id)
        #expect(!app.canOpenPreviousExcerpt)

        app.openNextExcerpt()
        #expect(app.excerpt.selectedExcerpt?.id == filteredMiddle.id)
        #expect(!app.canOpenNextExcerpt)
        #expect(app.excerpt.selectedExcerpt?.id != outsideScope.id)
    }
}

@MainActor
@Test
func excerptPlaybackNavigationAvailabilityUsesCachedScope() async throws {
    try await withTemporaryNavigationApp { app, database in
        let filteredMiddle = try insertNavigationExcerpt(
            in: database,
            content: "filtered middle excerpt",
            startMilliseconds: 3_000,
            createdAt: Date(timeIntervalSince1970: 1_800_000_000)
        )
        let filteredNewest = try insertNavigationExcerpt(
            in: database,
            content: "filtered newest excerpt",
            startMilliseconds: 5_000,
            createdAt: Date(timeIntervalSince1970: 1_900_000_000)
        )

        app.openExcerpt(
            filteredMiddle,
            navigationScopeIDs: [filteredNewest.id, filteredMiddle.id]
        )
        app.indexingDatabase = nil

        #expect(app.canOpenPreviousExcerpt)
        #expect(!app.canOpenNextExcerpt)
    }
}

@MainActor
@Test
func excerptPlaybackNavigationAvailabilityUsesCachedDatabaseSnapshot() async throws {
    try await withTemporaryNavigationApp { app, database in
        _ = try insertNavigationExcerpt(
            in: database,
            content: "old saved cue",
            startMilliseconds: 1_000,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        let middle = try insertNavigationExcerpt(
            in: database,
            content: "middle saved cue",
            startMilliseconds: 3_000,
            createdAt: Date(timeIntervalSince1970: 1_800_000_000)
        )
        _ = try insertNavigationExcerpt(
            in: database,
            content: "newest saved cue",
            startMilliseconds: 5_000,
            createdAt: Date(timeIntervalSince1970: 1_900_000_000)
        )

        app.openExcerpt(middle)
        app.indexingDatabase = nil

        #expect(app.canOpenPreviousExcerpt)
        #expect(app.canOpenNextExcerpt)
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

private func insertNavigationExcerpt(
    in database: IndexingDatabase,
    content: String,
    startMilliseconds: Int,
    createdAt: Date
) throws -> Excerpt {
    let subtitleFile = URL(
        fileURLWithPath: "/Media/ExcerptNavigation-\(startMilliseconds).srt"
    )
    let videoFile = URL(
        fileURLWithPath: "/Media/ExcerptNavigation-\(startMilliseconds).mkv"
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
    return try ExcerptDatabase(path: database.path).upsertExcerpt(
        selection: selection,
        createdAt: createdAt
    )
}

@MainActor
private func withTemporaryNavigationApp(
    _ body: @MainActor (AppCoordinator, IndexingDatabase) throws -> Void
) async throws {
    let suiteName = "CueSeekerAppNavigationTests-\(UUID().uuidString)"
    let userDefaults = try #require(UserDefaults.temporary(suiteName: suiteName))
    let databaseURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("CueSeekerAppNavigationTests-\(UUID().uuidString)")
        .appendingPathExtension("sqlite")
    defer {
        userDefaults.removePersistentDomainAndPlist(forName: suiteName)
        removeTemporaryDatabase(at: databaseURL)
        try? FileManager.default.removeItem(atPath: databaseURL.path + "-wal")
        try? FileManager.default.removeItem(atPath: databaseURL.path + "-shm")
    }

    _ = NSApplication.shared
    let app = AppCoordinator(userDefaults: userDefaults, databaseURL: databaseURL)
    await app.startupDatabaseTask?.value
    let database = try #require(app.indexingDatabase)
    try body(app, database)
}
