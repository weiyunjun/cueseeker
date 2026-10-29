import Foundation
import Testing
import CueSeekerPlayback
@testable import CueSeekerApp

@Test
@MainActor
func playbackInVideoTransitionImmediatelyUpdatesProgressToTargetAndHoldsSubtitleUntilCommit() async {
    let player = PlaybackPlayer()
    var committedPlayingStates: [Bool] = []
    let viewModel = PlaybackViewModel(
        player: player,
        onPresentationCommitted: { playing in
            committedPlayingStates.append(playing)
        }
    )
    viewModel.duration = 90
    viewModel.setSubtitleCues(
        [presentationCue(text: "old", startMilliseconds: 1_000)],
        currentTimeMilliseconds: 1_000
    )
    viewModel.isPlaying = true
    viewModel.player(player, didUpdateVideoAspectRatio: 16.0 / 9.0)
    await Task.yield()

    viewModel.preparePresentationTransition(
        to: 6,
        subtitleCues: [presentationCue(text: "target", startMilliseconds: 6_000)]
    )
    viewModel.bindPendingPresentation(to: 41)

    #expect(!viewModel.isOpeningNewVideo)
    #expect(viewModel.currentTime == 6)
    #expect(viewModel.displayedCurrentTime == 6)
    #expect(viewModel.duration == 90)

    viewModel.player(player, didUpdateTimePosition: 2.0)
    viewModel.player(player, didUpdateDuration: 120)
    viewModel.player(player, didUpdateVideoAspectRatio: 4.0 / 3.0)
    viewModel.player(player, didUpdatePaused: true)
    await Task.yield()

    #expect(viewModel.currentTime == 6)
    #expect(viewModel.displayedCurrentTime == 6)
    #expect(viewModel.activeSubtitleText == "old")
    #expect(viewModel.isPlaying)
    #expect(viewModel.duration == 90)
    #expect(viewModel.videoAspectRatio == 16.0 / 9.0)
    #expect(committedPlayingStates.isEmpty)

    viewModel.player(
        player,
        didCommitPresentationAtMilliseconds: 6_100,
        generation: 41,
        playing: true,
        videoSize: CGSize(width: 1_440, height: 1_080)
    )
    #expect(viewModel.videoAspectRatio == 4.0 / 3.0)
    await Task.yield()

    #expect(viewModel.currentTime == 6.1)
    #expect(viewModel.displayedCurrentTime == 6.1)
    #expect(viewModel.activeSubtitleText == "target")
    #expect(viewModel.isPlaying)
    #expect(committedPlayingStates == [true])
}

@Test
@MainActor
func playbackNewVideoOpeningResetsProgressToZeroAndIgnoresPlayPauseUntilCommit() async {
    let player = PlaybackPlayer()
    var committedPlayingStates: [Bool] = []
    let viewModel = PlaybackViewModel(
        player: player,
        onPresentationCommitted: { playing in
            committedPlayingStates.append(playing)
        }
    )
    viewModel.duration = 180
    viewModel.setSubtitleCues(
        [presentationCue(text: "previous video cue", startMilliseconds: 42_000)],
        currentTimeMilliseconds: 42_000
    )
    viewModel.isPlaying = false
    viewModel.player(player, didUpdateVideoAspectRatio: 16.0 / 9.0)
    await Task.yield()

    viewModel.prepareNewVideoOpening(
        to: 15,
        subtitleCues: [presentationCue(text: "new video cue", startMilliseconds: 15_000)]
    )
    viewModel.bindPendingPresentation(to: 77)

    #expect(viewModel.isOpeningNewVideo)
    #expect(viewModel.currentTime == 0)
    #expect(viewModel.displayedCurrentTime == 0)
    #expect(viewModel.duration == 0)
    #expect(viewModel.isPlaying)
    #expect(viewModel.activeSubtitleText == "previous video cue")

    // Play/pause toggle is ignored while the new video has not completed initial load.
    viewModel.togglePlayPause()
    #expect(viewModel.isPlaying)
    #expect(viewModel.feedback == nil)

    viewModel.player(
        player,
        didCommitPresentationAtMilliseconds: 15_000,
        generation: 77,
        playing: true,
        videoSize: CGSize(width: 1_920, height: 1_080)
    )
    await Task.yield()

    #expect(!viewModel.isOpeningNewVideo)
    #expect(viewModel.currentTime == 15)
    #expect(viewModel.displayedCurrentTime == 15)
    #expect(viewModel.activeSubtitleText == "new video cue")
    #expect(viewModel.isPlaying)
    #expect(committedPlayingStates == [true])
}

