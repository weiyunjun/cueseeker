# Implementation Record: Button Pressed Feedback And Hover State Completion

- Date: 2026-10-21
- Requirement: `docs/human/requirements/20261021-UI-Button Pressed Feedback And Hover State Completion.md`
- Branch: `main`

## Scope Delivered

1. **Button Pressed & Hover Color Tokens (`WorkbenchRedesignTokens.swift`, `PlaybackTheme.swift`, `WorkbenchControls.swift`)**
   - Removed legacy `settingsGroupBg` (`--color-settings-group-bg`).
   - Updated `primaryButtonBgHover` (`--color-primary-button-bg-hover`) to blend `NSColor.controlAccentColor` with `12%` `#000000` in Light and `12%` `#FFFFFF` in Dark, and added `primaryButtonBgPressed` (`--color-primary-button-bg-pressed`) blending `22%` `#000000` in Light and `22%` `#FFFFFF` in Dark.
   - Added `bgPressed`, `dangerBgPressed`, `filterChipSelectedBgHover`, `filterChipSelectedBgPressed`, `overlaySurfaceShortcutButtonPressedBg`, `overlaySurfaceKeycapPressedBg`, `popoverSurfaceShortcutButtonPressedBg`, `popoverSurfaceKeycapPressedBg`, `rowActionBgPressed`, `fileFolderCardBgPressed`, `PlaybackTheme.controlPressedBackground`, and `WorkbenchControlMetrics.redesignCoverSummaryButtonPressedBackgroundOpacity` (`0.34`).

2. **Pressed State & Drag-Out Regret Behavior for Whitelisted Buttons & Clickable File Folder Cards (`HoverEffectModifier.swift`, `WorkbenchControls.swift`, `CoverSummaryCard.swift`, `SettingsSubtitleCategory.swift`, `ContentView.swift`, `AnkiExportDialog.swift`, `PlaybackCommandPanel.swift`, `PlaybackCueFooter.swift`, `SchemaWorkbenchSelectionActionOverlay.swift`, `CueFacetFilterPanel.swift`, `PlaybackChromeIconButton.swift`, `PlaybackChromeView.swift`, `PlaybackVolumeControl.swift`, `TopbarAppEntries.swift`, `TaskEntryButton.swift`, `PlaybackReturnButton.swift`, `LiquidGlassVideoTopBar.swift`, `PlaybackSubtitleFocusOverlay.swift`, `TaskPanel.swift`, `WorkbenchFileView.swift`)**
   - Introduced `PressableButtonStyle` to track `configuration.isPressed` without label dimming or geometric scaling, reverting hover state when the pointer is dragged outside while the primary mouse button remains held down and restoring pressed state when dragged back inside.
   - Wired pressed and hover states across `C-03.1 Button` (`Neutral`, `Cover Summary`, `Primary`, `Destructive`, and Settings Subtitle `Font` dropdown trigger), `C-03.2 Icon Button` (`Default`, `Inline Clear`, `Row Action`, `Dialog Close`, `Sidebar Toggle`, Settings Shortcuts restore default button, Anki export `+` and item remove `✕` buttons, Command Panel back button, and topbar icon buttons across Workbench, Playback Overlay, and Player), `C-03.3 Shortcut Action Button` (with synchronous `C-08.9 Keycap` pressed state), `C-02.5 Filter Chip` (unselected and selected), clickable Level 1 & Level 2 folder cards in `WorkbenchFileView`, and Player speed / icon / volume mute speaker buttons.
   - Updated `CoverSummaryActionButton` in `CoverSummaryCard.swift` to use `WorkbenchRedesignColors.coverSummaryText` (`#FFFFFF`) with `14%` (Default) -> `24%` (Hover/Open) -> `34%` (Pressed) opacity steps.

3. **Settings & File Info Group Card Background Unification (`SettingsLayout.swift`)**
   - Updated `SettingsGroup` to fill with `WorkbenchRedesignColors.tableBg` (`--color-table-bg`) and stroke its outer border with `WorkbenchRedesignColors.borderControl` (`--color-border-control`), while keeping internal row dividers on `WorkbenchRedesignColors.borderDivider`.

## Verification

- Updated and added unit tests in `WorkbenchControlMetricsTests`, `FileCardMenuTests`, `TaskCardMenuTests`, and `CoverSummaryCardTests` and verified all tests pass via `swift test`.
