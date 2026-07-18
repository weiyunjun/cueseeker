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
func playbackViewModelHoldsSubtitlePresentationAtCueInteriorTimestamp() {
    let player = PlaybackPlayer()
    let viewModel = PlaybackViewModel(player: player)
    viewModel.setSubtitleCues(
        [
            PlaybackSubtitleCue(
                startMilliseconds: 1_000,
                endMilliseconds: 2_500,
                text: "hello"
            )
        ],
        currentTimeMilliseconds: 2_500
    )

    #expect(viewModel.activeSubtitleText == nil)

    viewModel.holdSubtitlePresentation(atMilliseconds: 2_499)

    #expect(viewModel.activeSubtitleText == "hello")

    viewModel.clearSubtitlePresentationHold()

    #expect(viewModel.activeSubtitleText == nil)
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
        app.activateCueSegmentPlayback(PlaybackSegment(
            startMilliseconds: 1_000,
            endMilliseconds: 2_500
        ))

        app.handlePlaybackSegmentFinished(endMilliseconds: 2_500)

        #expect(app.playback.playbackStatus == .paused)
        #expect(app.currentCueSegmentFinished)
        #expect(app.currentCueAutoSwitchBoundaryReached)
        #expect(app.autoSwitchCueSequenceTask == nil)
    }
}

@MainActor
@Test
func appCoordinatorConsumesCueSegmentCompletionOnlyOnce() async throws {
    try await withTemporarySegmentCompletionApp { app, _ in
        app.playback.playbackStatus = .playing
        app.activateCueSegmentPlayback(PlaybackSegment(
            startMilliseconds: 1_000,
            endMilliseconds: 2_500
        ))

        app.handlePlaybackSegmentFinished(endMilliseconds: 2_500)
        #expect(app.activeCueSegmentEndMilliseconds == nil)

        app.playback.playbackStatus = .playing
        app.currentCueSegmentFinished = false
        app.currentCueAutoSwitchBoundaryReached = false
        app.handlePlaybackSegmentFinished(endMilliseconds: 2_500)

        #expect(app.playback.playbackStatus == .playing)
        #expect(!app.currentCueSegmentFinished)
        #expect(!app.currentCueAutoSwitchBoundaryReached)
    }
}

@MainActor
@Test
func clearedCueSegmentRejectsLateCompletionDuringContinuousPlayback() async throws {
    try await withTemporarySegmentCompletionApp { app, _ in
        app.activePlaybackSource = .search
        app.playback.playbackStatus = .playing
        app.settings.autoSwitchToNextCuesInPlaylistEnabled = true
        app.activateCueSegmentPlayback(PlaybackSegment(
            startMilliseconds: 1_000,
            endMilliseconds: 2_500
        ))

        app.clearCueSegmentPlayback()
        app.handlePlaybackSegmentFinished(endMilliseconds: 2_500)

        #expect(app.activeCueSegmentEndMilliseconds == nil)
        #expect(app.playback.playbackStatus == .playing)
        #expect(!app.currentCueSegmentFinished)
        #expect(!app.currentCueAutoSwitchBoundaryReached)
        #expect(app.autoSwitchCueSequenceTask == nil)
    }
}

