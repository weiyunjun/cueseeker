import AppKit
import Foundation
import Testing
import CueSeekerCore
import CueSeekerPlayback
@testable import CueSeekerApp

@MainActor
@Test
func playbackViewModelForwardsAutoStopBoundary() async {
    let player = PlaybackPlayer()
    var reachedBoundaryEndMilliseconds: Int?
    let viewModel = PlaybackViewModel(
        player: player,
        onAutoStopBoundaryReached: { endMilliseconds in
            reachedBoundaryEndMilliseconds = endMilliseconds
        }
    )

    viewModel.isPlaying = true
    viewModel.player(player, didReachAutoStopBoundaryAtMilliseconds: 2_500)
    await Task.yield()

    #expect(reachedBoundaryEndMilliseconds == 2_500)
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
func appCoordinatorMarksSearchCueAutoPauseAsPaused() async throws {
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
        app.beginCueAutoStopPlayback()
        let boundary = app.configureCueAutoStopBoundary(
            startMilliseconds: 1_000,
            endMilliseconds: 2_500
        )

        app.handleCueAutoStopBoundaryReached(
            endMilliseconds: try #require(boundary?.endMilliseconds)
        )

        #expect(app.playback.playbackStatus == .paused)
        #expect(app.currentCueAutoStopReached)
        #expect(app.autoSwitchCueSequenceTask == nil)
    }
}

@MainActor
@Test
func appCoordinatorConsumesCueAutoPauseBoundaryOnlyOncePerArming() async throws {
    try await withTemporarySegmentCompletionApp { app, _ in
        app.playback.playbackStatus = .playing
        app.beginCueAutoStopPlayback()
        app.activateCueAutoStopBoundary(PlaybackAutoStopBoundary(
            startMilliseconds: 1_000,
            endMilliseconds: 2_500
        ))

        app.handleCueAutoStopBoundaryReached(endMilliseconds: 2_500)
        #expect(app.activeCueAutoPauseBoundary?.endMilliseconds == 2_500)
        #expect(!app.cueAutoPauseArmed)

        app.playback.playbackStatus = .playing
        app.currentCueAutoStopReached = false
        app.handleCueAutoStopBoundaryReached(endMilliseconds: 2_500)

        #expect(app.playback.playbackStatus == .playing)
        #expect(!app.currentCueAutoStopReached)
    }
}

@MainActor
@Test
func cueAutoPauseSeekRearmsOnlyBeforeCurrentItemBoundary() async throws {
    try await withTemporarySegmentCompletionApp { app, _ in
        app.settings.autoSwitchToNextCuesInPlaylistEnabled = true
        app.settings.setAutoSwitchCueSequenceGapMilliseconds(10_000)
        app.activePlaybackSource = .search
        app.playback.playbackStatus = .playing
        app.search.selectedSearchResult = segmentCompletionSearchResult(entryID: 1)
        app.beginCueAutoStopPlayback()
        app.activateCueAutoStopBoundary(PlaybackAutoStopBoundary(
            startMilliseconds: 1_000,
            endMilliseconds: 2_500
        ))

        app.handleCueAutoStopBoundaryReached(endMilliseconds: 2_500)
        #expect(!app.cueAutoPauseArmed)
        #expect(app.autoSwitchCueSequenceTask != nil)

        app.handleCueAutoPauseSeekCommitted(toMilliseconds: 3_000)
        #expect(app.activeCueAutoPauseBoundary?.endMilliseconds == 2_500)
        #expect(!app.cueAutoPauseArmed)
        #expect(app.autoSwitchCueSequenceTask == nil)

        app.playback.playbackStatus = .playing
        app.handleCueAutoStopBoundaryReached(endMilliseconds: 2_500)
        #expect(app.playback.playbackStatus == .playing)

        app.handleCueAutoPauseSeekCommitted(toMilliseconds: 1_500)
        #expect(app.cueAutoPauseArmed)

        app.handleCueAutoStopBoundaryReached(endMilliseconds: 2_500)
        #expect(app.playback.playbackStatus == .paused)
        #expect(app.currentCueAutoStopReached)
        #expect(!app.cueAutoPauseArmed)
        #expect(app.autoSwitchCueSequenceTask != nil)
        app.cancelAutoSwitchCueSequenceTask()
    }
}

