import AppKit
import Foundation
import Testing
import CueSeekerCore
import CueSeekerPlayback
@testable import CueSeekerApp

@MainActor
@Test
func refreshingLoadedCurrentSubtitlePathDoesNotClearVisibleWindow() async throws {
    try await withTemporarySubtitleRefreshApp { app, database in
        try database.replaceEntries(
            subtitleFile: URL(fileURLWithPath: "/Media/Lifecycle.srt"),
            videoFile: URL(fileURLWithPath: "/Media/Lifecycle.mkv"),
            entries: [
                SubtitleEntry(
                    sequenceNumber: 1,
                    startTimecode: "00:00:01,000",
                    endTimecode: "00:00:02,000",
                    startMilliseconds: 1_000,
                    endMilliseconds: 2_000,
                    text: "lifecycle first"
                ),
                SubtitleEntry(
                    sequenceNumber: 2,
                    startTimecode: "00:00:03,000",
                    endTimecode: "00:00:04,000",
                    startMilliseconds: 3_000,
                    endMilliseconds: 4_000,
                    text: "lifecycle second"
                )
            ]
        )
        let result = try #require(try database.searchPage("lifecycle", limit: 1).results.first)
        app.search.selectedSearchResult = result
        app.activePlaybackSource = .search

        app.refreshCurrentSubtitleEntries()
        let initialTask = try #require(app.currentSubtitleEntriesTask)
        await initialTask.value

        let loadedEntries = app.playback.currentSubtitleEntries
        let loadedIndex = app.playback.currentSubtitleEntryIndex
        let rowsVersion = app.playback.currentSubtitleEntryRowsVersion

        #expect(!loadedEntries.isEmpty)
        #expect(!loadedIndex.isEmpty)
        #expect(app.playback.currentSubtitleEntrySubtitlePath == result.subtitlePath)

        app.refreshCurrentSubtitleEntries()

        #expect(app.currentSubtitleEntriesTask == nil)
        #expect(app.playback.currentSubtitleEntries == loadedEntries)
        #expect(app.playback.currentSubtitleEntryIndex == loadedIndex)
        #expect(app.playback.currentSubtitleEntryRowsVersion == rowsVersion)
    }
}

@MainActor
@Test
func initialPlaybackSRTCuePrefixesSpeakerWhenSettingIsEnabled() async throws {
    try await withTemporarySubtitleRefreshApp { app, database in
        let subtitleFile = URL(fileURLWithPath: "/Media/Speaker.srt")
        try database.replaceEntries(
            subtitleFile: subtitleFile,
            videoFile: URL(fileURLWithPath: "/Media/Speaker.mkv"),
            entries: [
                SubtitleEntry(
                    sequenceNumber: 1,
                    startTimecode: "00:00:01,000",
                    endTimecode: "00:00:02,000",
                    startMilliseconds: 1_000,
                    endMilliseconds: 2_000,
                    text: "speaker first"
                )
            ]
        )
        let result = try #require(try database.searchPage("speaker", limit: 1).results.first)
        let line = try #require(try database.cueLineRecords(forSubtitleFile: subtitleFile).first)
        try database.replaceCueLineSpeakers(
            forSubtitleFile: subtitleFile,
            assignments: [
                SubtitleCueLineSpeakerAssignment(
                    cueLineID: line.id,
                    speakers: ["疑似高松灯", "长崎素世"]
                )
            ]
        )
        app.settings.playbackSpeakerDisplayEnabled = true

        let cues = app.initialPlaybackSubtitleCues(for: result)

        #expect(cues.first?.text == "长崎素世,疑似高松灯: speaker first")
    }
}

@MainActor
private func withTemporarySubtitleRefreshApp(
    _ body: @MainActor (AppCoordinator, SubtitleDatabase) async throws -> Void
) async throws {
    let suiteName = "CueSeekerSubtitleRefreshTests-\(UUID().uuidString)"
    let userDefaults = try #require(UserDefaults(suiteName: suiteName))
    let databaseURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("CueSeekerSubtitleRefreshTests-\(UUID().uuidString)")
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
    try await body(app, database)
}