@MainActor
@Test
func appCoordinatorHoldsSearchCueSubtitleDuringAutoSwitchGap() async throws {
    try await withTemporarySegmentCompletionApp { app, _ in
        app.ensurePlayerInitialized()
        app.settings.autoSwitchToNextCuesInPlaylistEnabled = true
        let result = SubtitleSearchResult(
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
        app.activePlaybackSource = .search
        app.playback.playbackStatus = .playing
        app.search.selectedSearchResult = result
        app.activateCueSegmentPlayback(PlaybackSegment(
            startMilliseconds: result.startMilliseconds,
            endMilliseconds: result.endMilliseconds
        ))
        app.playback.playbackViewModel?.setSubtitleCues(
            [
                PlaybackSubtitleCue(
                    startMilliseconds: result.startMilliseconds,
                    endMilliseconds: result.endMilliseconds,
                    text: result.content
                )
            ],
            currentTimeMilliseconds: result.endMilliseconds
        )

        #expect(app.playback.playbackViewModel?.activeSubtitleText == nil)

        app.handlePlaybackSegmentFinished(endMilliseconds: result.endMilliseconds)

        #expect(app.playback.playbackStatus == .paused)
        #expect(app.currentCueSegmentFinished)
        #expect(app.playback.playbackViewModel?.activeSubtitleText == "hello")

        app.settings.autoSwitchToNextCuesInPlaylistEnabled = false
        await Task.yield()

        #expect(app.autoSwitchCueSequenceTask == nil)
        #expect(app.playback.playbackViewModel?.activeSubtitleText == "hello")
    }
}

@MainActor
@Test
func appCoordinatorKeepsStoppedCueSubtitleWithoutAutoSwitch() async throws {
    try await withTemporarySegmentCompletionApp { app, _ in
        app.ensurePlayerInitialized()
        app.settings.onlyPlayCuesInPlaylistEnabled = true
        app.settings.autoSwitchToNextCuesInPlaylistEnabled = false
        let result = SubtitleSearchResult(
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
        app.activePlaybackSource = .search
        app.playback.playbackStatus = .playing
        app.search.selectedSearchResult = result
        app.activateCueSegmentPlayback(PlaybackSegment(
            startMilliseconds: result.startMilliseconds,
            endMilliseconds: result.endMilliseconds
        ))
        app.playback.playbackViewModel?.setSubtitleCues(
            [
                PlaybackSubtitleCue(
                    startMilliseconds: result.startMilliseconds,
                    endMilliseconds: result.endMilliseconds,
                    text: result.content
                )
            ],
            currentTimeMilliseconds: result.endMilliseconds
        )

        app.handlePlaybackSegmentFinished(endMilliseconds: result.endMilliseconds)

        #expect(app.playback.playbackStatus == .paused)
        #expect(app.autoSwitchCueSequenceTask == nil)
        #expect(app.playback.playbackViewModel?.activeSubtitleText == "hello")
    }
}

@MainActor
@Test
func appCoordinatorKeepsStoppedShioriSubtitleWithoutAutoSwitch() async throws {
    try await withTemporarySegmentCompletionApp { app, _ in
        app.ensurePlayerInitialized()
        app.settings.onlyPlayCuesInPlaylistEnabled = true
        app.settings.autoSwitchToNextCuesInPlaylistEnabled = false
        let selectedShiori = Shiori(
            id: 1,
            subtitlePath: "/Media/Segment.srt",
            subtitleFormat: .srt,
            videoPath: "/Media/Segment.mkv",
            videoName: "Segment",
            startMilliseconds: 1_000,
            endMilliseconds: 2_500,
            content: "hello",
            isValid: true,
            createdAt: "2026-07-18T00:00:00Z"
        )
        app.activePlaybackSource = .shiori
        app.playback.playbackStatus = .playing
        app.shiori.selectedShiori = selectedShiori
        app.activateCueSegmentPlayback(PlaybackSegment(
            startMilliseconds: selectedShiori.startMilliseconds,
            endMilliseconds: selectedShiori.endMilliseconds
        ))
        app.playback.playbackViewModel?.setSubtitleCues(
            [
                PlaybackSubtitleCue(
                    startMilliseconds: selectedShiori.startMilliseconds,
                    endMilliseconds: selectedShiori.endMilliseconds,
                    text: selectedShiori.content
                )
            ],
            currentTimeMilliseconds: selectedShiori.endMilliseconds
        )

        app.handlePlaybackSegmentFinished(
            endMilliseconds: selectedShiori.endMilliseconds
        )

        #expect(app.playback.playbackStatus == .paused)
        #expect(app.autoSwitchCueSequenceTask == nil)
        #expect(app.playback.playbackViewModel?.activeSubtitleText == "hello")
    }
}

@MainActor
@Test
func playlistCueSettingsSupportOnlyThreeValidCombinations() async throws {
    try await withTemporarySegmentCompletionApp { app, _ in
        app.activePlaybackSource = .search
        app.settings.setAutoSwitchCueSequenceGapMilliseconds(10_000)

        for combination in [
            (onlyPlay: true, autoSwitch: false),
            (onlyPlay: true, autoSwitch: true),
            (onlyPlay: false, autoSwitch: false)
        ] {
            app.beginCueSegmentPlayback()
            app.settings.onlyPlayCuesInPlaylistEnabled = combination.onlyPlay
            app.settings.autoSwitchToNextCuesInPlaylistEnabled = combination.autoSwitch
            app.playback.playbackStatus = .playing

            let segment = app.configureCuePlaybackBoundary(
                startMilliseconds: 1_000,
                endMilliseconds: 2_500
            )

            #expect((segment != nil) == combination.onlyPlay)

            if combination.onlyPlay {
                app.handlePlaybackSegmentFinished(endMilliseconds: 2_500)

                #expect(app.playback.playbackStatus == .paused)
                #expect(app.currentCueSegmentFinished)
                #expect(
                    (app.autoSwitchCueSequenceTask != nil)
                        == combination.autoSwitch
                )
            } else {
                #expect(app.playback.playbackStatus == .playing)
                #expect(!app.currentCueSegmentFinished)
                #expect(!app.currentCueAutoSwitchBoundaryReached)
                #expect(app.autoSwitchCueSequenceTask == nil)
            }

            app.cancelAutoSwitchCueSequenceTask()
        }
    }
}

@MainActor
@Test
func continuousFromStartBypassesBothPlaylistCueBehaviors() async throws {
    try await withTemporarySegmentCompletionApp { app, _ in
        app.settings.onlyPlayCuesInPlaylistEnabled = true
        app.settings.autoSwitchToNextCuesInPlaylistEnabled = true

        let segment = app.configureCuePlaybackBoundary(
            startMilliseconds: 1_000,
            endMilliseconds: 2_500,
            playsContinuouslyFromStart: true
        )

        #expect(segment == nil)
        #expect(app.activeCueSegmentEndMilliseconds == nil)
        #expect(app.autoSwitchCueSequenceTask == nil)
    }
}

@MainActor
@Test
func closingLibraryPlaybackSavesHistoryAndMarksHistoryRevision() async throws {
    try await withTemporarySegmentCompletionApp { app, database in
        let videoURL = URL(fileURLWithPath: "/Media/Show/Episode 1.mkv")
        try database.replaceEntries(
            subtitleFile: URL(fileURLWithPath: "/Media/Show/Episode 1.srt"),
            videoFile: videoURL,
            entries: [
                SubtitleEntry(
                    sequenceNumber: 1,
                    startTimecode: "00:00:01,000",
                    endTimecode: "00:00:02,000",
                    startMilliseconds: 1_000,
                    endMilliseconds: 2_000,
                    text: "library close progress"
                )
            ]
        )

        app.ensurePlayerInitialized()
        let playbackViewModel = try #require(app.playback.playbackViewModel)
        let player = try #require(app.player)
        app.activePlaybackSource = .library(videoPath: videoURL.path)

        playbackViewModel.player(player, didChangeProperty: "time-pos", value: .double(42.5))
        playbackViewModel.player(player, didChangeProperty: "duration", value: .double(100.0))
        await Task.yield()

        let revisionBeforeSave = app.library.libraryPlaybackHistoryRevision
        let completeRevisionBeforeSave = app.library.completeLibraryRevision

        app.saveCurrentLibraryPlaybackHistoryForPlaybackClose()

        let history = try #require(try database.libraryPlaybackHistory(forVideoFile: videoURL))
        #expect(history.positionMilliseconds == 42_500)
        #expect(history.duration == 100.0)
        #expect(app.library.libraryPlaybackHistoryRevision == revisionBeforeSave + 1)
        #expect(app.library.completeLibraryRevision == completeRevisionBeforeSave)
        #expect(app.completeLibraryTask == nil)
    }
}

@MainActor
@Test
func libraryPlaybackCompletionMilestoneSurvivesSeekingBackBeforeClose() async throws {
    try await withTemporarySegmentCompletionApp { app, database in
        let videoURL = URL(fileURLWithPath: "/Media/Show/Episode 1.mkv")
        try database.replaceEntries(
            subtitleFile: URL(fileURLWithPath: "/Media/Show/Episode 1.srt"),
            videoFile: videoURL,
            entries: [
                SubtitleEntry(
                    sequenceNumber: 1,
                    startTimecode: "00:01:24,000",
                    endTimecode: "00:01:25,000",
                    startMilliseconds: 84_000,
                    endMilliseconds: 85_000,
                    text: "library completion milestone"
                )
            ]
        )

        app.ensurePlayerInitialized()
        defer {
            app.stopLibraryPlaybackHistoryTracking()
        }

        let playbackViewModel = try #require(app.playback.playbackViewModel)
        let player = try #require(app.player)
        app.startLibraryPlaybackHistoryTracking(videoPath: videoURL.path)

        playbackViewModel.player(player, didChangeProperty: "duration", value: .double(100.0))
        await Task.yield()
        playbackViewModel.player(player, didChangeProperty: "time-pos", value: .double(85.0))
        await Task.yield()
        #expect(
            app.pendingLibraryPlaybackHistoryPresentationVideoPaths
                == Set([videoURL.path])
        )
        playbackViewModel.player(player, didChangeProperty: "time-pos", value: .double(42.5))
        await Task.yield()

        app.saveCurrentLibraryPlaybackHistoryForPlaybackClose()
        #expect(app.pendingLibraryPlaybackHistoryPresentationVideoPaths.isEmpty)

        let history = try #require(try database.libraryPlaybackHistory(forVideoFile: videoURL))
        #expect(history.positionMilliseconds == 42_500)
        #expect(history.duration == 100.0)
        #expect(history.completedAt != nil)
        #expect(LibraryWatchState(
            positionMilliseconds: history.positionMilliseconds,
            duration: history.duration,
            startedAt: history.startedAt,
            completedAt: history.completedAt
        ) == .finished)
    }
}

