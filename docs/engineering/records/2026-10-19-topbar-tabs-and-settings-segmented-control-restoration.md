# Implementation Record: Topbar Tabs And Settings Segmented Control Restoration

- **Date**: 2026-10-19
- **Requirement**: `docs/human/requirements/20261019-UI-Topbar Tabs And Settings Segmented Control Restoration.md`
- **Design References**:
  - `docs/human/design/ui/UI Tokens.md`
  - `docs/human/design/ui/UI Components - Controls.md`
  - `docs/human/design/ui/UI Layouts - Workbench.md`
  - `docs/human/design/ui/UI Layouts - Playback.md`

## Summary of Changes

1. **Topbar View Switcher Restoration to Plain Text + Sliding Bottom Capsule (`WorkbenchTabs.swift`, `PlaybackTheme.swift`, `ContentView.swift`, `PlaybackSubtitleFocusOverlay.swift`, `TaskPanel.swift`)**:
   - Restored the topbar/header view switchers in **Recent** (`Videos` / `Excerpt Lists`), **Playback Overlay** (`Current` / `Playlist`), and the **Task** dialog (`Current` / `Completed` / `Incomplete`) from `WorkbenchSegmentedControl` back to `WorkbenchTabs`, keeping their existing `WorkbenchAdaptiveHeaderBar` centered layout and collision-avoidance truncation rules.
   - Locked `WorkbenchTabs` typography at `14px` (`--font-size-body`) and `600` (`.semibold`) for **both selected and unselected options** so switching never alters glyph metrics or causes layout jitter.
   - Aligned `WorkbenchTabs` colors (and Playback Overlay's `Editing Collage` centered title) to standard text tokens (`WorkbenchRedesignColors.textPrimary`: Light `#1F1F1F`, Dark `#E4E4E4` for selected text and bottom indicator; `WorkbenchRedesignColors.textMuted`: Light `#717171`, Dark `#979797` for unselected text) and removed legacy `playbackModuleSidebarSelected` / `playbackModuleSidebarUnselected` colors.
   - Replaced per-tab static indicators with a single shared `24 × 2px` `Capsule()` indicator positioned via `Anchor<CGRect>` bounds preferences (`PlaybackOverlayMetrics.tabIndicatorFrame(for:)`) and animated alongside `WorkbenchTabLabel` text color interpolation (`PlaybackOverlayMetrics.interpolatedTabTextColor(progress:)`) using a `0.18s` fast-out curve (`cubic-bezier(0.22, 1, 0.36, 1)`) strictly when `selection` changes (without animating on initial mount or window resize).

2. **Settings Segmented Control Restoration to Accent Color Style & Compact Metrics (`WorkbenchRedesignTokens.swift`, `WorkbenchControls.swift`, `WorkbenchSegmentedControl.swift`)**:
   - Restored `WorkbenchRedesignColors.segmentedControlSelectedBg` to `NSColor.controlAccentColor` and `segmentedControlSelectedContent` to `#FFFFFF` (Light & Dark), removing the neutral-gray segmented control tokens.
   - Restored `WorkbenchSegmentedControl` container background to `WorkbenchRedesignColors.bgControl`, outer border to `WorkbenchRedesignColors.borderControl`, unselected segment text to `WorkbenchRedesignColors.textPrimary`, and removed the selected segment inner border.
   - Restored `redesignSegmentedControlHeight` from `36px` back to `32px` (`26px` segment height, `3px` padding, `8px` outer radius, `5px` inner radius) and `redesignFontSizeSegmentedControl` from `14px` back to `12px` (`500` weight).

## Verification

- Updated and verified `WorkbenchControlMetricsTests` (`segmentedControlAccentStylingAndGeometryTokensMatchSpecification`, `topbarTabsStylingGeometryAndSlidingMotionMatchSpecification`) and `PlaybackCueResultLayoutTests`, along with `PlaybackSubtitleFocusLayoutTests`, `WorkbenchLayoutStateTests`, `TaskQueueStoreTests`, and `TaskCardMenuTests`.
