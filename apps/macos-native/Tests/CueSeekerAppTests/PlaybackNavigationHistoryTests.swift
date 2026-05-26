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
func quickSearchBackResumesLibraryEntry() async throws {
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

        app.playback.isQuickSearchOverlayVisible = true
        app.playback.configureQuickSearchNavigation(canMoveBack: true, canMoveForward: false)
        #expect(app.playback.moveQuickSearchAIOptionFocus(by: 1))
        #expect(app.playback.quickSearchFocusTarget == .navigation)

        let dispatched = app.submitPlaybackQuickSearchFromUser()
        #expect(dispatched)
        #expect(app.library.selectedLibraryVideo?.videoPath == videoAPath)
        #expect(!app.playback.isQuickSearchOverlayVisible)
        #expect(try database.playbackNavigationCurrentEntryID() == entryA.id)
    }
}

@MainActor
@Test
func quickSearchBackResumesShioriEntry() async throws {
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
        app.shiori.shioris = [shioriRow]

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

        app.playback.isQuickSearchOverlayVisible = true
        app.playback.configureQuickSearchNavigation(canMoveBack: true, canMoveForward: false)
        #expect(app.playback.moveQuickSearchAIOptionFocus(by: 1))

        let dispatched = app.submitPlaybackQuickSearchFromUser()
        #expect(dispatched)
        #expect(app.shiori.selectedShiori?.id == shioriRow.id)
        #expect(!app.playback.isQuickSearchOverlayVisible)
        #expect(try database.playbackNavigationCurrentEntryID() == shioriEntry.id)
    }
}

@MainActor
@Test
func quickSearchBackResumesSearchEntryWithUnchangedRevision() async throws {
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

        app.playback.isQuickSearchOverlayVisible = true
        app.playback.configureQuickSearchNavigation(canMoveBack: true, canMoveForward: false)
        #expect(app.playback.moveQuickSearchAIOptionFocus(by: 1))

        let dispatched = app.submitPlaybackQuickSearchFromUser()
        #expect(dispatched)
        #expect(app.search.searchQuery == "telegram")
        #expect(app.search.selectedSearchResult?.entryID == savedEntryID)
        #expect(!app.playback.isQuickSearchOverlayVisible)
        #expect(try database.playbackNavigationCurrentEntryID() == searchEntry.id)
    }
}

@MainActor
@Test
func quickSearchBackResumesSearchEntryReplaysFirstResultWhenIndexChanged() async throws {
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

        app.playback.isQuickSearchOverlayVisible = true
        app.playback.configureQuickSearchNavigation(canMoveBack: true, canMoveForward: false)
        #expect(app.playback.moveQuickSearchAIOptionFocus(by: 1))

        let dispatched = app.submitPlaybackQuickSearchFromUser()
        #expect(dispatched)
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
