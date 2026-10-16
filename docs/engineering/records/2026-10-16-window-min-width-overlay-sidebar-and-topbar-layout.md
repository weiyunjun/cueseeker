# Implementation Record: Window Min Width Overlay Sidebar And Topbar Layout

- **Requirement**: `docs/human/requirements/20261016-UI-Window Min Width Overlay Sidebar And Topbar Layout.md`
- **Date**: 2026-10-16

## Summary of Changes

1. **Window & Page Content Minimum Width (`ContentView.swift`, `WorkbenchLayoutState.swift`)**:
   - Updated `AppShellLayout.minimumWindowWidth` (`--size-window-min-width`) and `AppShellLayout.pageContentMinimumWidth` (`--size-page-content-min-width`) to `600` (`560px` minimum window height unchanged).
   - Updated `AppShellLayout.sidebarAutoCollapseWindowWidth` (`--size-window-sidebar-collapse-width`) to `840` (`600 + 240`) and added `AppShellLayout.isCompactWindow(width:)` (`width > 0 && width < 840`).
   - Updated `WorkbenchLayoutState.collapseSidebarForCompactWindowIfNeeded(width:threshold:)` to auto-collapse on `< 840px` (`width < threshold`).

2. **Full-Height Overlay Sidebar in Compact Window & Removal of Page Horizontal Scrollbars (`AppTopbarLayout.swift`, `ContentView.swift`, `WorkbenchScrollView.swift`, `WorkbenchPageScrollbar.swift`, `SchemaWorkbenchSearchShell.swift`, `WorkbenchFileView.swift`, `WorkbenchTestLibraryView.swift`, `LibraryOverviewComponents.swift`)**:
   - Separated Docked Sidebar (`width >= 840px`, side-by-side `240px` sidebar + `>= 600px` page content) and Overlay Sidebar (`width < 840px` and manually expanded via the top-left toggle).
   - Rendered Overlay Sidebar in `AppTopbarLayout` as a full-height (`y = 0` to bottom, `width = 240px`) surface layered above the right page content and topbar while keeping `leadingControls` (top-left Sidebar toggle button) and native window traffic lights at their original coordinates and interactive.
   - Styled Overlay Sidebar with a `54px` top `TitlebarBackgroundView` region, a `1px` `--color-border-muted` (`WorkbenchRedesignColors.borderMuted`) trailing border, and `--shadow-popover` (`WorkbenchRedesignColors.shadowPopover`).
   - Added `OverlaySidebarPointerMonitorView` (`OverlaySidebarPointerMonitorNSView`) and `WorkbenchLayoutState.collapseOverlaySidebarOnMouseLeaveIfNeeded` so the Overlay Sidebar collapses immediately when the pointer exits the `240px` sidebar region or leaves the window.
   - Removed Workbench page-level bottom horizontal scrollbars (`WorkbenchPageHorizontalScrollbar`, `WorkbenchPageScrollOffset`, `tableScrollbarBottomReserve`) while preserving `SubtitleTableView`'s internal horizontal scrollbar.

3. **Topbar & Dialog Header Segmented Control Anti-Overlap Layout (`AppTopbarLayout.swift`, `WorkbenchControls.swift`, `TaskPanel.swift`, `PlaybackSubtitleFocusOverlay.swift`)**:
   - Implemented `WorkbenchAdaptiveHeaderGeometry`, `WorkbenchAdaptiveHeaderBarLayout`, and `WorkbenchAdaptiveHeaderBar` with a `12px` (`--spacing-3`) minimum horizontal gap on both sides of the centered segmented control / title.
   - Applied `WorkbenchAdaptiveHeaderBar` across the Workbench `Recent` topbar (`AppTopbarLayout`), `TaskPanel.headerRow`, and `PlaybackOverlayTopBar` so the center view stays horizontally centered when both sides have `>= 12px` clearance, shifts smoothly toward the side with remaining space when one side reaches `12px`, and locks at `trailingMinX - 12 - centerWidth` when both sides reach `12px` while compressing the leading title with tail ellipsis (`...`) and `.workbenchTruncatedTextTooltip`.

4. **Playback Overlay & Collage Topbar Double-Click Zoom and Window Drag (`PlaybackSubtitleFocusOverlay.swift`)**:
   - Mounted `TitlebarBackgroundView` (posting `.topbarTitlebarZoomRequested` on double-click zoom) at the base of `PlaybackOverlayTopBar` so all non-interactive regions across both Module mode (`Current / Subtitle Playlist / Command Panel Search Results`) and Collage mode (`Editing Collage…`) support double-click window zoom and left-drag window move.

## Verification

- Automated unit & component tests (`swift test --package-path apps/macos-native --filter "WorkbenchLayoutStateTests|WorkbenchControlMetricsTests|CoverSummaryCardTests|WorkbenchPageScrollbarTests|playbackSubtitleFocus|WorkbenchEmptyHintTests"`):
  - Verified `AppShellLayout.minimumWindowWidth == 600`, `pageContentMinimumWidth == 600`, and `sidebarAutoCollapseWindowWidth == 840`.
  - Verified compact-window auto-collapse (`< 840px`) and overlay sidebar mouse-leave auto-collapse (`x > 240` or leaving window only when `< 840px`).
  - Verified `WorkbenchAdaptiveHeaderGeometry` centering, single-side shifting without truncation, and dual-side locking at `12px` minimum gap with leading title compression.
  - Verified `PlaybackOverlayTopBar` mounts `TitlebarBackgroundView` in both module and collage modes.
  - Verified Workbench pages own only a vertical scrollbar while `SubtitleTableView` owns its horizontal scrollbar at the bottom without an outer page horizontal scrollbar.
