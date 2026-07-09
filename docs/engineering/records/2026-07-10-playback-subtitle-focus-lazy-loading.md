# Playback Subtitle Focus Lazy Loading

## Human-Owned Source

- `docs/human/requirements/20260710-Feature-Playback Subtitle Focus Overlay.md`
- `docs/human/design/UI.md`

## Scope

Add the persistent complete-document scrollbar, ten-cue lazy window loading,
bounded cue-text cache, sequential prefetch, and latest-target fast dragging to
Playback Subtitle Focus. The action menu and removal of the previous Quick
Search UI remain separate implementation steps.

## Classification

- Product semantics: reuses Core cue ordinals, the documented 6 + 1 + 3 window,
  ten-cue batches, two-cue prefetch threshold, thirty-cue cache limit, and
  source/session/request generations.
- Platform UI/UX: adds the fixed-dark persistent scrollbar, drag preview,
  100-millisecond stable-target delay, rollback, and one-slot final target
  alignment.
- Platform integration: serializes Subtitle Focus database reads away from the
  main actor and coordinates task cancellation with playback source lifetime.
- Playback execution: unchanged; scrollbar and lazy-loading interaction do not
  seek, resume, or write playback time.

## Changes

- Extracted the Table Scrollbar geometry, drawing, hit testing, cursor, and drag
  event sequence into one shared AppKit primitive. Search retains its existing
  scroll-view adapter and inherited appearance; Subtitle Focus uses a separate
  ordinal adapter with fixed-dark appearance and pointer cursor.
- Kept the Subtitle Focus scrollbar present whenever cue groups exist and based
  thumb length and position on complete-document metadata rather than the
  currently cached window. A full-length short-document thumb remains visible
  but cannot start a zero-travel drag.
- Added a Session-scoped scheduler with one logical active request and one
  latest pending request. New targets immediately supersede prior tokens while
  physical reads remain serialized through one actor-isolated database reader.
- Routed initial and subsequent Subtitle Focus reads through the same lazy
  database actor. The reader opens no database connection before Enter and
  checks cancellation around each synchronous database operation.
- Added user-navigation-only sequential prefetch at the two-cue boundary,
  adjacent ten-cue batch validation, equivalent-request deduplication, atomic
  cache merge, and opposite-direction ten-cue eviction capped at thirty cues.
- Added an overlay-reported actual visible ordinal range derived from viewport,
  Focus Anchor, and wheel presentation offset. Sequential commits also protect
  two adjacent animation slots and are rejected if eviction would remove any
  currently visible or required cue.
- Added fast scrollbar dragging with local continuous ordinal preview, immediate
  cached commits, a deterministic 100-millisecond delay for stable uncached
  targets, immediate mouse-up requests, and rollback to the committed ordinal
  after cancellation or failure.
- Entered Target Window Loading at the first uncached preview so the later
  action menu can remain suppressed throughout debounce and database loading.
  Keyboard and pointer navigation synchronously supersede target reads, and a
  Session-side pending-preview guard prevents delayed View callbacks from
  reviving cancelled targets.
- Kept the previous valid cue window visible until the latest target batch
  passes exact total-count and ordinal-range validation. Successful distant
  targets atomically replace the cache and trigger one 136-point reel
  transition; failure leaves the snapshot unchanged.
- Removed broad implicit reel-offset animation so prefetch, cache eviction,
  cached drag commits, and failure rollback cannot animate large cache-offset
  changes.
- Released scheduler, target, protected-range, cache, and task state on overlay
  dismissal or playback source replacement; late source/session/target results
  cannot publish.

## Verification

- `swift test --filter SubtitleFocus`
  - Passed 61 Swift Testing tests covering initial 6 + 1 + 3 policy, prefetch
    threshold and direction, one-active/latest-pending scheduling, stale target
    rejection, exact batch validation, thirty-cue eviction, actual visible-range
    protection, fast-drag state transitions, target-loading suppression,
    failure rollback, source/session cleanup, and one-slot far-target motion.
- `swift test --filter TableScrollbar`
  - Passed 13 Swift Testing tests covering shared single/dual-axis geometry,
    minimum and full-length thumbs, hit slop, drag fractions and event sequence,
    Search vertical and horizontal live dragging, wheel forwarding, and
    superview-coordinate hit testing.
- `swift build`
  - Passed.
- `swift test`
  - Passed 7 XCTest tests and 496 Swift Testing tests.
- Three focused read-only reviews
  - Found no remaining P0 or P1 issue after fixes for debounce loading state,
    keyboard/target races, stale callback revival, short-document dragging,
    Search adapter behavior, and visible-cue eviction safety.
- `git diff --check`
  - Passed.

## Outcome

Subtitle Focus now loads cue text only after Enter, keeps at most thirty cached
cues, serializes reads, and publishes only the latest valid source/session/target
result. Ordinary navigation prefetches without moving the Focus Anchor, while
fast scrollbar dragging remains responsive without issuing a query for every
crossed cue. Search preserves its established Table Scrollbar behavior through
the shared primitive.
