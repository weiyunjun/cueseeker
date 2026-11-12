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
    #expect(viewModel.effectiveFeedback?.text == "Loading")

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

@Test
@MainActor
func playbackPresentationAlignsPreTarget2msFrameCommitWithoutBlankingCueSubtitleWhilePreservingFarEarlierOrPostTargetFrames() async {
    let player = PlaybackPlayer()
    let viewModel = PlaybackViewModel(player: player)
    viewModel.duration = 1_500

    let cues = [
        PlaybackSubtitleCue(
            startMilliseconds: 1_096_080,
            endMilliseconds: 1_097_480,
            text: "お返事は何と。"
        ),
        PlaybackSubtitleCue(
            startMilliseconds: 1_099_350,
            endMilliseconds: 1_102_970,
            text: "「今宵月下の庭園で待つ」と。"
        ),
        PlaybackSubtitleCue(
            startMilliseconds: 2_010,
            endMilliseconds: 3_500,
            text: "ieee-754 boundary cue"
        )
    ]

    // 1. Seek to 18:19.35 (1_099_350ms) where covering 23.976fps frame commits 2ms early at 1_099_348ms:
    //    settled progress aligns to 1_099.35 and on-screen subtitle immediately displays the target cue.
    viewModel.preparePresentationTransition(
        to: 1_099.35,
        subtitleCues: cues
    )
    viewModel.bindPendingPresentation(to: 61)
    viewModel.player(
        player,
        didCommitPresentationAtMilliseconds: 1_099_348,
        generation: 61,
        playing: true,
        videoSize: CGSize(width: 1_920, height: 1_080)
    )
    await Task.yield()

    #expect(viewModel.currentTime == 1_099.35)
    #expect(viewModel.displayedCurrentTime == 1_099.35)
    #expect(viewModel.activeSubtitleText == "「今宵月下の庭園で待つ」と。")

    // 2. IEEE-754 decimal roundtrip target (Double(2_010) / 1_000) committing 2ms early at 2_008ms:
    //    targetMilliseconds rounds cleanly to 2_010ms rather than truncating to 2_009ms.
    let ieeeTargetSeconds = Double(2_010) / 1_000
    viewModel.prepareNewVideoOpening(
        to: ieeeTargetSeconds,
        subtitleCues: cues
    )
    viewModel.bindPendingPresentation(to: 62)
    viewModel.player(
        player,
        didCommitPresentationAtMilliseconds: 2_008,
        generation: 62,
        playing: true,
        videoSize: CGSize(width: 1_920, height: 1_080)
    )
    await Task.yield()

    #expect(viewModel.currentTime == 2.01)
    #expect(viewModel.displayedCurrentTime == 2.01)
    #expect(viewModel.activeSubtitleText == "ieee-754 boundary cue")

    // 3. Frame earlier by more than 2ms (e.g. post-EOF seek) preserves actual frame timestamp.
    viewModel.preparePresentationTransition(to: 6.0, subtitleCues: cues)
    viewModel.bindPendingPresentation(to: 63)
    viewModel.player(
        player,
        didCommitPresentationAtMilliseconds: 5_950,
        generation: 63,
        playing: false,
        videoSize: CGSize(width: 1_920, height: 1_080)
    )
    await Task.yield()

    #expect(viewModel.currentTime == 5.95)
    #expect(viewModel.displayedCurrentTime == 5.95)

    // 4. Frame at or after target preserves actual frame timestamp.
    viewModel.preparePresentationTransition(to: 6.0, subtitleCues: cues)
    viewModel.bindPendingPresentation(to: 64)
    viewModel.player(
        player,
        didCommitPresentationAtMilliseconds: 6_016,
        generation: 64,
        playing: true,
        videoSize: CGSize(width: 1_920, height: 1_080)
    )
    await Task.yield()

    #expect(viewModel.currentTime == 6.016)
    #expect(viewModel.displayedCurrentTime == 6.016)
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