@MainActor
@Test
func libraryPlaybackHistorySaveMarksCompletedWhenPositionReachedFinishPoint() async throws {
    try await withTemporarySegmentCompletionApp { app, database in
        let videoURL = URL(fileURLWithPath: "/Media/Show/Episode 1.mkv")
        try database.replaceEntries(
            subtitleFile: URL(fileURLWithPath: "/Media/Show/Episode 1.srt"),
            videoFile: videoURL,
            entries: [
                SubtitleEntry(
                    sequenceNumber: 1,
                    startTimecode: "00:01:24,000",
                    endTimecode: "00:01:25,000",
                    startMilliseconds: 84_000,
                    endMilliseconds: 85_000,
                    text: "library completion milestone"
                )
            ]
        )

        app.ensurePlayerInitialized()
        defer {
            app.stopLibraryPlaybackHistoryTracking()
        }

        let playbackViewModel = try #require(app.playback.playbackViewModel)
        let player = try #require(app.player)
        playbackViewModel.player(player, didChangeProperty: "duration", value: .double(100.0))
        playbackViewModel.player(player, didChangeProperty: "time-pos", value: .double(85.0))
        await Task.yield()

        app.startLibraryPlaybackHistoryTracking(videoPath: videoURL.path)
        app.saveCurrentLibraryPlaybackHistorySynchronously()

        let history = try #require(try database.libraryPlaybackHistory(forVideoFile: videoURL))
        #expect(history.positionMilliseconds == 85_000)
        #expect(history.completedAt != nil)
        #expect(LibraryWatchState(
            positionMilliseconds: history.positionMilliseconds,
            duration: history.duration,
            startedAt: history.startedAt,
            completedAt: history.completedAt
        ) == .finished)
    }
}

