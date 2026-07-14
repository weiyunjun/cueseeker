# Playback Seek and Result Switch Black Screen

Date: 2026-07-14

## Requirement

- `docs/human/requirements/20260714-Bug-Playback Seek And Result Switch Black Screen.md`

## Scope

Remove the forced black interval from five-second seeks and previous/next
playback transitions. Keep the previously presented video frame, subtitle, and
time state until the replacement frame is ready, then commit the replacement
presentation as one generation-aware transition. Explicit stop and close must
continue to remove the displayed image immediately.

## Steps

- Removed the in-session seek's early `flushAndRemoveImage`. Open and seek now
  retain the displayed image until the replacement sample buffer is ready, then
  use `flush` and an immediate enqueue without exposing the layer background.
- Added a player-lifetime presentation generation to native open, seek, state
  callbacks, and pending pixel submissions. The display drain validates both
  the current session and generation, while failed active-session seeks restore
  the previous logical generation without reusing the monotonic generation ID.
- Kept automatic software-decoder recycling inside the same logical
  presentation generation and made its stale-drain fallback request recycling
  without allowing the old frame to commit.
- Added a first-frame commit callback and a player-lifetime display-image
  removal counter. Public stop remains the single native path that calls
  `flushAndRemoveImage`.
- Added pending presentation state to the playback wrapper and view model. ASS
  and SRT sources, subtitle time, playback time, duration, and playing state
  remain on the previous presentation until the matching first frame commits.
  Superseded generations are ignored, and repeated relative seeks accumulate
  from the latest pending target.
- Routed Search, Shiori, Library, ordinary seeks, bounded seeks, and timeline
  completion through the same prepare, bind, and commit boundary. Result status
  changes to playing or paused only after the matching frame commits.
- Removed the SRT overlay's 120 ms opacity transition so the committed target
  subtitle does not visually lag the target video frame.
- Added deterministic view-model coverage and generated-media native coverage
  for same-session seek, cross-file open, rapid supersession, retained display,
  and explicit stop.

## Verification

- After an accidental reset, replayed the recorded patch sequence through the
  original `637/637` checkpoint. The restored worktree matched that checkpoint's
  exact changed-file list and per-file insertion/deletion counts.
- Confirmed that the later ASS prepare/commit staging, native first-frame gate,
  no-video-frame completion, and presentation-failure rollback additions are
  absent from this restored version.
- `git diff --check`: passed.
- `swift build --package-path apps/macos-native`: passed.
- `swift test --package-path apps/macos-native --filter PlaybackPresentationTransition`:
  passed all 4 focused tests.
- `swift test --package-path apps/macos-native`: passed all 637 tests.
- The focused native tests confirmed that same-session seek and cross-file open
  add zero display-image removals, explicit stop adds exactly one removal, and a
  superseded seek generation cannot publish a first-frame commit.
- The focused Swift tests confirmed that old subtitle, time, duration, and
  playing state remain visible while a transition is pending and that only the
  matching generation atomically commits the staged target.
- The first test iteration used a one-frame-per-second MPEG-4 fixture that did
  not produce a native frame and was not accepted as evidence. The final tests
  use the repository-established 24 fps H.264/AAC generation path and also
  cover the automatic software-recycle stale-drain path found during diagnosis.

## Outcome

Automated verification matches the measurable acceptance criteria: seek and
media replacement no longer actively remove the displayed image, presentation
state commits only with the matching target frame, rapid supersession rejects
stale work, and stop still clears immediately. This is the exact implementation
snapshot that previously received human end-to-end acceptance, restored without
the later unaccepted presentation extensions.

## Follow-ups

- Re-run human end-to-end verification on the restored commit before merging it
  into `main`.