@MainActor
@Test
func enteringOverlayCancelsPendingAutoSwitchWithoutClearingAutoPause() async throws {
    try await withTemporarySegmentCompletionApp { app, _ in
        app.ensurePlayerInitialized()
        app.settings.autoSwitchToNextCuesInPlaylistEnabled = true
        app.settings.setAutoSwitchCueSequenceGapMilliseconds(10_000)
        let result = segmentCompletionSearchResult(entryID: 1)
        app.activePlaybackSource = .search
        app.search.selectedSearchResult = result
        app.playback.playbackStatus = .playing
        app.beginCueAutoStopPlayback()
        app.activateCueAutoStopBoundary(PlaybackAutoStopBoundary(
            startMilliseconds: result.startMilliseconds,
            endMilliseconds: result.endMilliseconds
        ))
        app.handleCueAutoStopBoundaryReached(endMilliseconds: result.endMilliseconds)
        #expect(app.autoSwitchCueSequenceTask != nil)

        let opened = app.openPlaybackSubtitleFocusFromUser()

        #expect(opened)
        #expect(app.playback.subtitleFocusSession != nil)
        #expect(app.autoSwitchCueSequenceTask == nil)
        #expect(app.activeCueAutoPauseBoundary?.endMilliseconds == result.endMilliseconds)
        #expect(app.activePlaylistCueSettings?.autoSwitchEnabled == true)
        app.invalidatePlaybackSubtitleFocusForSourceReplacement()
    }
}

@MainActor
@Test
func newPlaylistIndexReinitializesBehaviorsAfterSeekInterruption() async throws {
    try await withTemporarySegmentCompletionApp { app, _ in
        let first = segmentCompletionSearchResult(entryID: 1)
        let second = SubtitleSearchResult(
            entryID: 2,
            subtitlePath: first.subtitlePath,
            subtitleFormat: first.subtitleFormat,
            videoPath: first.videoPath,
            videoName: first.videoName,
            startMilliseconds: 3_000,
            endMilliseconds: 4_500,
            content: "second",
            cueLines: ["second"]
        )
        let items = [first, second]
        let source = PlaybackPlaylistSource(
            origin: .search(resultListGeneration: 1),
            totalCount: items.count
        ) { ordinal in
            guard items.indices.contains(ordinal) else {
                return nil
            }
            return PlaybackPlaylistItem(
                searchResult: items[ordinal],
                ordinal: ordinal
            )
        }

        app.settings.autoSwitchToNextCuesInPlaylistEnabled = true
        app.settings.setAutoSwitchCueSequenceGapMilliseconds(10_000)
        app.activePlaybackSource = .search
        app.playback.setPlaylistSource(source, playbackSearchSelectedOrdinal: 0)
        app.search.selectedSearchResult = first
        app.playback.playbackStatus = .playing
        app.beginCueAutoStopPlayback()
        app.activateCueAutoStopBoundary(PlaybackAutoStopBoundary(
            startMilliseconds: first.startMilliseconds,
            endMilliseconds: first.endMilliseconds
        ))

        app.handleCueAutoStopBoundaryReached(endMilliseconds: first.endMilliseconds)
        #expect(app.autoSwitchCueSequenceTask != nil)

        app.handleCueAutoPauseSeekCommitted(toMilliseconds: 1_500)
        #expect(app.autoSwitchCueSequenceTask == nil)
        #expect(app.cueAutoPauseArmed)

        #expect(app.playback.setPlaylistPosition(at: 1))
        app.playback.playbackStatus = .playing
        app.handleCueAutoStopBoundaryReached(endMilliseconds: first.endMilliseconds)
        #expect(app.playback.playbackStatus == .playing)
        #expect(app.activePlaylistCuePosition?.ordinal == 0)

        app.search.selectedSearchResult = second
        app.beginCueAutoStopPlayback()
        let nextBoundary = app.configureCueAutoStopBoundary(
            startMilliseconds: second.startMilliseconds,
            endMilliseconds: second.endMilliseconds
        )

        #expect(nextBoundary?.endMilliseconds == second.endMilliseconds - 1)
        #expect(app.activePlaylistCuePosition?.ordinal == 1)
        #expect(app.activePlaylistCueSettings?.autoPauseEnabled == true)
        #expect(app.activePlaylistCueSettings?.autoSwitchEnabled == true)

        app.handleCueAutoStopBoundaryReached(
            endMilliseconds: try #require(nextBoundary?.endMilliseconds)
        )
        #expect(app.playback.playbackStatus == .paused)
        #expect(app.autoSwitchCueSequenceTask != nil)
        app.cancelAutoSwitchCueSequenceTask()
    }
}