@Test
@MainActor
func playbackLoadingFeedbackAppearsAfter300msAndCountsDelayAfterTransientHUDCompletes() async {
    #expect(PlaybackChromeMetrics.feedbackSpinnerSize == 23)
    #expect(PlaybackChromeMetrics.loadingFeedbackDelayMilliseconds == 300)

    let player = PlaybackPlayer()
    let viewModel = PlaybackViewModel(player: player)

    viewModel.prepareNewVideoOpening(to: 10)
    viewModel.bindPendingPresentation(to: 99)

    // Immediately after trigger (< 300ms), loading spinner is not visible.
    #expect(!viewModel.isLoadingFeedbackVisible)
    #expect(viewModel.effectiveFeedback == nil)

    // Without a transient HUD, waiting past 300ms shows the loading spinner.
    try? await Task.sleep(
        nanoseconds: (PlaybackChromeMetrics.loadingFeedbackDelayMilliseconds + 60) * 1_000_000
    )
    await Task.yield()
    #expect(viewModel.isLoadingFeedbackVisible)
    #expect(viewModel.effectiveFeedback == .loading)

    // Triggering a transient action HUD takes over the center slot and resets the loading timer
    // so that the 300ms threshold is counted AFTER the action HUD finishes playing.
    viewModel.showFeedback(
        PlaybackFeedback(icon: .caretRight, text: "Next Video"),
        durationMilliseconds: 120
    )
    #expect(!viewModel.isLoadingFeedbackVisible)
    #expect(viewModel.effectiveFeedback?.showsSpinner == false)
    #expect(viewModel.effectiveFeedback?.text == "Next Video")

    // Wait for the 120ms action HUD to finish playing (+40ms margin, still < 300ms after HUD end).
    try? await Task.sleep(nanoseconds: 160 * 1_000_000)
    await Task.yield()
    #expect(viewModel.feedback == nil)
    #expect(!viewModel.isLoadingFeedbackVisible)
    #expect(viewModel.effectiveFeedback == nil)

    // Once 300ms have elapsed after the action HUD finished and the frame is still pending,
    // the loading spinner appears.
    try? await Task.sleep(
        nanoseconds: (PlaybackChromeMetrics.loadingFeedbackDelayMilliseconds + 60) * 1_000_000
    )
    await Task.yield()
    #expect(viewModel.isLoadingFeedbackVisible)
    #expect(viewModel.effectiveFeedback == .loading)
    #expect(viewModel.effectiveFeedback?.showsSpinner == true)
    #expect(viewModel.effectiveFeedback?.text == nil)

    // Committing the target frame immediately dismisses the loading spinner.
    viewModel.player(
        player,
        didCommitPresentationAtMilliseconds: 10_000,
        generation: 99,
        playing: true,
        videoSize: CGSize(width: 1_920, height: 1_080)
    )
    #expect(!viewModel.isLoadingFeedbackVisible)
    #expect(viewModel.effectiveFeedback == nil)
}

@Test
@MainActor
func playbackPresentationRejectsSupersededGenerationAndCommitsOnlyLatestTarget() async {
    let player = PlaybackPlayer()
    var committedPlayingStates: [Bool] = []
    let viewModel = PlaybackViewModel(
        player: player,
        onPresentationCommitted: { playing in
            committedPlayingStates.append(playing)
        }
    )
    viewModel.duration = 60
    viewModel.setSubtitleCues(
        [presentationCue(text: "old", startMilliseconds: 1_000)],
        currentTimeMilliseconds: 1_000
    )
    viewModel.isPlaying = true
    let initialAspectRatio = 16.0 / 9.0

    viewModel.preparePresentationTransition(
        to: 6,
        subtitleCues: [presentationCue(text: "superseded", startMilliseconds: 6_000)]
    )
    viewModel.bindPendingPresentation(to: 50)
    #expect(viewModel.currentTime == 6)
    #expect(viewModel.displayedCurrentTime == 6)

    viewModel.preparePresentationTransition(
        to: 11,
        subtitleCues: [presentationCue(text: "latest", startMilliseconds: 11_000)]
    )
    viewModel.bindPendingPresentation(to: 51)
    #expect(viewModel.currentTime == 11)
    #expect(viewModel.displayedCurrentTime == 11)

    viewModel.player(
        player,
        didCommitPresentationAtMilliseconds: 6_000,
        generation: 50,
        playing: true,
        videoSize: CGSize(width: 1_440, height: 1_080)
    )
    #expect(viewModel.videoAspectRatio == initialAspectRatio)
    await Task.yield()

    #expect(viewModel.currentTime == 11)
    #expect(viewModel.displayedCurrentTime == 11)
    #expect(viewModel.activeSubtitleText == "old")
    #expect(viewModel.isPlaying)
    #expect(committedPlayingStates.isEmpty)

    viewModel.player(player, didUpdateTimePosition: 2.2)
    await Task.yield()
    #expect(viewModel.currentTime == 11)
    #expect(viewModel.activeSubtitleText == "old")

    viewModel.player(
        player,
        didCommitPresentationAtMilliseconds: 11_000,
        generation: 51,
        playing: false,
        videoSize: CGSize(width: 3_840, height: 1_608)
    )
    #expect(viewModel.videoAspectRatio == 3_840.0 / 1_608.0)
    await Task.yield()

    #expect(viewModel.currentTime == 11)
    #expect(viewModel.displayedCurrentTime == 11)
    #expect(viewModel.activeSubtitleText == "latest")
    #expect(!viewModel.isPlaying)
    #expect(committedPlayingStates == [false])
}

private func presentationCue(
    text: String,
    startMilliseconds: Int
) -> PlaybackSubtitleCue {
    PlaybackSubtitleCue(
        startMilliseconds: startMilliseconds,
        endMilliseconds: startMilliseconds + 1_000,
        text: text
    )
}
