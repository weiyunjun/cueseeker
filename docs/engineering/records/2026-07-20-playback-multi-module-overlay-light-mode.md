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
3. Made the Native Reel redraw its resident content when effective appearance
   changes, changed its scrollbar to inherited appearance, applied the dedicated
   playlist sequence color, and refreshed the AppKit pointer-shield background
   without invalidating Reel measurements or session state.

## Verification

- `swift test --filter playbackSubtitleFocusColorsResolveDocumentedLightAndDarkTokens`
  passed with 1 test.
- `swift test --filter playbackCueResult` passed with 12 tests.
- `swift test --filter playbackMultiModule` passed with 2 tests.
- `swift test --filter 'playbackRecent|playbackLibrary'` passed with 9 tests.
- The focused appearance-rendering, state-preservation, inherited-scrollbar,
  and playlist-sequence test run passed with 3 tests.
- `swift test --filter subtitleFocus` passed with 69 tests.
- `swift test --filter playbackCueResult` passed with 12 tests.
- The first state-preservation test attempted to inspect `NSView.needsDisplay`
  without mounting the view in a window. AppKit immediately cleared that
  internal flag, so the test was corrected to verify rendered Light and Dark
  output separately while the state test verifies selection, fractional
  position, measurement-cache preservation, and inherited scrollbar mode.
- Static inspection confirmed that the Playback Subtitle Focus sources no
  longer force Dark appearance.

## Outcome

The dynamic Overlay color foundation matches the documented Light and Dark
tokens. SwiftUI Overlay surfaces now inherit CueSeeker's effective appearance;
Native Reel and scrollbar appearance behavior passes targeted rendering,
state, layout, virtualization, and interaction verification.

## Follow-ups

- Complete integrated build, test, and appearance verification.