@MainActor
@Test
func stoppingPlaybackClearsPlaylistCueRuntimeState() async throws {
    try await withTemporarySegmentCompletionApp { app, _ in
        app.ensurePlayerInitialized()
        app.settings.autoSwitchToNextCuesInPlaylistEnabled = true
        app.settings.setAutoSwitchCueSequenceGapMilliseconds(10_000)
        app.activePlaybackSource = .search
        app.search.selectedSearchResult = segmentCompletionSearchResult(entryID: 1)
        app.playback.playbackStatus = .playing
        app.beginCueAutoStopPlayback()
        app.activateCueAutoStopBoundary(PlaybackAutoStopBoundary(
            startMilliseconds: 1_000,
            endMilliseconds: 2_500
        ))
        app.handleCueAutoStopBoundaryReached(endMilliseconds: 2_500)
        #expect(app.autoSwitchCueSequenceTask != nil)

        app.stopPlayback()

        #expect(app.activeCueAutoPauseBoundary == nil)
        #expect(app.activePlaylistCueSettings == nil)
        #expect(app.activePlaylistCuePosition == nil)
        #expect(app.autoSwitchCueSequenceTask == nil)
    }
}

@MainActor
@Test
func clearedCueAutoPauseRejectsLateCompletionDuringContinuousPlayback() async throws {
    try await withTemporarySegmentCompletionApp { app, _ in
        app.activePlaybackSource = .search
        app.playback.playbackStatus = .playing
        app.settings.autoSwitchToNextCuesInPlaylistEnabled = true
        app.beginCueAutoStopPlayback()
        app.activateCueAutoStopBoundary(PlaybackAutoStopBoundary(
            startMilliseconds: 1_000,
            endMilliseconds: 2_500
        ))

        app.clearCueAutoStopPlayback()
        app.handleCueAutoStopBoundaryReached(endMilliseconds: 2_500)

        #expect(app.activeCueAutoPauseBoundary == nil)
        #expect(!app.cueAutoPauseArmed)
        #expect(app.playback.playbackStatus == .playing)
        #expect(!app.currentCueAutoStopReached)
        #expect(app.autoSwitchCueSequenceTask == nil)
    }
}

@MainActor
@Test
func appCoordinatorKeepsCurrentItemSettingsDuringAutoSwitchGap() async throws {
    try await withTemporarySegmentCompletionApp { app, _ in
        app.ensurePlayerInitialized()
        app.settings.autoSwitchToNextCuesInPlaylistEnabled = true
        app.settings.setAutoSwitchCueSequenceGapMilliseconds(10_000)
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
        app.beginCueAutoStopPlayback()
        let boundary = app.configureCueAutoStopBoundary(
            startMilliseconds: result.startMilliseconds,
            endMilliseconds: result.endMilliseconds
        )
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

        app.handleCueAutoStopBoundaryReached(
            endMilliseconds: try #require(boundary?.endMilliseconds)
        )

        #expect(app.playback.playbackStatus == .paused)
        #expect(app.currentCueAutoStopReached)
        #expect(app.playback.playbackViewModel?.activeSubtitleText == "hello")

        app.settings.setAutoSwitchCueSequenceGapMilliseconds(750)
        app.settings.autoPauseAfterCueFinishesEnabled = false
        await Task.yield()

        #expect(app.autoSwitchCueSequenceTask != nil)
        #expect(app.playback.playbackViewModel?.activeSubtitleText == "hello")
        #expect(app.activePlaylistCueSettings?.autoPauseEnabled == true)
        #expect(app.activePlaylistCueSettings?.autoSwitchEnabled == true)
        #expect(app.activePlaylistCueSettings?.autoSwitchGapMilliseconds == 10_000)

        app.beginCueAutoStopPlayback()

        #expect(app.activePlaylistCueSettings?.autoPauseEnabled == false)
        #expect(app.activePlaylistCueSettings?.autoSwitchEnabled == false)
        #expect(app.activePlaylistCueSettings?.autoSwitchGapMilliseconds == 750)
        #expect(app.autoSwitchCueSequenceTask == nil)
    }
}

