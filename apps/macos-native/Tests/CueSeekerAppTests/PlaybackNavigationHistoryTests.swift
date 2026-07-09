import Foundation
import AppKit
import Testing
import CueSeekerCore
@testable import CueSeekerApp

@MainActor
@Test
func recordingFromEmptyHistoryAppendsFirstEntryAndPointsToIt() async throws {
    try await withTemporaryNavigationApp { app, database in
        app.recordPlaybackNavigationEntry(
            .library(PlaybackNavigationLibraryPayload(videoPath: "/Media/A.mkv"))
        )

        let entries = try database.playbackNavigationEntries()
        #expect(entries.count == 1)
        #expect(entries[0].payload == .library(
            PlaybackNavigationLibraryPayload(videoPath: "/Media/A.mkv")
        ))
        #expect(try database.playbackNavigationCurrentEntryID() == entries[0].id)
    }
}

@MainActor
@Test
func recordingSameKindReplacesHeadInsteadOfAppending() async throws {
    try await withTemporaryNavigationApp { app, database in
        app.recordPlaybackNavigationEntry(
            .library(PlaybackNavigationLibraryPayload(videoPath: "/Media/A.mkv"))
        )
        app.activePlaybackSource = .library(videoPath: "/Media/A.mkv")
        app.recordPlaybackNavigationEntry(
            .library(PlaybackNavigationLibraryPayload(videoPath: "/Media/B.mkv"))
        )

        let entries = try database.playbackNavigationEntries()
        #expect(entries.count == 1)
        #expect(entries[0].payload == .library(
            PlaybackNavigationLibraryPayload(videoPath: "/Media/B.mkv")
        ))
        #expect(try database.playbackNavigationCurrentEntryID() == entries[0].id)
    }
}

@MainActor
@Test
func recordingDifferentKindAppendsAndAdvancesPointer() async throws {
    try await withTemporaryNavigationApp { app, database in
        app.recordPlaybackNavigationEntry(
            .library(PlaybackNavigationLibraryPayload(videoPath: "/Media/A.mkv"))
        )
        app.activePlaybackSource = .library(videoPath: "/Media/A.mkv")
        app.recordPlaybackNavigationEntry(
            .shiori(
                PlaybackNavigationShioriPayload(
                    id: 7,
                    subtitlePath: "/Media/Shiori.srt",
                    startMilliseconds: 1_000,
                    endMilliseconds: 2_000
                )
            )
        )

        let entries = try database.playbackNavigationEntries()
        #expect(entries.count == 2)
        #expect(entries[1].kind == .shiori)
        #expect(try database.playbackNavigationCurrentEntryID() == entries[1].id)
    }
}

@MainActor
@Test
func recordingAfterPointerMovedBackTruncatesForwardEntries() async throws {
    try await withTemporaryNavigationApp { app, database in
        app.recordPlaybackNavigationEntry(
            .library(PlaybackNavigationLibraryPayload(videoPath: "/Media/A.mkv"))
        )
        let firstID = try #require(try database.playbackNavigationCurrentEntryID())

        app.activePlaybackSource = .library(videoPath: "/Media/A.mkv")
        app.recordPlaybackNavigationEntry(
            .shiori(
                PlaybackNavigationShioriPayload(
                    id: 1,
                    subtitlePath: "/Media/X.srt",
                    startMilliseconds: 1_000,
                    endMilliseconds: 2_000
                )
            )
        )
        app.activePlaybackSource = .shiori
        app.recordPlaybackNavigationEntry(
            .search(
                PlaybackNavigationSearchPayload(
                    query: "foo",
                    scopePaths: [],
                    entryID: nil,
                    subtitlePath: nil,
                    videoPath: nil,
                    startMilliseconds: nil,
                    endMilliseconds: nil,
                    indexRevision: 0
                )
            )
        )

        try database.setPlaybackNavigationCurrentEntryID(firstID)

        app.recordPlaybackNavigationEntry(
            .library(PlaybackNavigationLibraryPayload(videoPath: "/Media/C.mkv"))
        )

        let entries = try database.playbackNavigationEntries()
        #expect(entries.count == 2)
        #expect(entries[0].id == firstID)
        #expect(entries[1].payload == .library(
            PlaybackNavigationLibraryPayload(videoPath: "/Media/C.mkv")
        ))
        #expect(try database.playbackNavigationCurrentEntryID() == entries[1].id)
    }
}

