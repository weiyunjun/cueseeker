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
- Added a native first-frame presentation gate and two-phase ASS preparation.
  The target ASS source is loaded and rendered by an isolated worker while the
  old subtitle remains visible; the exact gated video frame and prepared ASS
  frame then commit in the same main-thread presentation turn.
- Added an explicit no-video-frame completion path and a finished-session seek
  reopen fallback. A target beyond the video track can no longer leave the UI
  pending indefinitely, and a seek racing natural session completion retries
  without clearing the retained image.
- Routed Search, Shiori, Library, ordinary seeks, bounded seeks, and timeline
  completion through the same prepare, bind, and commit boundary. Result status
  changes to playing or paused only after the matching frame commits.
- Removed the SRT overlay's 120 ms opacity transition so the committed target
  subtitle does not visually lag the target video frame.
- Added deterministic view-model, ASS staging, and generated-media native
  coverage for same-session seek, cross-file open, rapid supersession, retained
  display, gated first-frame resume, no-frame completion, and explicit stop.

## Verification

- `git diff --check`: passed.
- `swift build --package-path apps/macos-native`: passed.
- Focused presentation-transition regression tests: passed all 9 tests.
- `swift test --package-path apps/macos-native`: passed all 642 tests.
- The focused native tests confirmed that same-session seek and cross-file open
  add zero display-image removals, explicit stop adds exactly one removal, and a
  superseded seek generation cannot publish a first-frame commit.
- The focused Swift tests confirmed that old subtitle, time, duration, and
  playing state remain visible while a transition is pending and that only the
  matching generation atomically commits the staged target.
- The ASS tests confirmed that preparation keeps the old source, worker, and
  visible surface intact; commit switches the prepared source synchronously;
  stale tokens are rejected; and a prepared clear removes subtitles atomically.
- The gate and EOF tests confirmed that a gated first pixel is retained without
  removing the displayed image, resumes with the same timestamp, and reports a
  target with no video frame instead of waiting forever.
- The first test iteration used a one-frame-per-second MPEG-4 fixture that did
  not produce a native frame and was not accepted as evidence. The final tests
  use the repository-established 24 fps H.264/AAC generation path and also
  cover the automatic software-recycle stale-drain path found during diagnosis.
- The first full-suite run exposed a race where a session could finish between
  the player's finished check and its in-session seek. The seek path now reopens
  the same media with the same presentation generation in that case; the final
  full-suite run passed.

## Outcome

Automated verification matches the measurable acceptance criteria: seek and
media replacement no longer actively remove the displayed image, presentation
state commits only with the matching target frame, rapid supersession rejects
stale work, and stop still clears immediately. The owner completed end-to-end
visual verification and accepted the result on 2026-07-14.
