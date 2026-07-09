# Playback Subtitle Focus Data Layer

## Human-Owned Source

- `docs/human/requirements/20260710-Feature-Playback Subtitle Focus Overlay.md`
- `docs/human/design/UI.md`

## Scope

Establish the product-semantic data boundary for Playback Subtitle Focus before
adding playback orchestration or presentation code.

## Classification

- Product semantics: initial cue selection, fixed-size cue windows, sequential
  prefetch ranges, bounded cue-text caching, and latest-request validation.
- Platform UI/UX: unchanged in this step.
- Platform integration: synchronous SQLite window reads exposed for later
  off-main-thread orchestration.
- Playback execution: unchanged in this step.

## Changes

- Added Subtitle Focus cue, snapshot, source identity, loading-policy, bounded
  cache, and request-token value types in `CueSeekerCore`.
- Added a dedicated initial snapshot query that selects the active cue, or the
  nearest cue whose start time is not later than the captured playback time.
- Added ordinal cue-window reads ordered consistently by start time, end time,
  and stable cue-group identity.
- Loaded complete cue-group text from ordered cue-line records so SRT and ASS
  use the same data path and preserve source line order and content.
- Added tests for the 6 + 1 + 3 initial distribution, document boundaries,
  fewer than ten cues, two-cue prefetch threshold, ten-cue batches, thirty-cue
  cache eviction, source/session request validation, gap fallback, stable
  same-start ordering, and ASS cue-line display order.

## Verification

- `swift test --filter SubtitleFocus`
  - Passed 9 Swift Testing tests.
- `swift test --filter CueSeekerCoreTests`
  - Passed 177 Swift Testing tests.
- `git diff --check`
  - Passed.

## Outcome

The feature now has an isolated, testable Core data model. No Subtitle Focus
query or cache is created during ordinary playback; the App layer will invoke
these synchronous window APIs only after Enter and will own off-main-thread
execution and lifecycle cancellation in the next step.