@MainActor
@Test
func recordingPrunesWhenEntriesExceedLimit() async throws {
    try await withTemporaryNavigationApp { app, database in
        for index in 0..<5 {
            if index % 2 == 0 {
                app.recordPlaybackNavigationEntry(
                    .library(PlaybackNavigationLibraryPayload(videoPath: "/Media/\(index).mkv")),
                    limit: 3
                )
                app.activePlaybackSource = .library(videoPath: "/Media/\(index).mkv")
            } else {
                app.recordPlaybackNavigationEntry(
                    .shiori(
                        PlaybackNavigationShioriPayload(
                            id: Int64(index),
                            subtitlePath: "/Media/\(index).srt",
                            startMilliseconds: index * 1_000,
                            endMilliseconds: (index + 1) * 1_000
                        )
                    ),
                    limit: 3
                )
                app.activePlaybackSource = .shiori
            }
        }

        let entries = try database.playbackNavigationEntries()
        #expect(entries.count == 3)
        let lastEntry = try #require(entries.last)
        #expect(lastEntry.payload == .library(
            PlaybackNavigationLibraryPayload(videoPath: "/Media/4.mkv")
        ))
        #expect(try database.playbackNavigationCurrentEntryID() == lastEntry.id)
    }
}

@MainActor
@Test
func playbackNavigationBackRestoresLibraryEntry() async throws {
    try await withTemporaryNavigationApp { app, database in
        try indexFakeLibraryVideo(in: database, basename: "A")
        try indexFakeLibraryVideo(in: database, basename: "B")
        let libraryVideos = try database.libraryVideos(
            under: [URL(fileURLWithPath: "/Media")]
        )
        app.library.libraryVideos = libraryVideos
        let videoAPath = "/Media/A.mkv"
        let videoBPath = "/Media/B.mkv"

        let entryA = try database.appendPlaybackNavigationEntry(
            .library(PlaybackNavigationLibraryPayload(videoPath: videoAPath))
        )
        let entryB = try database.appendPlaybackNavigationEntry(
            .library(PlaybackNavigationLibraryPayload(videoPath: videoBPath))
        )
        try database.setPlaybackNavigationCurrentEntryID(entryB.id)
        app.activePlaybackSource = .library(videoPath: videoBPath)

        #expect(app.executePlaybackNavigationCommand(.back))
        #expect(app.library.selectedLibraryVideo?.videoPath == videoAPath)
        #expect(try database.playbackNavigationCurrentEntryID() == entryA.id)
    }
}

@MainActor
@Test
func playbackNavigationForwardRestoresLibraryEntryWithoutRecordingHistory() async throws {
    try await withTemporaryNavigationApp { app, database in
        try indexFakeLibraryVideo(in: database, basename: "A")
        try indexFakeLibraryVideo(in: database, basename: "B")
        app.library.libraryVideos = try database.libraryVideos(
            under: [URL(fileURLWithPath: "/Media")]
        )
        let videoAPath = "/Media/A.mkv"
        let videoBPath = "/Media/B.mkv"
        let entryA = try database.appendPlaybackNavigationEntry(
            .library(PlaybackNavigationLibraryPayload(videoPath: videoAPath))
        )
        let entryB = try database.appendPlaybackNavigationEntry(
            .library(PlaybackNavigationLibraryPayload(videoPath: videoBPath))
        )
        try database.setPlaybackNavigationCurrentEntryID(entryA.id)
        app.activePlaybackSource = .library(videoPath: videoAPath)

        #expect(app.playbackNavigationAvailability().canMoveBack == false)
        #expect(app.playbackNavigationAvailability().canMoveForward)
        #expect(app.executePlaybackNavigationCommand(.forward))
        #expect(app.library.selectedLibraryVideo?.videoPath == videoBPath)
        #expect(try database.playbackNavigationCurrentEntryID() == entryB.id)

        let entries = try database.playbackNavigationEntries()
        #expect(entries.map(\.id) == [entryA.id, entryB.id])
        #expect(app.playbackNavigationAvailability().canMoveBack)
        #expect(app.playbackNavigationAvailability().canMoveForward == false)
        #expect(!app.executePlaybackNavigationCommand(.forward))
        #expect(try database.playbackNavigationCurrentEntryID() == entryB.id)
    }
}

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
        app.library.libraryVideos = try database.libraryVideos(
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
        app.openSearchResult(searchResult, recordsNavigationHistory: false)
        #expect(!app.workbenchLayout.isSearchFocused)

        try indexFakeLibraryVideo(in: database, basename: "Library")
        app.library.libraryVideos = try database.libraryVideos(
            under: [URL(fileURLWithPath: "/Media")]
        )
        let libraryVideo = try #require(app.library.libraryVideos.first {
            $0.videoPath == "/Media/Library.mkv"
        })

        app.workbenchLayout.isSearchFocused = true
        app.openLibraryVideo(libraryVideo, recordsNavigationHistory: false)
        #expect(!app.workbenchLayout.isSearchFocused)

        let shiori = try insertNavigationShiori(
            in: database,
            content: "saved cue",
            startMilliseconds: 3_000,
            createdAt: Date(timeIntervalSince1970: 1_800_000_000)
        )

        app.workbenchLayout.isSearchFocused = true
        app.openShiori(shiori, recordsNavigationHistory: false)
        #expect(!app.workbenchLayout.isSearchFocused)
    }
}

