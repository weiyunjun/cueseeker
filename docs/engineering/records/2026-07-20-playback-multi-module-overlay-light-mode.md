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

## Verification

- `swift test --filter playbackSubtitleFocusColorsResolveDocumentedLightAndDarkTokens`
  passed with 1 test.
- `swift test --filter playbackCueResult` passed with 12 tests.

## Outcome

The dynamic Overlay color foundation matches the documented Light and Dark
tokens. Runtime presentation remains fixed Dark until the following appearance
propagation step, so this step does not introduce a partial Light interface.

## Follow-ups

- Propagate the effective appearance through the SwiftUI Overlay surfaces.
- Refresh Native Reel colors and scrollbar drawing when appearance changes.
