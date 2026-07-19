# Library Playback Auto Advance And Completed Restart

## Requirement

- `docs/human/requirements/20260719-Feature-Playlist Auto Advance And Completed Video Restart.md`

## Scope

Make Library and Recent full-video playback advance to the next video after
natural media completion. Restart completed videos from the beginning when they
are opened directly or through previous/next Library navigation.

## Architecture

- Product semantics: `CueSeekerCore` resolves completed playback history to a
  zero start position and resolves whether a natural completion has a next-video
  action.
- Playback execution: the native backend reports natural full-media completion
  only after video decode ends and audio output drains.
- App orchestration: `AppCoordinator` persists the completed Library history,
  then opens the next video from the existing Library navigation sequence.

## Steps

1. Added a Core playback-intent resolver for completed-history restart and
   next-video completion actions.
2. Added a generation-checked native natural-completion delegate event after
   audio drain, separate from bounded Cue segment completion and Auto Pause.
3. Forwarded natural completion through `PlaybackPlayer` and
   `PlaybackViewModel` to Library playback orchestration. The wrapper clears the
   finished current-media identity so reopening the same completed video uses a
   new native session instead of seeking a session that has already ended.
4. Persisted natural completion at the resolved media duration before automatic
   navigation. Automatic navigation skips the ordinary source-switch history
   save because completion has already been recorded synchronously.
5. Reused the existing Library and Recent navigation snapshots, so automatic,
   previous, and next navigation share the same order and completed-start rule.
6. Rejected a natural-completion callback when the active Library video no
   longer matches the selected video, preventing a late old-session callback
   from advancing past a newly selected replacement.
7. Added Core, native generated-media, ViewModel, and App regressions.
8. Updated stable playback requirements and the changelog.

## Verification

- The tests-first Core check failed before the playback-intent resolver existed,
  then passed after implementation.
- The first App auto-advance regression found a duplicate source-switch save
  overwriting the completed `100000ms` position with `0ms`. Automatic
  navigation now skips that redundant save, and the regression passes.
- `libraryPlaybackStartPositionRestartsCompletedVideo`: passed.
- `libraryPlaybackCompletionAdvancesOnlyWhenNextVideoExists`: passed.
- `nativePlaybackNotifiesNaturalCompletionAfterAudioDrain`: passed with
  generated audio/video media, including wrapper invalidation of the finished
  current-media identity.
- `playbackViewModelForwardsNaturalPlaybackCompletion`: passed.
- `naturalLibraryPlaybackCompletionOpensNextVideoAndPersistsCompletion`: passed.
- `staleNaturalLibraryCompletionCannotAdvanceReplacementSelection`: passed.
- `nativeAutoStopKeepsSessionAliveAndResumesFromBoundary`: passed and confirmed
  that an Auto Pause boundary does not emit natural full-media completion.
- `swift test --jobs 1 --no-parallel`: all feature-related tests passed; the
  final run completed 792 of 793 tests and exposed the existing shared
  `UserDefaults` isolation failure in
  `sharedPersistenceMigrationCopiesLegacyValuesWithoutOverwritingSharedValues`.
  Its immediate isolated single-worker rerun passed.
- `swift build --jobs 1`: passed.
- `git diff --check`: passed.

## Outcome

The implemented path distinguishes full-media completion from bounded Cue
completion, waits for audio drain before advancing, preserves the completed
history write, and consistently restarts completed Library videos from zero.