@MainActor
@Test
func playbackNavigationBackRestoresShioriEntry() async throws {
    try await withTemporaryNavigationApp { app, database in
        try indexFakeLibraryVideo(in: database, basename: "Next")
        app.library.libraryVideos = try database.libraryVideos(
            under: [URL(fileURLWithPath: "/Media")]
        )

        let shioriRow = try database.upsertShiori(
            subtitleFile: URL(fileURLWithPath: "/Media/Next.srt"),
            subtitleFormat: .srt,
            videoFile: URL(fileURLWithPath: "/Media/Next.mkv"),
            videoName: "Next",
            selection: SubtitleCueTextSelection(
                cueGroupID: 0,
                startMilliseconds: 1_000,
                endMilliseconds: 2_000,
                lines: ["hello"]
            )
        )
        #expect(app.shiori.shioris.isEmpty)

        let shioriEntry = try database.appendPlaybackNavigationEntry(
            .shiori(
                PlaybackNavigationShioriPayload(
                    id: shioriRow.id,
                    subtitlePath: shioriRow.subtitlePath,
                    startMilliseconds: shioriRow.startMilliseconds,
                    endMilliseconds: shioriRow.endMilliseconds
                )
            )
        )
        let nextEntry = try database.appendPlaybackNavigationEntry(
            .library(PlaybackNavigationLibraryPayload(videoPath: "/Media/Next.mkv"))
        )
        try database.setPlaybackNavigationCurrentEntryID(nextEntry.id)

        #expect(app.executePlaybackNavigationCommand(.back))
        #expect(app.shiori.selectedShiori?.id == shioriRow.id)
        #expect(try database.playbackNavigationCurrentEntryID() == shioriEntry.id)
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

        #expect(app.shiori.shioris.isEmpty)

        app.openShiori(middle)
        #expect(app.canOpenPreviousShiori)
        #expect(app.canOpenNextShiori)

        app.openPreviousShiori()
        #expect(app.shiori.selectedShiori?.id == newest.id)
        #expect(!app.canOpenPreviousShiori)

        app.openNextShiori()
        #expect(app.shiori.selectedShiori?.id == middle.id)

        app.openNextShiori()
        #expect(app.shiori.selectedShiori?.id == old.id)
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

        #expect(app.shiori.shioris.isEmpty)
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
        app.subtitleDatabase = nil

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
        app.subtitleDatabase = nil

        #expect(app.canOpenPreviousShiori)
        #expect(app.canOpenNextShiori)
    }
}

