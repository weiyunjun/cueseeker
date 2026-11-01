# Unified Context Menu Submenu And Dropdown Positioning Without Premature Scrollbars

Human-owned documents:

- `docs/human/requirements/20261101-UI-Unified Context Menu Submenu And Dropdown Positioning Without Premature Scrollbars.md`
- `docs/human/design/ui/UI Index.md`
- `docs/human/design/ui/UI Interaction Rules.md`
- `docs/human/design/ui/UI Components - Controls.md`

## Why

1. **Eliminate Premature Height Truncation and Scrollbars on Vertical Mid-Area Triggers (`MenuPlacement.swift`)**:
   - Previously, when `shrinksToFit: true` was passed to `MenuPlacement.openingFrame` and neither `roomBelow` nor `roomAbove` alone could hold the menu's full natural height, `MenuPlacement.openingFrame` immediately truncated `height = max(0, max(roomBelow, roomAbove))` before clamping `y`.
   - When right-clicking or opening a button menu near the vertical middle of a container, cutting the height down to a single half forced an internal scrollbar even when the container's total vertical height was plenty tall enough to hold the entire menu whole.
2. **Release Workbench Table Menu Boundary from the Narrow Table Body (`SubtitleTableCoordinator+Menus.swift`)**:
   - Previously, `menuBodyFrameInContainer()` used `currentTableBodyVisibleRect`, which subtracted the `Table Header` (`44pt`) in `Search` and subtracted the `Cover Summary` (`220pt`) + `Pinned Search Toolbar` (`88pt`) + `Table Header` (`44pt`) (`352pt` total) in `Excerpt` detail pages.
   - Because the whole window scroll is frozen while any menu is open, restricting table row menus and submenus to `currentTableBodyVisibleRect` severely compressed their vertical space in `Excerpt` detail pages and forced premature scrollbars.

## What Changed

1. **Unified `flip -> shift -> size` Menu Placement (`MenuPlacement.swift`)**:
   - Updated `MenuPlacement.openingFrame` so `shrinksToFit` caps `height` against the container's total available vertical space (`availableHeight = max(0, maxY - minY)`) rather than `max(roomBelow, roomAbove)`.
   - When neither `roomBelow` nor `roomAbove` alone fits the menu, `y` slides along the container boundary via `clamp(y, min: minY, max: maxY - height)`, keeping 100% of the menu's natural height with the pointer or trigger positioned alongside the middle of the menu.
   - Updated horizontal trailing-edge handling so zero-width point anchors flip to the left of the pointer (`anchor.minX - menuSize.width`) and compact button anchors whose menu shifted vertically across the button step `gap` (`4pt`) to the left of the button (`anchor.minX - gap - menuSize.width`) instead of sliding over the trigger.
2. **Full-Container Vertical Menu Boundary in Workbench Tables (`SubtitleTableCoordinator+Menus.swift`)**:
   - Updated `menuBodyFrameInContainer()` to span the full vertical height of `SubtitleTableContainerView` (`y: container.bounds.minY, height: container.bounds.height`) while keeping the horizontal scroll viewport bounds (`scrollView?.frame ?? container.bounds`), and ensured `SubtitleTableMenuClipView` sits above the table header and page chrome (`positioned: .above, relativeTo: nil`).
   - Primary row menus and secondary destination submenus (`Save to Excerpt List`, `Move to ...`, `Duplicate to ...`) can now extend upward over the table header, toolbar, and Excerpt Detail Cover Summary without premature height truncation.
3. **Unit Tests (`MenuPlacementTests.swift`, `SubtitleTableVirtualRowTests.swift`)**:
   - Updated `MenuPlacementTests` to verify full-height edge sliding when `shrinksToFit: true`, height capping only when the entire container is shorter than the menu, horizontal pointer flip near the trailing edge, and button-left step when vertical shift would overlap a trailing button.
   - Added `subtitleTablePageChromeAllowsRowMenuAndSubmenuToExtendOverHeaderAndChromeWithoutPrematureTruncation` in `SubtitleTableVirtualRowTests` verifying that in an Excerpt Detail table with `pageChrome`, both the primary row menu and a 16-list submenu extend upward over the table header and page chrome at full height and receive pointer hit-testing there.

## Verification

- Automated tests:
  - `swift test --package-path apps/macos-native --filter "MenuPlacementTests|FileCardMenuTests|SubtitleTableRowActionMenuTests|subtitleTableViewRightClick|subtitleTableExcerptSubmenu|subtitleTablePageChromeAllowsRowMenuAndSubmenuToExtendOverHeaderAndChromeWithoutPrematureTruncation"`
