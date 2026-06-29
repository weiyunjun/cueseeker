# Player Topbar Tokenization

## Human-Owned Source

- `docs/human/requirements/20260630-Feature-Player Chrome Tokens.md`

## Scope

Tokenize the player topbar title and custom window-control buttons against the
player chrome design tokens and layout definitions.

## Classification

- Product semantics: unchanged; close, minimize, zoom/fullscreen, and playback
  title meaning are unchanged.
- Platform UI/UX: the player topbar gradient, title, traffic-light colors,
  control border, glyph, cluster spacing, topbar padding, title typography, and
  title shadow now read from player chrome theme/metric constants.
- Platform integration: unchanged; native titlebar drag and double-click
  behavior remain owned by the existing titlebar background bridge.
- Playback execution: unchanged.

## Changes

- Added player topbar gradient, window-control, and title-shadow colors to
  `PlaybackTheme`.
- Added player topbar title, window-control, padding, and spacing metrics to
  `PlaybackChromeMetrics`.
- Replaced hard-coded player topbar gradient, title color, title size, title
  shadow, max title width, horizontal padding, and window-control cluster gap.
- Replaced hard-coded custom close/minimize/zoom button colors, size, border,
  and glyph styling.
- Removed the player title's extra tracking because the player chrome title
  component does not define a letter-spacing token.

## Verification

- `git diff --check` passed.
- `swift build` passed in `apps/macos-native`.
- `swift test` passed in `apps/macos-native`: XCTest reported 7 passing CASS
  rendering tests, and Swift Testing reported 357 passing tests.

## Outcome

The player topbar title and custom window-control buttons now share the
player-chrome token/metric source. Player bottom chrome remains tokenized, and
Quick Search remains outside this implementation scope.
