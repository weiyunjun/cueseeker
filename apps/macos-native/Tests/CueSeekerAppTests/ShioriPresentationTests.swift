import AppKit
import Foundation
import Testing
import CueSeekerCore
import CueSeekerPlayback
@testable import CueSeekerApp

@MainActor
@Test
func removeShioriDoesNotHydrateLegacyPresentationWhenTableOnly() throws {
    let suiteName = "CueSeekerShioriPresentationTests-\(UUID().uuidString)"
    let userDefaults = try #require(UserDefaults(suiteName: suiteName))
    let fixtureRoot = FileManager.default.temporaryDirectory
        .appendingPathComponent("CueSeekerShioriPresentationTests-\(UUID().uuidString)", isDirectory: true)
    let databaseURL = fixtureRoot
        .appendingPathComponent("CueSeekerShioriPresentationTests.sqlite")
    defer {
        userDefaults.removePersistentDomain(forName: suiteName)
        try? FileManager.default.removeItem(at: fixtureRoot)
    }

    try FileManager.default.createDirectory(
        at: fixtureRoot,
        withIntermediateDirectories: true
    )

    _ = NSApplication.shared
    let app = AppCoordinator(userDefaults: userDefaults, databaseURL: databaseURL)
    let database = try #require(app.subtitleDatabase)
    let first = try makeShiori(
        in: database,
        id: 1,
        content: "first saved cue"
    )
    _ = try makeShiori(
        in: database,
        id: 2,
        content: "second saved cue"
    )

    #expect(try database.shioriCount() == 2)
    #expect(app.shiori.shioris.isEmpty)
    #expect(app.shiori.shioriFileGroups.isEmpty)

    #expect(app.removeShiori(first, reloadPresentation: true))

    #expect(try database.shioriCount() == 1)
    #expect(app.shiori.shioris.isEmpty)
    #expect(app.shiori.shioriFileGroups.isEmpty)
    #expect(!app.shiori.tableHasLoadedInitialPage)
}

@MainActor
@Test
func playbackShioriToggleDoesNotRemoveExistingShiori() throws {
    let suiteName = "CueSeekerPlaybackShioriRemovalTests-\(UUID().uuidString)"
    let userDefaults = try #require(UserDefaults(suiteName: suiteName))
    let fixtureRoot = FileManager.default.temporaryDirectory
        .appendingPathComponent("CueSeekerPlaybackShioriRemovalTests-\(UUID().uuidString)", isDirectory: true)
    let databaseURL = fixtureRoot
        .appendingPathComponent("CueSeekerPlaybackShioriRemovalTests.sqlite")
    defer {
        userDefaults.removePersistentDomain(forName: suiteName)
        try? FileManager.default.removeItem(at: fixtureRoot)
    }

    try FileManager.default.createDirectory(
        at: fixtureRoot,
        withIntermediateDirectories: true
    )

    _ = NSApplication.shared
    let app = AppCoordinator(userDefaults: userDefaults, databaseURL: databaseURL)
    let database = try #require(app.subtitleDatabase)
    let subtitleFile = URL(fileURLWithPath: "/Media/Playback-Shiori.srt")
    let videoFile = URL(fileURLWithPath: "/Media/Playback-Shiori.mkv")
    let shiori = try makeIndexedPlaybackShiori(
        in: database,
        subtitleFile: subtitleFile,
        videoFile: videoFile
    )
    let player = PlaybackPlayer()
    let playbackViewModel = PlaybackViewModel(player: player)
    app.shiori.selectedShiori = shiori
    app.playback.playbackViewModel = playbackViewModel
    playbackViewModel.setSubtitleCues([], currentTimeMilliseconds: 1_500)

    #expect(try database.shioriCount() == 1)

    #expect(app.toggleCurrentShiori())

    #expect(try database.shioriCount() == 1)
    #expect(try database.shiori(id: shiori.id)?.id == shiori.id)
    #expect(app.shiori.selectedShiori?.id == shiori.id)
    #expect(playbackViewModel.feedback?.text == "Shiori Already Saved")
}

