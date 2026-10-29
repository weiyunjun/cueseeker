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
func playbackLoadingFeedbackAppearsAfter150msYieldsToTransientHUDAndClearsOnCommit() async {
    let player = PlaybackPlayer()
    let viewModel = PlaybackViewModel(player: player)

    viewModel.prepareNewVideoOpening(to: 10)
    viewModel.bindPendingPresentation(to: 99)

    // Immediately after trigger (< 150ms), loading spinner is not visible.
    #expect(!viewModel.isLoadingFeedbackVisible)
    #expect(viewModel.effectiveFeedback == nil)

    // Triggering a transient navigation HUD takes priority in the single center slot.
    viewModel.showSearchNavigationFeedback(direction: .next, hasResult: true)
    #expect(viewModel.effectiveFeedback?.showsSpinner == false)
    #expect(viewModel.effectiveFeedback?.text != nil)

    try? await Task.sleep(
        nanoseconds: (PlaybackChromeMetrics.loadingFeedbackDelayMilliseconds + 60) * 1_000_000
    )
    await Task.yield()

    // After 150ms, loading feedback is armed, but transient HUD still holds priority.
    #expect(viewModel.isLoadingFeedbackVisible)
    #expect(viewModel.effectiveFeedback?.showsSpinner == false)

    // Once the transient HUD finishes (or clears), the loading spinner seamlessly takes over.
    viewModel.feedback = nil
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