@MainActor
@Test
func playbackNavigationBackRestoresSavedSearchResultWhenIndexRevisionIsUnchanged() async throws {
    try await withTemporaryNavigationApp { app, database in
        let subtitleURL = URL(fileURLWithPath: "/Media/Movie.srt")
        let videoURL = URL(fileURLWithPath: "/Media/Movie.mkv")
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
                    text: "telegram for you"
                ),
                SubtitleEntry(
                    sequenceNumber: 2,
                    startTimecode: "00:00:05,000",
                    endTimecode: "00:00:06,000",
                    startMilliseconds: 5_000,
                    endMilliseconds: 6_000,
                    text: "another telegram line"
                )
            ]
        )
        try indexFakeLibraryVideo(in: database, basename: "Next")
        let results = try database.search("telegram")
        let savedEntryID = try #require(results.last?.entryID)
        let currentRevision = try database.playbackNavigationIndexRevision()

        app.indexing.selectedFolders = [URL(fileURLWithPath: "/Media")]
        app.library.libraryVideos = try database.libraryVideos(
            under: [URL(fileURLWithPath: "/Media")]
        )

        let searchEntry = try database.appendPlaybackNavigationEntry(
            .search(
                PlaybackNavigationSearchPayload(
                    query: "telegram",
                    scopePaths: ["/Media"],
                    entryID: savedEntryID,
                    subtitlePath: "/Media/Movie.srt",
                    videoPath: "/Media/Movie.mkv",
                    startMilliseconds: 5_000,
                    endMilliseconds: 6_000,
                    indexRevision: currentRevision
                )
            )
        )
        let nextEntry = try database.appendPlaybackNavigationEntry(
            .library(PlaybackNavigationLibraryPayload(videoPath: "/Media/Next.mkv"))
        )
        try database.setPlaybackNavigationCurrentEntryID(nextEntry.id)

        #expect(app.executePlaybackNavigationCommand(.back))
        #expect(app.search.searchQuery == "telegram")
        #expect(app.search.selectedSearchResult?.entryID == savedEntryID)
        #expect(try database.playbackNavigationCurrentEntryID() == searchEntry.id)
    }
}

@MainActor
@Test
func playbackNavigationBackRestoresFirstSearchResultWhenIndexRevisionChanges() async throws {
    try await withTemporaryNavigationApp { app, database in
        let subtitleURL = URL(fileURLWithPath: "/Media/Movie.srt")
        let videoURL = URL(fileURLWithPath: "/Media/Movie.mkv")
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
                    text: "telegram for you"
                )
            ]
        )
        let firstResults = try database.search("telegram")
        let firstResultEntryID = try #require(firstResults.first?.entryID)

        app.indexing.selectedFolders = [URL(fileURLWithPath: "/Media")]
        try indexFakeLibraryVideo(in: database, basename: "Next")
        app.library.libraryVideos = try database.libraryVideos(
            under: [URL(fileURLWithPath: "/Media")]
        )

        // Use a stale revision so the restore code path treats this as changed.
        let staleRevision: Int64 = 0
        let searchEntry = try database.appendPlaybackNavigationEntry(
            .search(
                PlaybackNavigationSearchPayload(
                    query: "telegram",
                    scopePaths: ["/Media"],
                    entryID: 9999, // intentionally not present so the rerun branch is exercised
                    subtitlePath: "/Media/Movie.srt",
                    videoPath: "/Media/Movie.mkv",
                    startMilliseconds: 5_000,
                    endMilliseconds: 6_000,
                    indexRevision: staleRevision
                )
            )
        )
        let nextEntry = try database.appendPlaybackNavigationEntry(
            .library(PlaybackNavigationLibraryPayload(videoPath: "/Media/Next.mkv"))
        )
        try database.setPlaybackNavigationCurrentEntryID(nextEntry.id)

        #expect(app.executePlaybackNavigationCommand(.back))
        #expect(app.search.searchQuery == "telegram")
        #expect(app.search.selectedSearchResult?.entryID == firstResultEntryID)
        #expect(try database.playbackNavigationCurrentEntryID() == searchEntry.id)
    }
}

@MainActor
private func indexFakeLibraryVideo(in database: SubtitleDatabase, basename: String) throws {
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
    in database: SubtitleDatabase,
    content: String,
    startMilliseconds: Int,
    createdAt: Date
) throws -> Shiori {
    try database.upsertShiori(
        subtitleFile: URL(fileURLWithPath: "/Media/ShioriNavigation.srt"),
        subtitleFormat: .srt,
        videoFile: URL(fileURLWithPath: "/Media/ShioriNavigation.mkv"),
        videoName: "ShioriNavigation.mkv",
        selection: SubtitleCueTextSelection(
            cueGroupID: Int64(startMilliseconds),
            startMilliseconds: startMilliseconds,
            endMilliseconds: startMilliseconds + 1_000,
            lines: [content]
        ),
        createdAt: createdAt
    )
}

@MainActor
private func withTemporaryNavigationApp(
    _ body: @MainActor (AppCoordinator, SubtitleDatabase) throws -> Void
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
    let database = try #require(app.subtitleDatabase)
    try body(app, database)
}
