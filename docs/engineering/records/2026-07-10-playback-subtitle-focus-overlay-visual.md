# Playback Subtitle Focus Overlay Visual

## Human-Owned Source

- `docs/human/requirements/20260710-Feature-Playback Subtitle Focus Overlay.md`
- `docs/human/design/UI.md`

## Scope

Add the first visible Subtitle Focus surface and activate it from Enter only
after the complete initial cue window is available. Navigation, the virtual
scrollbar, and the action menu remain separate later steps.

## Classification

- Product semantics: unchanged; the overlay renders the committed Core
  snapshot without deriving new cue identity or loading data.
- Platform UI/UX: adds the fixed dark overlay, cue reel, fixed cue slots, and
  documented color, size, typography, and motion tokens.
- Platform integration: mounts the overlay above the existing playback stage
  and routes the existing global Enter shortcut to the Session open command.
- Playback execution: unchanged; the render host remains attached with the
  same geometry behind the overlay.

## Changes

- Added fixed Subtitle Focus colors for `#242426` background and 94%, 62%, and
  34% white cue states.
- Added the documented 104-point cue slot, 32-point gap, 136-point pitch,
  960-point maximum content width, 40-point cue type, 52-point line height, and
  0.22-second motion metrics.
- Added a full-stage overlay that renders only after the initial snapshot is
  committed and publishes all ten loaded cues in one pass.
- Kept every cue in identical fixed geometry, clipped overflowing multiline
  text without changing slot height, and aligned the selected cue's first-line
  origin to the viewport center whenever document boundaries allow.
- Positioned the loaded window inside the complete document's virtual reel, so
  prefetch and cache-window boundaries do not move the selected cue.
- Clamped the reel at the complete document's first and last cue boundaries,
  enforced a truly clipped four-sided 32-point viewport, and handled subtitles
  with fewer than ten cues without changing slot geometry.
- Added cue-local hover state for the documented 62% white token without
  publishing hover through the Session Store.
- Mounted the visible layer through the optional child Session Store so cue
  state does not republish through `PlaybackStore`.
- Disabled playback-stage hit testing and accessibility while a Session is
  opening or visible, consumed unmodified overlay keyboard input, and kept the
  native render surface attached.
- Switched Enter from the old Quick Search opener to Subtitle Focus only in the
  same commit that adds the visible overlay.

## Verification

- `swift test --filter PlaybackSubtitleFocus`
  - Passed 13 Swift Testing tests, including a real SwiftUI render and measured
    52-point cue line pitch.
- `swift build`
  - Passed.
- `swift test`
  - Passed 7 XCTest tests and 450 Swift Testing tests.
- `git diff --check`
  - Passed.

## Outcome

Enter can now pause and open a visible, fixed-geometry Subtitle Focus reel after
the complete initial window loads. Opening shows no spinner, ordinary playback
still creates no Subtitle Focus view or subscription, and Escape continues to
restore the captured playback state through the Session lifecycle.
