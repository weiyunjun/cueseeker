# 20261024 Player Chrome Normalization and Scrubbing Interaction Cleanup

## 1. Requirement Reference

- Requirement: `docs/human/requirements/20261024-UI-Player Chrome Normalization And Scrubbing Interaction Cleanup.md`
- Stabilized Design References:
  - `docs/human/design/ui/UI Design Rules.md`
  - `docs/human/design/ui/UI Interaction Rules.md`
  - `docs/human/design/ui/UI Tokens.md`
  - `docs/human/design/ui/UI Components - Controls.md`
  - `docs/human/design/ui/UI Components - Domain.md`
  - `docs/human/design/ui/UI Layouts - Playback.md`
  - `docs/human/design/ui/UI Layouts - Workbench.md`
  - `docs/human/design/ui/Icon Registry.md`

## 2. Implementation Summary

1. **Topbar Centered Element Width & `--spacing-3` (`12px`) Safety Gap (`AppTopbarLayout.swift`, `LiquidGlassVideoTopBar.swift`, `PlaybackSubtitleFocusOverlay.swift`, `PlaybackTheme.swift`)**:
   - Normalized `PlaybackChromeMetrics.topbarCenterMaxWidth` to compute available width from the actual measured leading and trailing control widths (`barWidth - 2 * (max(leadingOccupiedWidth, trailingOccupiedWidth) + safetyGap)`) with `safetyGap = WorkbenchControlMetrics.redesignSpacing3` (`12px`), removing the hardcoded `trailingButtonCount: 2` helper.
   - Extended `WorkbenchAdaptiveHeaderGeometry.resolve` / `WorkbenchAdaptiveHeaderBar` with `keepsCenterOnMidline` and `centerMaxWidthCap` so both `LiquidGlassVideoTopBar` (`L-07.1`) and `PlaybackOverlayTopBar` in `Editing Collage` state (`L-08.2`) dynamically constrain centered titles against live leading/trailing widths (including dynamic `TaskCountBadge` expansion) while keeping the title centered on the topbar midline.
2. **Player Topbar Task Count Badge Mode-Invariant Dark Colors (`LiquidGlassVideoTopBar.swift`)**:
   - Passed `countBackground: PlaybackTheme.controlHoverBackground` (`--color-player-control-bg-hover`) and `countTextColor: PlaybackTheme.textSecondary` (`--color-player-text-secondary`) to `TopbarAppEntries` on the video topbar so `TaskCountBadge` matches `Tag / Player Chrome` across both Light and Dark system appearances.
3. **Remove Scrubbing Interaction Suppression & Normalize Button States (`PlaybackChromeIconButton.swift`, `PlaybackChromeView.swift`, `PlaybackVolumeControl.swift`, `PlaybackVideoStage.swift`)**:
   - Removed `suppressesInteraction` during progress scrubbing from `PlaybackChromeIconButton`, `PlaybackSpeedChromeButton`, `PlaybackVolumeControl`, tooltips, and player menus (retaining menu interaction suppression only when covered by Command Panel).
   - Replaced the non-whitelisted `isSelected` property on `PlaybackChromeIconButton` with the canonical `isOpen` (`Open` state) on `PlaybackSubtitleChromeButton`, ensuring the active subtitle button keeps its translucent white background (`--color-player-control-bg-hover`) while dragging the progress scrubber.
4. **Bottom Control Bar `90px` Height & Stage-Hosted Player Speed Menu (`PlaybackTheme.swift`, `PlaybackChromeView.swift`, `PlaybackChromeSpeedMenu.swift`, `PlaybackChromeMoreMenu.swift`, `PlaybackVideoStage.swift`)**:
   - Removed the hardcoded `interactiveHeight` (`358px`) from `PlaybackChromeMetrics` and framed `PlaybackChromeView` strictly to `PlaybackChromeMetrics.height` (`90px`, `--height-player-bottom-control-bar`).
   - Hosted `PlaybackChromeSpeedMenuOverlay` on `PlaybackVideoStage` within `PlaybackChromeMoreMenuOverlay.bounds` and unified `PlaybackChromeSpeedMenu` on `WorkbenchPopoverPanel(surface: .playerChrome)` (`1px` border).
   - Unified `.check` and `.caretRight` icon sizes in `PlaybackChromeSpeedMenu` and `PlaybackChromeMoreMenu` to `WorkbenchControlMetrics.redesignMenuItemSymbolFontSizeMacOS` (`18px`).
5. **Progress Scrubber `No Duration` State & Time Capsule Width (`PlaybackProgressScrubber.swift`, `PlaybackTheme.swift`)**:
   - Guarded hover track thickening, preview track, thumb visibility, time capsule display, and drag scrubbing on `duration > 0` (`No Duration` state).
   - Removed `progressTimeCapsuleMinWidth` (`44px`) and added `PlaybackProgressTimeCapsulePlacementLayout` to measure and clamp the floating time capsule (`C-12.4`) synchronously within the scrubber bounds.

## 3. Verification

- Executed `swift test --package-path apps/macos-native --filter "PlaybackMoreMenuTests|WorkbenchLayoutStateTests|PlaybackNormalShortcutTests"`.
- All unit tests compiled cleanly and passed.
