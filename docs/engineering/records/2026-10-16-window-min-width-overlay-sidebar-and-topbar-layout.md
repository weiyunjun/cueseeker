# Implementation Record: Window Min Width Overlay Sidebar And Topbar Layout

- **Requirement**: `docs/human/requirements/20261016-UI-Window Min Width Overlay Sidebar And Topbar Layout.md`
- **Date**: 2026-10-16

## Summary of Changes

1. **Window & Page Content Minimum Width & Design Token Unification (`WorkbenchControls.swift`, `WorkbenchRedesignTokens.swift`, `ContentView.swift`, `WorkbenchLayoutState.swift`)**:
   - Added `WorkbenchControlMetrics.redesignWindowDefaultWidth` (`1000`), `redesignWindowMinimumWidth` (`600`), `redesignWindowMinimumHeight` (`560`), `redesignSidebarMotionDuration` (`0.18`), and `redesignBorderHairlineWidth` (`1`), plus `WorkbenchRedesignColors.bgCanvas`.
   - Updated `AppShellLayout` to reference these semantic tokens (`minimumWindowWidth = 600`, `pageContentMinimumWidth = 600`, `sidebarAutoCollapseWindowWidth = 840`, `modeControlsOuterPadding = redesignSpacing3`, `sidebarBorderWidth = redesignBorderHairlineWidth`) and defined named z-index constants (`topBarZIndex`, `dialogLayerZIndex`, `toastLayerZIndex`, `tooltipLayerZIndex`).
   - Updated `ContentRootView` to use `WorkbenchRedesignColors.bgCanvas` and named z-index constants, removing hardcoded RGB and magic z-index literals.
   - Updated `WorkbenchLayoutState.collapseSidebarForCompactWindowIfNeeded(width:threshold:)` to auto-collapse on `< 840px` (`width < threshold`).

2. **Full-Height Overlay Sidebar with Pure Opacity Fade & Removal of Page Horizontal Scrollbars (`AppTopbarLayout.swift`, `ContentView.swift`, `WorkbenchScrollView.swift`, `WorkbenchPageScrollbar.swift`, `SchemaWorkbenchSearchShell.swift`, `WorkbenchFileView.swift`, `WorkbenchTestLibraryView.swift`, `LibraryOverviewComponents.swift`)**:
   - Separated Docked Sidebar (`width >= 840px`, side-by-side `240px` sidebar + `>= 600px` page content) and Overlay Sidebar (`width < 840px` and manually expanded via the top-left toggle).
   - Rendered Overlay Sidebar in `AppTopbarLayout` as a full-height (`y = 0` to bottom, `width = 240px`) surface layered above the right page content and topbar using **pure opacity fade (`.transition(.opacity)`)** and `.allowsHitTesting(isOverlaySidebarVisible)` so its geometric bounds remain fixed at `0 <= x <= 240` from frame 0 and hit-testing is disabled immediately on fade-out.
   - Styled Overlay Sidebar with a `54px` top `TitlebarBackgroundView` region, a `1px` (`AppShellLayout.sidebarBorderWidth`) `--color-border-muted` (`WorkbenchRedesignColors.borderMuted`) trailing border, and `--shadow-popover` (`WorkbenchRedesignColors.shadowPopover`).
   - Updated `OverlaySidebarPointerMonitorNSView` with an entrance animation cooldown guard (`entranceCooldownDuration = AppShellLayout.sidePanelAnimationDuration`) and horizontal-only exit check (`pointInSidebar.x > sidebarBounds.maxX`) so upward mouse nudges near the top-left toggle button never falsely collapse the sidebar, while moving right past `x > 240` immediately collapses it.
   - Removed Workbench page-level bottom horizontal scrollbars (`WorkbenchPageHorizontalScrollbar`, `WorkbenchPageScrollOffset`, `tableScrollbarBottomReserve`) while preserving `SubtitleTableView`'s internal horizontal scrollbar.

3. **Topbar & Dialog Header Segmented Control Anti-Overlap Layout (`AppTopbarLayout.swift`, `WorkbenchControls.swift`, `TaskPanel.swift`, `PlaybackSubtitleFocusOverlay.swift`)**:
   - Implemented `WorkbenchAdaptiveHeaderGeometry`, `WorkbenchAdaptiveHeaderBarLayout`, and `WorkbenchAdaptiveHeaderBar` with a `12px` (`--spacing-3`) minimum horizontal gap on both sides of the centered segmented control / title.
   - Applied `WorkbenchAdaptiveHeaderBar` across the Workbench `Recent` topbar (`AppTopbarLayout`), `TaskPanel.headerRow`, and `PlaybackOverlayTopBar` so the center view stays horizontally centered when both sides have `>= 12px` clearance, shifts smoothly toward the side with remaining space when one side reaches `12px`, and locks at `trailingMinX - 12 - centerWidth` when both sides reach `12px` while compressing the leading title with tail ellipsis (`...`) and `.workbenchTruncatedTextTooltip`.

4. **Playback Overlay & Collage Topbar Double-Click Zoom and Window Drag (`PlaybackSubtitleFocusOverlay.swift`)**:
   - Mounted `TitlebarBackgroundView` (posting `.topbarTitlebarZoomRequested` on double-click zoom) at the base of `PlaybackOverlayTopBar` so all non-interactive regions across both Module mode (`Current / Subtitle Playlist / Command Panel Search Results`) and Collage mode (`Editing Collage…`) support double-click window zoom and left-drag window move.

## Verification

- Automated unit & component tests (`swift test --package-path apps/macos-native --filter "WorkbenchLayoutStateTests|WorkbenchControlMetricsTests|CoverSummaryCardTests|WorkbenchPageScrollbarTests|playbackSubtitleFocus|WorkbenchEmptyHintTests"`):
  - Verified tokenized `WorkbenchControlMetrics` and `AppShellLayout` values (`minimumWindowWidth == 600`, `pageContentMinimumWidth == 600`, `sidebarAutoCollapseWindowWidth == 840`, `sidePanelAnimationDuration == 0.18`, `sidebarBorderWidth == 1`).
  - Verified compact-window auto-collapse (`< 840px`), entrance cooldown guard, vertical-nudge immunity (`x <= 240`), and horizontal exit collapse (`x > 240`).
  - Verified `WorkbenchAdaptiveHeaderGeometry` centering, single-side shifting without truncation, and dual-side locking at `12px` minimum gap with leading title compression.
  - Verified `PlaybackOverlayTopBar` mounts `TitlebarBackgroundView` in both module and collage modes.
  - Verified Workbench pages own only a vertical scrollbar while `SubtitleTableView` owns its horizontal scrollbar at the bottom without an outer page horizontal scrollbar.