@MainActor
@Test
func playbackShioriToggleStillSavesUnsavedCue() throws {
    let suiteName = "CueSeekerPlaybackShioriSaveTests-\(UUID().uuidString)"
    let userDefaults = try #require(UserDefaults(suiteName: suiteName))
    let fixtureRoot = FileManager.default.temporaryDirectory
        .appendingPathComponent("CueSeekerPlaybackShioriSaveTests-\(UUID().uuidString)", isDirectory: true)
    let databaseURL = fixtureRoot
        .appendingPathComponent("CueSeekerPlaybackShioriSaveTests.sqlite")
    defer {
        userDefaults.removePersistentDomain(forName: suiteName)
        try? FileManager.default.removeItem(at: fixtureRoot)
    }

    try FileManager.default.createDirectory(
        at: fixtureRoot,
        withIntermediateDirectories: true
    )

    _ = NSApplication.shared
    let app = AppCoordinator(userDefaults: userDefaults, databaseURL: databaseURL)
    let database = try #require(app.subtitleDatabase)
    let subtitleFile = URL(fileURLWithPath: "/Media/Playback-Shiori-Save.srt")
    let videoFile = URL(fileURLWithPath: "/Media/Playback-Shiori-Save.mkv")
    try indexPlaybackSubtitleCue(
        in: database,
        subtitleFile: subtitleFile,
        videoFile: videoFile
    )
    let player = PlaybackPlayer()
    let playbackViewModel = PlaybackViewModel(player: player)
    app.search.selectedSearchResult = SubtitleSearchResult(
        entryID: 1,
        subtitlePath: subtitleFile.path,
        subtitleFormat: .srt,
        videoPath: videoFile.path,
        videoName: videoFile.lastPathComponent,
        startMilliseconds: 1_000,
        endMilliseconds: 3_000,
        content: "playback saved cue",
        cueLines: ["playback saved cue"]
    )
    app.playback.playbackViewModel = playbackViewModel
    playbackViewModel.setSubtitleCues([], currentTimeMilliseconds: 1_500)

    #expect(try database.shioriCount() == 0)

    #expect(app.toggleCurrentShiori())

    let saved = try #require(try database.shioris().first)
    #expect(saved.subtitlePath == subtitleFile.path)
    #expect(saved.videoPath == videoFile.path)
    #expect(saved.content == "playback saved cue")
    #expect(playbackViewModel.feedback?.text == "Shiori Saved")
}

private func makeShiori(
    in database: SubtitleDatabase,
    id: Int,
    content: String
) throws -> Shiori {
    try database.upsertShiori(
        subtitleFile: URL(fileURLWithPath: "/Media/Shiori-\(id).srt"),
        subtitleFormat: .srt,
        videoFile: URL(fileURLWithPath: "/Media/Shiori-\(id).mkv"),
        videoName: "Shiori-\(id).mkv",
        selection: SubtitleCueTextSelection(
            cueGroupID: Int64(id),
            startMilliseconds: id * 1_000,
            endMilliseconds: id * 1_000 + 500,
            lines: [content]
        )
    )
}

private func makeIndexedPlaybackShiori(
    in database: SubtitleDatabase,
    subtitleFile: URL,
    videoFile: URL
) throws -> Shiori {
    try indexPlaybackSubtitleCue(
        in: database,
        subtitleFile: subtitleFile,
        videoFile: videoFile
    )

    return try database.upsertShiori(
        subtitleFile: subtitleFile,
        subtitleFormat: .srt,
        videoFile: videoFile,
        videoName: videoFile.lastPathComponent,
        selection: SubtitleCueTextSelection(
            cueGroupID: 1,
            startMilliseconds: 1_000,
            endMilliseconds: 3_000,
            lines: ["playback saved cue"]
        )
    )
}

private func indexPlaybackSubtitleCue(
    in database: SubtitleDatabase,
    subtitleFile: URL,
    videoFile: URL
) throws {
    try database.replaceEntries(
        subtitleFile: subtitleFile,
        videoFile: videoFile,
        entries: [
            SubtitleEntry(
                sequenceNumber: 1,
                startTimecode: "00:00:01,000",
                endTimecode: "00:00:03,000",
                startMilliseconds: 1_000,
                endMilliseconds: 3_000,
                text: "playback saved cue"
            )
        ]
    )
}
