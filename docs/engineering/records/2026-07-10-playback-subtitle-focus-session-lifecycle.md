# Playback Subtitle Focus Session Lifecycle

## Human-Owned Source

- `docs/human/requirements/20260710-Feature-Playback Subtitle Focus Overlay.md`
- `docs/human/design/UI.md`

## Scope

Prepare the Subtitle Focus data model for playback with an on-demand Session,
off-main-thread initial loading, exact playback-state capture, and deterministic
cleanup. The visible overlay and Enter activation remain the next step so no
intermediate commit exposes a pause-without-feedback regression.

## Classification

- Product semantics: reuses the committed Core cue-window and source-identity
  model without duplicating it in the App target.
- Platform UI/UX: adds a dedicated optional Session Store but no visual surface
  in this step.
- Platform integration: prepares the existing playback key monitor for active
  Session dismissal and reads the initial window off the main thread. Enter is
  switched only when the visible overlay lands in the next step.
- Playback execution: captures playback time and playing state before pausing,
  then restores only the captured playing state on user dismissal.

## Changes

- Added an optional `PlaybackSubtitleFocusSessionStore` that does not exist
  before Enter and owns the active Session token, initial cue snapshot, and
  bounded cue cache after Enter.
- Added AppCoordinator orchestration to capture normalized video/subtitle
  identity, exact playback time, and playing state before pausing.
- Loaded the initial cue window through a separate SQLite connection on a
  detached task and published only when the Session identity and generation
  still match.
- Added Escape cancellation/dismissal handling for an active Session while
  preserving editable-text-input priority in the global key handler.
- Invalidated pending work and released all retained cues before Search,
  Library, or Shiori selection changes and before playback stops, without
  resuming a source that is being replaced.
- Marked Search, Library, and Shiori replacements as opening before their
  deferred play command so an old playback frame cannot start a new Session
  during the source handoff.
- Changed the shared pause command to report success so a failed native pause
  cannot leave a live Subtitle Focus Session.
- Added tests for lazy Session creation, child-store refresh isolation, initial
  publication, stale generation/source rejection, playing/paused restore
  decisions, and source-replacement cache release.

## Verification

- `swift test --filter PlaybackSubtitleFocus`
  - Passed 6 Swift Testing tests.
- `swift test --filter PlaybackSegmentCompletion`
  - Passed 9 Swift Testing tests.
- `swift test --filter PlaybackStoreTests`
  - Passed 16 Swift Testing tests.
- `swift build`
  - Passed.
- `swift test`
  - Passed 7 XCTest tests and 443 Swift Testing tests.
- `git diff --check`
  - Passed.

## Outcome

Subtitle Focus now has a source-scoped lifecycle that can capture and pause the
current playback, rejects late initial-load results, and returns retained cue
count to zero on dismissal or source change. The next step can render the
documented fixed-height dark overlay and switch Enter to this open command in
the same usable commit, without subscribing normal playback to cue interaction
state.
