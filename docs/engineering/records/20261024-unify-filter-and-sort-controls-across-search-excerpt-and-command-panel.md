# 2026-10-24 Unify Filter and Sort Controls Across Search, Excerpt, and Command Panel

## Covering Human Documentation

- Requirement: `docs/human/requirements/20261024-UI-Unify Filter And Sort Controls Across Search Excerpt And Command Panel.md`
- Design authorities:
  - `docs/human/design/ui/UI Components - Domain.md` (`C-15.6 Sort Menu Popover`)
  - `docs/human/design/ui/UI Layouts - Workbench.md` (`L-05.4 Search / Excerpt Toolbar Layout`)
  - `docs/human/design/ui/UI Layouts - Playback.md` (`L-09.2 Command Panel Secondary Layout`)
  - `docs/human/design/ui/UI Interaction Rules.md` (`I-06.6 Overlay Keyboard Ownership`)

## Implementation Steps

1. Extracted `SchemaWorkbenchFilterAndSortControls` in `apps/macos-native/Sources/CueSeekerApp/Shared/WorkbenchSchemaSearch/SchemaWorkbenchSearchShell.swift` so Search, Excerpt Detail, and Command Panel Search Results share a single Filter Trigger + Sort Trigger `WorkbenchButton` group (`16px` spacing, `MenuAnchorProbe` binding, and `.layoutPriority(1)`).
2. Extracted `SchemaWorkbenchSortMenuHost` and `SchemaWorkbenchSortMenuTriggerContext` in `SchemaWorkbenchSearchShell.swift` to centralize Sort Menu anchor probing, natural popover size measurement, `MenuPlacement.openingFrame` placement, `MenuGateClientView` keyboard routing (`Esc`, `↑/↓`, `←/→` consume, `Enter` activate), `SchemaWorkbenchSortMenuSurfaceHost` hosting, and automatic dismissal when `isSelectionMode`, `isFilterDialogOpen`, `layerContext.isCovered` / `isWorkbenchPageCovered`, or `onDisappear` fires.
3. Updated `SchemaWorkbenchSearchShell`, `SchemaWorkbenchSearchToolbar`, and `PlaybackCommandPanelSearchResults` (in `apps/macos-native/Sources/CueSeekerApp/Playback/SubtitleFocus/PlaybackCommandPanel.swift`) to use `SchemaWorkbenchSortMenuHost` and `SchemaWorkbenchFilterAndSortControls`, removing the duplicated Sort Menu state, placement, keyboard routing, and `PlaybackCommandPanelSortMenuSurfaceHost` from `PlaybackCommandPanel.swift`.
4. Added unit test coverage in `apps/macos-native/Tests/CueSeekerAppTests/PlaybackSearchOverlayTests.swift` verifying sort option lists and `resolvedSortTitle(for:)` across Search, Command Panel, and Excerpt Detail.

## Verification

- Ran `swift test --package-path apps/macos-native --filter PlaybackSearchOverlayTests`.
- Ran `swift test --package-path apps/macos-native --filter WorkbenchPageScrollbarTests`.

## Outcome

- Result matched expectations: Search, Excerpt Detail, and Command Panel Search Results now share a single unified Filter + Sort trigger control group and Sort Menu host without private duplicate implementations, while preserving their respective sort option lists (`SearchSortOrder.workbenchSortOptions` vs. `ExcerptSortOrder.workbenchSortOptions`) and state scopes.
