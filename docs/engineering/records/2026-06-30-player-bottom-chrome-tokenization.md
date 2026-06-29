# Player Bottom Chrome Tokenization

## Human-Owned Source

- `docs/human/design/UI.md`

## Scope

Tokenize the player bottom control bar and progress scrubber implementation
against the player chrome design tokens and component/layout definitions.

## Classification

- Product semantics: unchanged; playback commands, speed values, subtitle
  visibility, Shiori, copy, fullscreen, and timeline seek meaning are unchanged.
- Platform UI/UX: player bottom bar buttons, grouped button capsules, speed
  menu, progress scrubber, progress time capsule, and shared bottom-bar metrics
  now read from player chrome theme/metric constants.
- Platform integration: unchanged.
- Playback execution: unchanged.

## Changes

- Added player chrome color, shadow, size, spacing, padding, typography, and
  progress metrics in the playback theme layer, matching
  `docs/human/design/UI.md`.
- Kept existing playback theme names as compatibility aliases for Quick Search
  and other playback overlays outside this implementation scope.
- Replaced hard-coded bottom control bar layout values with
  `PlaybackChromeMetrics`.
- Replaced bottom circular button colors and transport button dimensions with
  player chrome tokens.
- Replaced speed menu dimensions, item metrics, text sizes, background,
  highlight, radius, and shadow with player chrome tokens.
- Replaced progress scrubber track, thumb, hit-area, and progress time capsule
  values with player chrome tokens.
- Let the existing playback volume control reuse shared bottom-bar height,
  icon size, and text color without turning it into a newly standardized
  component.

## Verification

- `git diff --check` passed.
- `swift build` passed in `apps/macos-native`.
- `swift test` passed in `apps/macos-native`: XCTest reported 7 passing CASS
  rendering tests, and Swift Testing reported 357 passing tests.

## Outcome

The player bottom control bar and progress scrubber now share a single
player-chrome token/metric source for the documented bottom-bar and progress
components. Quick Search and the top bar were left outside this change.