@MainActor
@Test
func autoPauseHoldsCurrentCueAtAdjacentBoundaryWhenSelectionDiffers() async throws {
    try await withTemporarySegmentCompletionApp { app, _ in
        app.ensurePlayerInitialized()
        app.settings.autoPauseAfterCueFinishesEnabled = true
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
        app.search.selectedSearchResult = segmentCompletionSearchResult(entryID: 99)
        app.beginCueAutoStopPlayback()
        let boundary = app.configureCueAutoStopBoundary(
            startMilliseconds: result.startMilliseconds,
            endMilliseconds: result.endMilliseconds
        )
        app.playback.playbackViewModel?.setSubtitleCues(
            [
                PlaybackSubtitleCue(
                    startMilliseconds: result.startMilliseconds,
                    endMilliseconds: result.endMilliseconds,
                    text: result.content
                ),
                PlaybackSubtitleCue(
                    startMilliseconds: result.endMilliseconds,
                    endMilliseconds: 3_500,
                    text: "next"
                )
            ],
            currentTimeMilliseconds: result.endMilliseconds
        )

        #expect(app.playback.playbackViewModel?.activeSubtitleText == "next")

        app.handleCueAutoStopBoundaryReached(
            endMilliseconds: try #require(boundary?.endMilliseconds)
        )

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
        app.settings.autoPauseAfterCueFinishesEnabled = true
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
        app.beginCueAutoStopPlayback()
        let boundary = app.configureCueAutoStopBoundary(
            startMilliseconds: selectedShiori.startMilliseconds,
            endMilliseconds: selectedShiori.endMilliseconds
        )
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

        app.handleCueAutoStopBoundaryReached(
            endMilliseconds: try #require(boundary?.endMilliseconds)
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
            (autoPause: true, autoSwitch: false),
            (autoPause: true, autoSwitch: true),
            (autoPause: false, autoSwitch: false)
        ] {
            app.settings.autoPauseAfterCueFinishesEnabled = combination.autoPause
            app.settings.autoSwitchToNextCuesInPlaylistEnabled = combination.autoSwitch
            app.beginCueAutoStopPlayback()
            app.playback.playbackStatus = .playing

            let boundary = app.configureCueAutoStopBoundary(
                startMilliseconds: 1_000,
                endMilliseconds: 2_500
            )

            #expect((boundary != nil) == combination.autoPause)

            if combination.autoPause {
                app.handleCueAutoStopBoundaryReached(
                    endMilliseconds: try #require(boundary?.endMilliseconds)
                )

                #expect(app.playback.playbackStatus == .paused)
                #expect(app.currentCueAutoStopReached)
                #expect(
                    (app.autoSwitchCueSequenceTask != nil)
                        == combination.autoSwitch
                )
            } else {
                #expect(app.playback.playbackStatus == .playing)
                #expect(!app.currentCueAutoStopReached)
                #expect(app.autoSwitchCueSequenceTask == nil)
            }

            app.cancelAutoSwitchCueSequenceTask()
        }
    }
}

