import AppKit
import Foundation
import Testing
import CueSeekerCore
import CueSeekerPlayback
@testable import CueSeekerApp

@MainActor
@Test
func playbackViewModelForwardsSegmentCompletion() async {
    let player = PlaybackPlayer()
    var finishedSegmentEndMilliseconds: Int?
    let viewModel = PlaybackViewModel(
        player: player,
        onSegmentFinished: { endMilliseconds in
            finishedSegmentEndMilliseconds = endMilliseconds
        }
    )

    viewModel.isPlaying = true
    viewModel.player(player, didFinishSegmentAtMilliseconds: 2_500)
    await Task.yield()

    #expect(finishedSegmentEndMilliseconds == 2_500)
    #expect(!viewModel.isPlaying)
}

@MainActor
@Test
func appCoordinatorMarksSearchCueSegmentFinishedAsPaused() async throws {
    try await withTemporarySegmentCompletionApp { app, _ in
        app.activePlaybackSource = .search
        app.playback.playbackStatus = .playing
        app.search.selectedSearchResult = SubtitleSearchResult(
            entryID: 1,
            subtitlePath: "/Media/Segment.srt",
            subtitleFormat: .srt,
            videoPath: "/Media/Segment.mkv",
            videoName: "Segment",
            startMilliseconds: 1_000,
            endMilliseconds: 2_500,
            content: "hello",
            cueLines: ["hello"]
        )

        app.handlePlaybackSegmentFinished(endMilliseconds: 2_500)

        #expect(app.playback.playbackStatus == .paused)
        #expect(app.currentCueSegmentFinished)
    }
}

@MainActor
@Test
func appCoordinatorOnlyBoundsCuePlaybackWhenAutoSwitchIsEnabled() async throws {
    try await withTemporarySegmentCompletionApp { app, _ in
        #expect(app.autoSwitchCuePlaybackSegment(
            startMilliseconds: 1_000,
            endMilliseconds: 2_500
        ) == nil)

        app.settings.autoPlayCueSequenceEnabled = true
        let segment = try #require(app.autoSwitchCuePlaybackSegment(
            startMilliseconds: 1_000,
            endMilliseconds: 2_500
        ))

        #expect(segment.startMilliseconds == 1_000)
        #expect(segment.endMilliseconds == 2_500)
    }
}

@MainActor
private func withTemporarySegmentCompletionApp(
    _ body: @MainActor (AppCoordinator, SubtitleDatabase) async throws -> Void
) async throws {
    let suiteName = "CueSeekerSegmentCompletionTests-\(UUID().uuidString)"
    let userDefaults = try #require(UserDefaults(suiteName: suiteName))
    let databaseURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("CueSeekerSegmentCompletionTests-\(UUID().uuidString)")
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
