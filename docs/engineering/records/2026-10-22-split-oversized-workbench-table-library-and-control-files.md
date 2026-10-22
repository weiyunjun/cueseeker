# 2026-10-22 Split Oversized Workbench Table Library And Control Files

## Requirement Reference
- `docs/human/requirements/20261022-Engineering-Split Oversized Workbench Table Library And Control Files.md`

## Summary of Changes
1. **Sub-step 2A — Modularized `SubtitleTableView.swift` (7,818 Lines) into 9 Focused Files**:
   - `SubtitleTableMetricsAndColumns.swift` (350 lines): `SubtitleTableMetrics`, `SubtitleTableTextDragAutoScrollGeometry`, `SubtitleTableColumnLayout`.
   - `SubtitleTableTextLayout.swift` (355 lines): `SubtitleTableTagStyle`, `SubtitleTableTextRole`, `SubtitleTableText`, `SubtitleTextLayout`.
   - `SubtitleTableMenuAndCheckboxViews.swift` (248 lines): `RowActionMenu`, `RowActionDestinationSubmenu`, `CueStateTipGeometry`, `SubtitleTableMenuClipView`, `WorkbenchCheckboxDrawing`, `WorkbenchCheckboxButton`.
   - `SubtitleTableChromeAndHeaderViews.swift` (1,139 lines): `SubtitleTableContainerView`, `SubtitleTablePageChromeViewportView`, `SubtitleTableOutlineOverlayView`, `SubtitleTableScrollbarOverlayView`, `SubtitleVirtualTableHeaderView`, `SubtitleVirtualTableDocumentView`, `SubtitleTablePageChrome`.
   - `SubtitleTableCoordinator+Drawing.swift` (1,181 lines): Row/cell/tag drawing, height measurement, and document invalidation helpers.
   - `SubtitleTableCoordinator+SelectionAndInput.swift` (1,705 lines): Cross-cell/header text selection, drag auto-scroll, clipboard copy, pointer shape, mouse/keyboard/hover/tooltip routing.
   - `SubtitleTableCoordinator+Menus.swift` (771 lines): `MenuGate` and `MenuHostingView` row action menu and destination submenu presentation and action dispatch.
   - `SubtitleTableCoordinator+Testing.swift` (530 lines): Isolated all `*ForTesting` inspection and interaction hooks on `SubtitleTableView.Coordinator`.
   - `SubtitleTableView.swift` (1,570 lines): `SubtitleTableView` (`NSViewRepresentable`) and core `Coordinator` state, lifecycle, diffing, layout, and `DynamicScrollAnchor` preservation.
2. **Sub-step 2B — Split `WorkbenchLibraryView.swift` (2,212 Lines) into 5 Focused Files**:
   - `WorkbenchRecentView.swift` (163 lines): `WorkbenchRecentView`, `RecentTimeSection`, `RecentSectionTitleView`.
   - `WorkbenchLibraryView.swift` (593 lines): `WorkbenchLibraryView`, `WorkbenchLibraryMetrics`, Library overview & folder detail views, `LibrarySortMenuPopover`.
   - `LibraryMediaCards.swift` (485 lines): Shared `RecentWatchingGrid`, `LibraryVideoCardGrid`, `LibraryVideoCard`, `CompleteLibraryFolderGrid`, `LibraryFolderCard`, `CompleteLibraryEpisodeGrid`.
   - `LibraryCardContextMenuHost.swift` (608 lines): `LibraryCardContextMenuHost`, `LibraryCardContextMenu`, `LibraryCardRightClickMonitor`, and viewport/menu geometry helpers.
   - `LibraryCoverViews.swift` (373 lines): `LibraryCoverWithProgress`, `LibraryCoverWithBadge`, `LibraryCachedCoverImage`, `LibraryWatchStatus`, `WatchStatusBadge`.

## Verification
- Verified `swift build --package-path apps/macos-native` and `SubtitleTable` / `SubtitleTextLayout` / `Library` / `RecentWatching` / `CardContextMenu` unit test suites compile cleanly with 0 errors and pass.
