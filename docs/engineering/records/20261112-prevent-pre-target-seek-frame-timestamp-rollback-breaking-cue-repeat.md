# 2026-11-12: Prevent Pre-Target Seek Frame Timestamp Rollback Breaking Cue Repeat

## Requirement Source
- `docs/human/requirements/20261112-Bug-Prevent Pre-Target Seek Frame Timestamp Rollback Breaking Cue Repeat.md`
- `docs/human/design/playback/Playback Core.md`

## Summary of Changes
1. **Native Seek Frame Progress Alignment Within 2ms Tolerance (`CNativePlayback`)**:
   - Defined `SFXSeekFrameAlignmentToleranceSeconds = 0.002` and `SFXResolvedPlaybackSecondsForSeekTarget(mediaSeconds, seekSeconds)` in `SFXVideoToolboxSupport.m`, shared with `SFXFrameBeforeSeekTarget`.
   - Added `_alignPreTargetSeekFrames` on `SFXNativePlaybackSession` (`SFXNativePlaybackSession.m`, `SFXNativePlaybackSession+AudioAndDecode.m`): when opening at a start timestamp or seeking in-session, if a presented video frame falls within the `2ms` frame-alignment tolerance before `_seekSeconds` (`_seekSeconds - 2ms <= mediaSeconds < _seekSeconds`), video presentation timing (`CMSampleBuffer` / frame pacing) and audio sync remain untouched while `_currentTime`, `_lastSubmittedVideoFrameMilliseconds`, `didPresentVideoFrameAtMilliseconds:`, and `notifyTimeIfNeeded:` align to `_seekSeconds` instead of rolling back `1–2ms` before the target and freezing there across the `250ms` delegate throttle window.
   - Automatically clears `_alignPreTargetSeekFrames` as soon as a frame at or after `_seekSeconds` (or earlier by more than `2ms`) is decoded.
2. **Playback Presentation, Subtitle Lookup, and IEEE-754 Millisecond Conversion Alignment (`CueSeekerPlayback`, `CueSeekerApp`)**:
   - Added `PlaybackSeekTimestampAlignment` in `PlaybackTypes.swift`:
     - `alignedPlaybackMilliseconds(presentedMilliseconds:targetMilliseconds:)` aligns committed first-frame timestamps within `2ms` before `targetMilliseconds` to `targetMilliseconds` while preserving frames `>= targetMilliseconds` or earlier by `> 2ms` (such as post-EOF seeks).
     - `playbackMilliseconds(atSeconds:)` (`Int((seconds * 1_000 + 1e-6).rounded(.down))`) prevents IEEE-754 decimal roundtrip representations (e.g., `Double(2_010) / 1_000`, `Double(16_080) / 1_000`, `Double(1_099_350) / 1_000`) from truncating `1ms` below exact millisecond boundaries.
   - Applied `PlaybackSeekTimestampAlignment` across `PlaybackPlayer.commitPendingPresentation`, `PlaybackSubtitleTrack.activeText(at:)`, `PlaybackViewModel` (`playFromCue`, `endTimelineScrubbing`, `performSeek`, and `didCommitPresentationAtMilliseconds`), `AppCoordinator.cueRepeatStartMilliseconds(at:)`, and `AppCoordinator.openPlaybackSubtitleFocusFromUser()`, ensuring `Repeat`, on-screen SRT/ASS subtitles, and `Playback Overlay (Current)` default selection never roll back across a preceding silent gap to an earlier cue.
3. **Unit & Integration Tests (`CueSeekerPlaybackTests`, `CueSeekerAppTests`)**:
   - Added `playbackSeekTimestampAlignmentAlignsPreTargetFramesWithin2msAndPreservesIEEE754Roundtrips` and `nativeOpenAndSeekAlignPreTarget2msFrameProgressWhilePreservingPostTargetFrameTimestamp` (23.976fps `24000/1001` media fixture) in `NativePlaybackPresentationTransitionTests.swift`.
   - Added `playbackPresentationAlignsPreTarget2msFrameCommitWithoutBlankingCueSubtitleWhilePreservingFarEarlierOrPostTargetFrames` in `PlaybackPresentationTransitionTests.swift`.
   - Added `preTarget2msFrameCommitAndIEEE754RoundtripNeverRollbackRepeatOrOverlaySelectionToPreviousCue` in `PlaybackSegmentCompletionTests.swift`.

## Verification
- Ran `swift test --package-path apps/macos-native --no-parallel --filter "playbackSeekTimestampAlignment|nativeOpenAndSeekAlignPreTarget2msFrameProgress|nativeSeekAndOpenRetainPresentedImage|nativeRapidSeeksCommitOnlyLatestPresentationGeneration|PlaybackPresentationTransitionTests|preTarget2msFrameCommitAndIEEE754Roundtrip|cueRepeatEligibilityUsesOverlayDefaultCueSelection|PlaybackNormalShortcutTests"` (`27` tests passed).
- Ran `swift test --package-path apps/macos-native --no-parallel --filter "PlaybackSegmentCompletionTests|PlaybackRequestTests"` (`72` tests passed).
- Result matched all requirement and acceptance criteria; end-to-end playback verification is ready for user acceptance.
