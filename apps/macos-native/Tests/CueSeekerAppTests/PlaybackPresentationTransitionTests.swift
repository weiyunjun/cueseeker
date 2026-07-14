import Foundation
import Testing
import CueSeekerPlayback
@testable import CueSeekerApp

@Test
@MainActor
func playbackPresentationKeepsOldSubtitleAndTimeUntilMatchingFrameCommit() async {
    let player = PlaybackPlayer()
    var committedPlayingStates: [Bool] = []
    let viewModel = PlaybackViewModel(
        player: player,
        onPresentationCommitted: { playing in
            committedPlayingStates.append(playing)
        }
    )
    viewModel.setSubtitleCues(
        [presentationCue(text: "old", startMilliseconds: 1_000)],
        currentTimeMilliseconds: 1_000
    )
    viewModel.isPlaying = true

    viewModel.preparePresentationTransition(
        to: 6,
        subtitleCues: [presentationCue(text: "target", startMilliseconds: 6_000)]
    )
    viewModel.bindPendingPresentation(to: 41)

    viewModel.player(player, didChangeProperty: "time-pos", value: .double(6.1))
    viewModel.player(player, didChangeProperty: "duration", value: .double(120))
    viewModel.player(player, didChangeProperty: "pause", value: .bool(true))
    await Task.yield()

    #expect(viewModel.currentTime == 1)
    #expect(viewModel.displayedCurrentTime == 1)
    #expect(viewModel.activeSubtitleText == "old")
    #expect(viewModel.isPlaying)
    #expect(viewModel.duration == 0)
    #expect(committedPlayingStates.isEmpty)

    viewModel.player(
        player,
        didCommitPresentationAtMilliseconds: 6_100,
        generation: 41,
        playing: true
    )
    await Task.yield()

    #expect(viewModel.currentTime == 6.1)
    #expect(viewModel.displayedCurrentTime == 6.1)
    #expect(viewModel.activeSubtitleText == "target")
    #expect(viewModel.isPlaying)
    #expect(committedPlayingStates == [true])
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
    viewModel.setSubtitleCues(
        [presentationCue(text: "old", startMilliseconds: 1_000)],
        currentTimeMilliseconds: 1_000
    )
    viewModel.isPlaying = true

    viewModel.preparePresentationTransition(
        to: 6,
        subtitleCues: [presentationCue(text: "superseded", startMilliseconds: 6_000)]
    )
    viewModel.bindPendingPresentation(to: 50)
    viewModel.preparePresentationTransition(
        to: 11,
        subtitleCues: [presentationCue(text: "latest", startMilliseconds: 11_000)]
    )
    viewModel.bindPendingPresentation(to: 51)

    viewModel.player(
        player,
        didCommitPresentationAtMilliseconds: 6_000,
        generation: 50,
        playing: true
    )
    await Task.yield()

    #expect(viewModel.currentTime == 1)
    #expect(viewModel.displayedCurrentTime == 1)
    #expect(viewModel.activeSubtitleText == "old")
    #expect(viewModel.isPlaying)
    #expect(committedPlayingStates.isEmpty)

    viewModel.player(player, didChangeProperty: "time-pos", value: .double(11.2))
    await Task.yield()
    #expect(viewModel.currentTime == 1)
    #expect(viewModel.activeSubtitleText == "old")

    viewModel.player(
        player,
        didCommitPresentationAtMilliseconds: 11_000,
        generation: 51,
        playing: false
    )
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