@MainActor
@Test
func zeroGapAutoSwitchConsumesOnlyTheCompletedAutoStopEvent() async throws {
    try await withTemporarySegmentCompletionApp { app, _ in
        app.settings.autoPauseAfterCueFinishesEnabled = true
        app.settings.autoSwitchToNextCuesInPlaylistEnabled = true
        app.settings.setAutoSwitchCueSequenceGapMilliseconds(0)
        app.activePlaybackSource = .search
        app.playback.playbackStatus = .playing
        app.search.selectedSearchResult = segmentCompletionSearchResult(entryID: 1)
        app.beginCueAutoStopPlayback()
        app.activateCueAutoStopBoundary(PlaybackAutoStopBoundary(
            startMilliseconds: 1_000,
            endMilliseconds: 2_500
        ))

        app.handleCueAutoStopBoundaryReached(endMilliseconds: 2_500)
        for _ in 0..<10 where app.autoSwitchCueSequenceTask != nil {
            await Task.yield()
        }

        #expect(app.autoSwitchCueSequenceTask == nil)
        #expect(!app.currentCueAutoStopReached)
    }
}

@MainActor
@Test
func manualResumeCancelsPendingCueAutoSwitch() async throws {
    try await withTemporarySegmentCompletionApp { app, _ in
        app.settings.autoPauseAfterCueFinishesEnabled = true
        app.settings.autoSwitchToNextCuesInPlaylistEnabled = true
        app.settings.setAutoSwitchCueSequenceGapMilliseconds(10_000)
        app.activePlaybackSource = .search
        app.playback.playbackStatus = .playing
        app.search.selectedSearchResult = segmentCompletionSearchResult(entryID: 1)
        app.beginCueAutoStopPlayback()
        app.activateCueAutoStopBoundary(PlaybackAutoStopBoundary(
            startMilliseconds: 1_000,
            endMilliseconds: 2_500
        ))
        app.handleCueAutoStopBoundaryReached(endMilliseconds: 2_500)
        #expect(app.autoSwitchCueSequenceTask != nil)

        app.resumePlayback()

        #expect(app.autoSwitchCueSequenceTask == nil)
        #expect(!app.currentCueAutoStopReached)
        #expect(app.playback.playbackStatus == .playing)
    }
}

@MainActor
@Test
func replacingCuePlaybackInvalidatesPendingCueAutoSwitch() async throws {
    try await withTemporarySegmentCompletionApp { app, _ in
        app.settings.autoPauseAfterCueFinishesEnabled = true
        app.settings.autoSwitchToNextCuesInPlaylistEnabled = true
        app.settings.setAutoSwitchCueSequenceGapMilliseconds(20)
        app.activePlaybackSource = .search
        app.playback.playbackStatus = .playing
        let original = segmentCompletionSearchResult(entryID: 1)
        app.search.selectedSearchResult = original
        app.beginCueAutoStopPlayback()
        app.activateCueAutoStopBoundary(PlaybackAutoStopBoundary(
            startMilliseconds: 1_000,
            endMilliseconds: 2_500
        ))
        app.handleCueAutoStopBoundaryReached(endMilliseconds: 2_500)
        #expect(app.autoSwitchCueSequenceTask != nil)

        app.beginCueAutoStopPlayback()
        try? await Task.sleep(nanoseconds: 40_000_000)

        #expect(app.autoSwitchCueSequenceTask == nil)
        #expect(!app.currentCueAutoStopReached)
        #expect(app.search.selectedSearchResult?.entryID == original.entryID)
    }
}

@MainActor
@Test
func everyInitializedPlaylistItemUsesItsAutoPauseSnapshot() async throws {
    try await withTemporarySegmentCompletionApp { app, _ in
        app.settings.autoPauseAfterCueFinishesEnabled = true
        app.settings.autoSwitchToNextCuesInPlaylistEnabled = true
        app.beginCueAutoStopPlayback()

        let boundary = app.configureCueAutoStopBoundary(
            startMilliseconds: 1_000,
            endMilliseconds: 2_500
        )

        #expect(boundary?.endMilliseconds == 2_499)
        #expect(app.activeCueAutoPauseBoundary == boundary)
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

private func segmentCompletionSearchResult(entryID: Int64) -> SubtitleSearchResult {
    SubtitleSearchResult(
        entryID: entryID,
        subtitlePath: "/Media/Segment.srt",
        subtitleFormat: .srt,
        videoPath: "/Media/Segment.mkv",
        videoName: "Segment",
        startMilliseconds: 1_000,
        endMilliseconds: 2_500,
        content: "hello",
        cueLines: ["hello"]
    )
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