@MainActor
@Test
func libraryPlaybackCompletionUsesVideoEndWhenLastSubtitleIsBeforeThreshold() async throws {
    try await withTemporarySegmentCompletionApp { app, database in
        let videoURL = URL(fileURLWithPath: "/Media/Show/Episode 1.mkv")
        try database.replaceEntries(
            subtitleFile: URL(fileURLWithPath: "/Media/Show/Episode 1.srt"),
            videoFile: videoURL,
            entries: [
                SubtitleEntry(
                    sequenceNumber: 1,
                    startTimecode: "00:00:01,000",
                    endTimecode: "00:00:02,000",
                    startMilliseconds: 1_000,
                    endMilliseconds: 2_000,
                    text: "early subtitle"
                )
            ]
        )

        app.ensurePlayerInitialized()
        defer {
            app.stopLibraryPlaybackHistoryTracking()
        }

        let playbackViewModel = try #require(app.playback.playbackViewModel)
        let player = try #require(app.player)
        app.startLibraryPlaybackHistoryTracking(videoPath: videoURL.path)

        playbackViewModel.player(player, didChangeProperty: "duration", value: .double(100.0))
        await Task.yield()
        playbackViewModel.player(player, didChangeProperty: "time-pos", value: .double(96.0))
        await Task.yield()
        app.saveCurrentLibraryPlaybackHistorySynchronously()

        let progressHistory = try #require(try database.libraryPlaybackHistory(forVideoFile: videoURL))
        #expect(progressHistory.completedAt == nil)

        playbackViewModel.player(player, didChangeProperty: "time-pos", value: .double(100.0))
        await Task.yield()
        app.saveCurrentLibraryPlaybackHistoryForPlaybackClose()

        let finishedHistory = try #require(try database.libraryPlaybackHistory(forVideoFile: videoURL))
        #expect(finishedHistory.completedAt != nil)
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
