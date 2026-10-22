# 2026-10-22 Subtitle Reel Focus Fade And Navigation Debounce

## Requirement Reference
- `docs/human/requirements/20261022-UI-Subtitle Reel Focus Fade And Navigation Debounce.md`

## Summary of Changes
1. **Subtitle Focus Motion Tokens & Three-Tier Color Interpolation (`PlaybackTheme.swift`)**:
   - Updated `PlaybackSubtitleFocusMetrics.reelTransitionDuration` from `0.22` to `0.40` (`--duration-subtitle-focus-scroll`).
   - Added `focusFadeOutDuration = 0.26` (`--duration-subtitle-focus-fade-out`), `focusFadeInDelay = 0.18` (`--delay-subtitle-focus-fade-in`), and `focusFadeInDuration = 0.22` (`--duration-subtitle-focus-fade-in`) along with their `reducesMotion`-aware resolvers.
   - Added appearance-aware sRGB color interpolation helpers `subtitleFocusCuePrimaryNative(selectionProgress:)`, `subtitleFocusCueGroupNative(selectionProgress:)`, and `cueMetadataNative(selectionProgress:)` to interpolate primary cue text, secondary cue group text, and cue metadata in lockstep between `Unselected` and `Selected` colors.
2. **Adapter & Layout Selection Progress Plumbing (`PlaybackVirtualReelContracts.swift`, `PlaybackCueResult.swift`, `PlaybackPlaylistReelAdapter.swift`)**:
   - Extended `PlaybackVirtualReelContentAdapter.drawItem`, `PlaybackSubtitleFocusCueReelAdapter`, `PlaybackCueResultReelAdapter`, `PlaybackCueResultLayout`, and `PlaybackCueMetadataLayout` to accept and render continuous `selectionProgress` in `[0, 1]`.
3. **Focus Fade-Out, Navigation Debounce & Fade-In Engine (`PlaybackSubtitleFocusReelDocumentView.swift`, `PlaybackSubtitleFocusReel.swift`, `PlaybackStore.swift`, `PlaybackCommandPanel.swift`)**:
   - Implemented per-ordinal focus animation and debounce tracking in `PlaybackSubtitleFocusReelDocumentView` driven by `PlaybackSubtitleFocusReelPositionAnimator.easedProgress` (`cubic-bezier(0.22, 1, 0.36, 1)`).
   - Initial presentation, tab switches, and dataset replacements call `setImmediateSelection` to render the initial focused cue at `100%` `Selected` color without fade-in.
   - Keyboard/controller navigation, Collage preview strip jumps, discrete wheel steps, trackpad scrolling (`didMove`), and scrollbar dragging (`didMove`) invoke `beginNavigationSelection`, which immediately fades out any lit or partially-lit cue over `0.26s` (supporting smooth mid-flight reversal without jumps), holds all cues at `Unselected` while resetting the `0.18s` debounce deadline on each movement, and fades in the settled target cue over `0.22s` once stationary for `0.18s`.
   - Wired `commandPanelSearchKeyboardNavigationRequest` in `PlaybackStore` and `PlaybackCommandPanel` so keyboard navigation in Command Panel Search Results shares the same `0.40s` scroll and `0.26s / 0.18s / 0.22s` focus transition.

## Verification
- Updated metric assertions and added `subtitleFocusThemeInterpolatesThreeTierTextColorsAcrossLightAndDarkAppearances`, `subtitleFocusSingleStepNavigationFadesOutImmediatelyAndDebouncesFadeIn`, `subtitleFocusContinuousNavigationDebouncesTransitRowsAndReversesMidFadeIn`, and `subtitleFocusScrollbarDragSettlesInPlaceAndBoundaryWheelKeepsSelectionLit` in `PlaybackSubtitleFocusLayoutTests.swift`, plus Command Panel search navigation assertions in `PlaybackSearchOverlayTests.swift`.
- Ran `swift test --package-path apps/macos-native --filter "PlaybackSubtitleFocusLayoutTests|PlaybackPlaylistReelAdapterTests|PlaybackSearchOverlayTests|PlaybackSubtitleFocusKeyboardActionTests"` (all 106 tests passed).
