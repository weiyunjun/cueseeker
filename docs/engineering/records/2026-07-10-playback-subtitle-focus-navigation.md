# Playback Subtitle Focus Navigation

## Human-Owned Source

- `docs/human/requirements/20260710-Feature-Playback Subtitle Focus Overlay.md`
- `docs/human/design/UI.md`

## Scope

Add fixed-anchor cue navigation to the visible Subtitle Focus overlay through
keyboard, wheel, trackpad, hover, and cue-text pointer input. Lazy loading, the
virtual scrollbar, and the action menu remain separate implementation steps.

## Classification

- Product semantics: cue selection continues to use stable Core ordinals and
  complete cached cue groups.
- Platform UI/UX: adds the fixed Focus Anchor, continuous reel motion, pointer
  hit behavior, documented transition, and Reduce Motion handling.
- Platform integration: routes Up and Down through the existing playback key
  monitor and captures scroll events only inside the active overlay window.
- Playback execution: unchanged; cue navigation does not seek, resume, or write
  playback time.

## Changes

- Separated the initial boundary-aware anchor calculation from subsequent reel
  positioning so the anchor does not drift near the first or last cue.
- Added cached previous/next navigation and pointer-selected anchor state to the
  child Subtitle Focus Session Store.
- Routed Up and Down to the active Session while continuing to consume
  unmodified overlay keyboard input at document and cache boundaries. The
  Session queues requests until the overlay drains them, including requests
  received immediately before the cue-selection view mounts.
- Limited the app key monitor to the primary playback window so an open Session
  cannot intercept input in Settings or another native window.
- Added overlay-local wheel and trackpad displacement that rebases selection at
  fixed 136-point slot crossings and settles the nearest slot onto the anchor.
- Preserved visual continuity when selection changes during scrolling by
  compensating each selected-ordinal change with the opposite residual offset.
- Scoped scroll capture to a transparent, non-hit-testing AppKit bridge with
  window and overlay bounds checks, gesture ownership, momentum handling, and
  symmetric monitor teardown.
- Added cue-local pointer hover, cursor feedback, and click selection. Clicking
  an unselected cue moves the logical anchor to that cue's current first-line
  position while leaving the reel in the same visible position.
- Limited cue pointer hit regions to the two visible TextKit line-fragment
  bounds, so clipped third and later lines cannot intercept the gap or another
  cue.
- Recorded the reel's animated presentation transform so clicks during a
  transition use the currently visible first-line position rather than the
  animation target.
- Coordinated queued keyboard navigation with wheel residual state inside the
  overlay, preventing a wheel-to-arrow handoff from jumping or rebounding.
- Applied the documented timing curve to keyboard and final settle motion, and
  aligned immediately when Reduce Motion is enabled.

## Verification

- `swift test --filter PlaybackSubtitleFocus`
  - Passed 29 Swift Testing tests covering fixed anchor geometry, exact
    136-point steps, pointer transfer with zero reel displacement, cache-window
    stability, visible-fragment pointer hit regions, animated presentation
    anchors, continuous wheel rebasing, nearest-cue settle, keyboard/wheel
    handoff, pre-mount key queuing, document/cache boundaries,
    gesture/momentum ownership, and Session cleanup.
- `swift build`
  - Passed.
- `swift test`
  - Passed 7 XCTest tests and 466 Swift Testing tests.
- `git diff --check`
  - Passed.

## Outcome

Subtitle Focus cue selection can now move independently of playback through
keyboard and pointer navigation while the logical Focus Anchor remains stable.
Wheel and trackpad deltas stay local to the reel, and only fixed-slot crossings
publish selected-cue changes through the child Session Store.
