# Implementation Record: Completed Video End Time Alignment And Reopen Restart

- Date: 2026-10-29
- Requirement: `docs/human/requirements/20261029-Bug-Completed Video End Time Alignment And Reopen Restart.md`
- Design Reference: `docs/human/design/product/playback/Playback Controls And Session Behavior.md`

## Summary

Aligned the player's current time and displayed progress to full video duration upon natural playback completion, and ensured that reading playback history flushes pending asynchronous writes so a single-episode folder (or the last episode of a folder) preserves full-duration completion progress and restarts from `00:00` when reopened.

## Implementation Steps

1. Updated `SFXNativePlaybackSession.m` (`notifyPlaybackFinishedIfNeeded`) to advance `_currentTime` to `fmax(_currentTime, _duration)` when `_duration` is positive and finite and emit `[self notifyTimeIfNeeded:YES]` before dispatching `nativePlaybackPlayerDidFinishPlayback:`.
2. Added `PlaybackViewModel.completeNaturalPlaybackAtEnd(fallbackDuration:)` and invoked it in `PlaybackViewModel.playerDidFinishPlayback(_:)` and `AppCoordinator.persistNaturallyCompletedLibraryPlayback(videoPath:)` so `currentTime` and `displayedCurrentTime` reach full duration when natural completion stops at the end of a video.
3. Updated `AppCoordinator.libraryPlaybackHistory(for:)` to flush `libraryPlaybackHistoryWriter` before querying `database.libraryPlaybackHistory(forVideoFile:)`, ensuring asynchronous completion writes are visible immediately on reopen.
4. Added regression coverage in `PlaybackSegmentCompletionTests` and `NativePlaybackMediaTimelineTests`.

## Verification

- `swift test --package-path apps/macos-native --filter "playbackViewModelForwardsNaturalPlaybackCompletion|singleEpisodeNaturalLibraryPlaybackCompletionPreservesFullDurationAndRestartsFromZeroOnReopen|naturalLibraryPlaybackCompletionOpensNextVideoAndPersistsCompletion|nativePlaybackNotifiesNaturalCompletionAfterAudioDrain"`

## Outcome

All targeted unit and integration tests passed and matched the requirement expectations.
