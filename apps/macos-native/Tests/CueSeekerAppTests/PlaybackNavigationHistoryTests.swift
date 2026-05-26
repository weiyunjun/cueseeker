import Foundation
import AppKit
import Testing
import CueSeekerCore
@testable import CueSeekerApp

@MainActor
@Test
func recordingFromEmptyHistoryAppendsFirstEntryAndPointsToIt() throws {
    try withTemporaryNavigationApp { app, database in
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
func recordingSameKindReplacesHeadInsteadOfAppending() throws {
    try withTemporaryNavigationApp { app, database in
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
func recordingDifferentKindAppendsAndAdvancesPointer() throws {
    try withTemporaryNavigationApp { app, database in
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
func recordingAfterPointerMovedBackTruncatesForwardEntries() throws {
    try withTemporaryNavigationApp { app, database in
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
func recordingPrunesWhenEntriesExceedLimit() throws {
    try withTemporaryNavigationApp { app, database in
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
private func withTemporaryNavigationApp(
    _ body: @MainActor (AppCoordinator, SubtitleDatabase) throws -> Void
) throws {
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
    let database = try #require(app.subtitleDatabase)
    try body(app, database)
}
