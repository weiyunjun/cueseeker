# Implementation Record: Playback Cue Reel Timeline Removal And Styling Refinement

- **Requirement**: `docs/human/requirements/20261016-UI-Playback Cue Reel Timeline Removal And Styling Refinement.md`
- **Date**: 2026-10-16

## Summary of Changes

1. **Remove Non-Collage Left Dot-Line Timeline (`PlaybackSubtitleFocusReel.swift`, `PlaybackTheme.swift`)**:
   - Updated `PlaybackCueTimelineLayout` so that when `usesCheckbox == false` (`Current`, `Subtitle Playlist`, and `Command Panel Search Results`), `leadingAccessoryWidth(usesCheckbox: false)` returns `0`, `rowLayout(in:usesCheckbox:markerCenterY:)` returns `markerRect: .zero` and `cueRect: rowRect`, and `connectorRect(from:to:)` returns `nil` whenever a row has an empty marker rect.
   - Updated `PlaybackSubtitleFocusReelDocumentView.draw(_:)` and `cueTimelineConnectorRects` to draw leading markers (`PlaybackCollageCheckboxDrawing`) and vertical timeline connectors exclusively when `isEditingCollage == true`.
   - Removed the obsolete `PlaybackCueTimelineMetrics.dotSize`, `PlaybackCueTimelineLayout.drawDot`, and `PlaybackTheme.cueTimelineFocusedNative`.

2. **Metadata Font Size Token (`PlaybackTheme.swift`)**:
   - Updated `PlaybackSubtitleFocusMetrics.metadataFontSize` (`--font-size-playback-cue-metadata`) to `14` while keeping metadata line-height (`16px`), row height (`24px`), font weight (`400 regular`), and vertical/horizontal gaps unchanged.

3. **Subtitle Focus & Metadata Light/Dark Color Tokens (`PlaybackTheme.swift`, `PlaybackCueResult.swift`, `PlaybackSubtitleFocusReel.swift`)**:
   - Updated `PlaybackTheme.subtitleFocusOverlayBackgroundNative` (`--color-subtitle-focus-overlay-bg`) to Light `#FAFBFD` (`250, 251, 253`) and Dark `#18181B` (`24, 24, 27`).
   - Updated `PlaybackTheme.subtitleFocusCueSelectedNative` (`--color-subtitle-focus-cue-selected`) to Light `#0F172A` (`15, 23, 42`, `alpha 1.0`) and Dark `#FFFFFF` (`alpha 1.0`).
   - Updated `PlaybackTheme.subtitleFocusCueGroupSelectedNative` (`--color-subtitle-focus-cue-group-selected`) to Light `#334155` (`51, 65, 85`) and Dark `rgba(255, 255, 255, 0.68)`.
   - Updated `PlaybackTheme.subtitleFocusCueUnselectedNative` (`--color-subtitle-focus-cue-unselected`) to Light `rgba(15, 23, 42, 0.26)` and Dark `rgba(255, 255, 255, 0.26)`, while keeping `playbackModuleSidebarUnselectedNative` at `0.34`.
   - Added `PlaybackTheme.cueMetadataSelectedNative` (`--color-playback-cue-metadata-selected`, Light `rgba(15, 23, 42, 0.56)` / Dark `rgba(255, 255, 255, 0.56)`), `PlaybackTheme.cueMetadataUnselectedNative` (`--color-playback-cue-metadata-unselected`, Light `rgba(15, 23, 42, 0.22)` / Dark `rgba(255, 255, 255, 0.20)`), and `PlaybackTheme.cueMetadataNative(isSelected:)` wired through `PlaybackCueMetadataLayout.draw(_:in:isSelected:isEnabled:)` in both `PlaybackCueResultLayout` and `PlaybackSubtitleFocusCueReelAdapter`.

## Verification

- Automated unit & integration tests (`swift test --package-path apps/macos-native --filter "PlaybackCueResultLayoutTests|PlaybackSubtitleFocusLayoutTests|PlaybackPlaylistReelAdapterTests|PlaybackMultiModuleOverlayIntegrationTests"`):
  - Verified `PlaybackCueTimelineLayout` omits leading markers and connectors when `usesCheckbox == false` and preserves `31px` checkbox markers, `24px` marker gap, and `1px` vertical connectors when `usesCheckbox == true` (`Editing Collage`).
  - Verified `PlaybackSubtitleFocusMetrics.metadataFontSize == 14` and metadata layout truncation behavior.
  - Verified Light and Dark resolved hex and alpha values for `subtitleFocusOverlayBackgroundNative`, `subtitleFocusCueSelectedNative`, `subtitleFocusCueGroupSelectedNative`, `subtitleFocusCueUnselectedNative`, and `cueMetadataNative(isSelected:)`.
