# 2026-11-16 Global Color Audit, Grayscale Playback Overlay, and Translucent Scrollbar

- **Covering Requirement**: `docs/human/requirements/20261116-UI-Global Color Audit Grayscale Playback Overlay And Translucent Scrollbar.md`
- **Referenced Design Documents**:
  - `docs/human/design/ui/UI Design Rules.md`
  - `docs/human/design/ui/UI Tokens.md`
  - `docs/human/design/ui/UI Components - Controls.md`
  - `docs/human/design/ui/UI Components - Domain.md`
  - `docs/human/design/ui/UI Layouts - Playback.md`
- **Branch / Baseline**: `main` (pre-requirement baseline `267b766`, requirement commit `6040869`)

## Scope

1. Update 23 existing color tokens in place (0 new tokens) across `WorkbenchRedesignTokens.swift` and `PlaybackTheme.swift` to remove cold-blue color cast, establish a pure neutral grayscale hierarchy for `Playback Overlay`, and switch global non-player scrollbars to translucent black/white foreground overlays while preserving fixed dark `Player Chrome` tokens.
2. Align 3 existing component/container surface references:
   - `L-09.1` `PlaybackCommandPanel` container surface (`bgDialog`, `--radius-dialog`, `.interfaceLayer(.commandPanel)`, `commandPanelScrim`, `.circular` clip/stroke/exterior outline via `dialogEdgeHighlight` and `dialogOutline`, and `shadowDialog`).
   - `L-09.2` `PlaybackCommandPanelSecondaryHeader` back button hover/pressed backgrounds (`bgHover` and `bgPressed`).
   - `C-08.5` `drawCueStateIndicator` hover fill (`rowSelected`).
3. Sync hardcoded color/alpha assertions in existing headless unit tests without adding any simulated UI tests, fake windows, or test-only production hooks.

## Summary of Changes

1. **Updated Workbench, Command Panel, Keycap, and Scrollbar Tokens**:
   - Modified `apps/macos-native/Sources/CueSeekerApp/Shared/WorkbenchRedesignTokens.swift` in place (`16` tokens):
     - `--color-table-row-selected`: Light `#F3F4F6`, Dark `#2B2B31`.
     - `--color-row-selected`: Light `#E5E7EB`, Dark `rgba(255,255,255,0.08)`.
     - `--color-row-action-bg-pressed`: Light `#D1D5DB`, Dark `rgba(255,255,255,0.14)`.
     - `--color-menu-item-selected-bg`: Light `#E5E7EB`, Dark `rgba(255,255,255,0.16)`.
     - `--color-overlay-surface-shortcut-button-bg-hover` / `-pressed`: Light `rgba(0,0,0,0.06)` / `rgba(0,0,0,0.12)`, Dark `rgba(255,255,255,0.10)` / `rgba(255,255,255,0.16)`.
     - `--color-overlay-surface-keycap-bg` / `-hover` / `-pressed`: Light `rgba(0,0,0,0.08)` / `0.14` / `0.20`, Dark `rgba(255,255,255,0.10)` / `0.16` / `0.22`.
     - `--color-popover-surface-shortcut-button-bg-hover` / `-pressed`: Light `#F3F4F6` / `#E5E7EB`, Dark `rgba(255,255,255,0.12)` / `rgba(255,255,255,0.16)`.
     - `--color-popover-surface-keycap-bg` / `-hover` / `-pressed`: Light `#E6E6E6` / `#D6D6D6` / `#C6C6C6`, Dark `rgba(255,255,255,0.10)` / `0.18` / `0.24`.
     - `--color-scrollbar-thumb-default` / `-interactive`: Light `rgba(0,0,0,0.18)` / `rgba(0,0,0,0.34)`, Dark `rgba(255,255,255,0.22)` / `rgba(255,255,255,0.38)`.

