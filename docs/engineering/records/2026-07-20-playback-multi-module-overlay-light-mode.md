# Playback Multi-Module Overlay Light Mode

## Requirement

- `docs/human/requirements/20260720-Feature-Playback Multi-Module Overlay Light Mode.md`
- `docs/human/design/UI.md`

## Scope

Make the Playback Multi-Module Overlay follow CueSeeker's effective Light,
Dark, and Auto appearance while preserving its layout, session state,
selection, scrolling, and playback behavior.

## Classification

- Platform UI/UX: add appearance-aware Overlay colors and rendering.
- Platform integration: reuse the existing application appearance setting and
  AppKit effective appearance propagation.
- Product semantics: unchanged.
- Playback execution: unchanged.

## Steps

1. Added dynamic Light and Dark subtitle-focus, module-sidebar, and playlist
   sequence colors while preserving the existing Dark values.
2. Removed the fixed Dark SwiftUI environments from the Overlay shell, Current,
   Search, Recent, and Library surfaces so they inherit CueSeeker's effective
   appearance. Connected the module Sidebar to its dedicated appearance-aware
   colors without changing layout or interaction.

## Verification

- `swift test --filter playbackSubtitleFocusColorsResolveDocumentedLightAndDarkTokens`
  passed with 1 test.
- `swift test --filter playbackCueResult` passed with 12 tests.
- `swift test --filter playbackMultiModule` passed with 2 tests.
- `swift test --filter 'playbackRecent|playbackLibrary'` passed with 9 tests.
- Static inspection confirmed that the only remaining fixed Dark appearance in
  the Overlay source is the Native Reel scrollbar scheduled for the next step.

## Outcome

The dynamic Overlay color foundation matches the documented Light and Dark
tokens. SwiftUI Overlay surfaces now inherit CueSeeker's effective appearance;
Native Reel and scrollbar refresh behavior remains for the following step.

## Follow-ups

- Refresh Native Reel colors and scrollbar drawing when appearance changes.