2. **Updated Neutral Grayscale `Playback Overlay` Tokens**:
   - Modified `apps/macos-native/Sources/CueSeekerApp/Playback/PlaybackTheme.swift` in place (`7` tokens):
     - `--color-subtitle-focus-overlay-bg`: Light `#F4F4F4`, Dark `#161616`.
     - `--color-subtitle-focus-cue-selected`: Light `#1A1A1A`, Dark `#EDEDED`.
     - `--color-subtitle-focus-cue-group-selected`: Light `rgba(26,26,26,0.75)`, Dark `rgba(237,237,237,0.75)`.
     - `--color-subtitle-focus-cue-unselected`: Light `rgba(26,26,26,0.30)`, Dark `rgba(237,237,237,0.30)`.
     - `--color-playback-cue-timeline-muted`: Light `#D6D6D6`, Dark `#444444`.
     - `--color-playback-cue-metadata-selected`: Light `rgba(26,26,26,0.54)`, Dark `rgba(237,237,237,0.54)`.
     - `--color-playback-cue-metadata-unselected`: Light `rgba(26,26,26,0.24)`, Dark `rgba(237,237,237,0.24)`.
   - Static and transition-interpolated resolvers (`subtitleFocusCuePrimaryNative`, `subtitleFocusCueGroupNative`, and `cueMetadataNative`) derive directly from these updated dynamic colors while `Player Chrome` tokens remain unchanged.

3. **Aligned `Command Panel` Container, Secondary Header Back Button, and `Cue State Indicator` Hover Fill**:
   - Updated `apps/macos-native/Sources/CueSeekerApp/Playback/SubtitleFocus/PlaybackCommandPanel.swift`:
     - Aligned `PlaybackCommandPanel` container chrome (`L-09.1`) to `WorkbenchDialogChrome` using `RoundedRectangle(cornerRadius: PlaybackCommandPanelMetrics.cornerRadius, style: .circular)` for `.clipShape`, inner `1px` `dialogEdgeHighlight` `strokeBorder`, outer `1 / displayScale` `dialogOutline` clipped with `WorkbenchExteriorClipShape(..., cornerStyle: .circular)`, and `shadowDialog`, keeping `bgDialog`, `.interfaceLayer(.commandPanel)`, and `commandPanelScrim` intact.
     - Updated `PlaybackCommandPanelSecondaryHeader` back button (`L-09.2`) hover/pressed fills to `WorkbenchRedesignColors.bgHover` and `WorkbenchRedesignColors.bgPressed`.
   - Updated `apps/macos-native/Sources/CueSeekerApp/Shared/SubtitleTable/SubtitleTableCoordinator+Drawing.swift`:
     - Updated `drawCueStateIndicator` (`C-08.5`) hover fill from `WorkbenchRedesignColors.NS.tableRowSelected` to `WorkbenchRedesignColors.NS.rowSelected`.

4. **Updated Existing Headless Color Assertions**:
   - Updated hardcoded hex/alpha expectations in:
     - `apps/macos-native/Tests/CueSeekerAppTests/WorkbenchControlMetricsTests.swift`
     - `apps/macos-native/Tests/CueSeekerAppTests/PlaybackCueResultLayoutTests.swift`
     - `apps/macos-native/Tests/CueSeekerAppTests/FileCardMenuTests.swift`
     - `apps/macos-native/Tests/CueSeekerAppTests/TaskCardMenuTests.swift`
     - `apps/macos-native/Tests/CueSeekerAppTests/PlaybackSubtitleFocusLayoutTests.swift` (`subtitleFocusThemeInterpolatesThreeTierTextColorsAcrossLightAndDarkAppearances`, reflecting equal neutral RGB `#1A1A1A` and linear alpha ramp `0.30 -> 0.75` in Light mode).

## Verification

- `swift build --package-path apps/macos-native`: passed (`Build complete! (9.83s)`, `0` errors).
- `swift test --package-path apps/macos-native --filter "WorkbenchControlMetricsTests|PlaybackCueResultLayoutTests|FileCardMenuTests|TaskCardMenuTests|subtitleFocusThemeInterpolatesThreeTierTextColorsAcrossLightAndDarkAppearances"`: `52` tests passed in `0.471` seconds (`0` failures).
- `swift test --package-path apps/macos-native --filter "WorkbenchControlMetricsTests|PlaybackCueResultLayoutTests|FileCardMenuTests|TaskCardMenuTests"`: `51` tests passed in `0.343` seconds (`0` failures).

## Outcome

All 23 color tokens and 3 component/container surface alignments are implemented in place and verified against compilation and headless color/metric test suites. Ready for cross-session Code Review and user end-to-end visual acceptance prior to syncing `docs/human/design/ui/`.
