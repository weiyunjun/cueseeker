# 2026-10-31 Keyboard and Controller Accessibility — Step 1 (Workbench Pages & Popup Menus)

## Requirement Reference
- `docs/human/requirements/20261031-UI-Keyboard And Controller Accessibility Across Workbench Dialogs Settings And Playback.md`
- `docs/human/design/ui/UI Accessibility Rules.md`
- `docs/human/design/playback/Controller.md`

## Summary of Changes (Step 1)
1. **Unified Accessibility Focus Ring & Tokens (`WorkbenchRedesignTokens.swift`, `PlaybackTheme.swift`, `WorkbenchAccessibility.swift`, `InterfaceLayerRegistry.swift`)**:
   - Added `--color-menu-item-selected-bg`, `--color-danger-bg-selected`, `--color-player-menu-item-selected-bg`, and `PlaybackTheme.focusRing`.
   - Implemented `.workbenchAccessibilityFocusRing(isFocused:cornerRadius:color:)` (`2px` stroke width, `2px` outer offset, zero geometry shift) and `WorkbenchAccessibilityScrollRevealProbe` (`NSScrollView` minimal non-animated scroll-to-visible accounting for pinned headers).
   - Forwarded `.environment(\.workbenchAccessibility, workbenchAccessibility)` across `InterfaceLayerHosting.bridgedRootView` boundaries.
2. **Popup Menus & Submenus (`MenuHighlightModel.swift`, `MenuGate.swift`, `MenuSubmenu.swift`, `WorkbenchPopoverControls.swift`, and all menu hosts)**:
   - Separated `selectedPosition`, `hoveredPosition`, and `accessibilityPosition` in `MenuHighlightModel` so pointer `Hover` and keyboard/controller/accessibility `Select` are independent, with `Select` taking visual priority on the same item.
   - Added `Tab` (`48`) / `Shift + Tab` (`0xFE30`) / controller `R1` / `L1` wrap-around menu accessibility traversal across `allPositions` (including disabled items, skipping dividers), syncing `selectedPosition` only for enabled items.
   - Implemented two-step `Esc` / controller `◯` dismissal in menus and submenus (1st `Esc` / `◯` clears accessibility focus ring while keeping `Select` and submenu open; 2nd `Esc` / `◯` closes the entire menu).
   - Wired controller input routing to open `MenuGate` clients across both Main and Settings windows.
3. **Main Window Workbench Accessibility (`WorkbenchAccessibility.swift`, `AppCoordinator+WorkbenchAccessibility.swift`, `ContentView.swift`, `TopbarAppEntries.swift`, `WorkbenchTabs.swift`, `CoverSummaryCard.swift`, `LibraryOverviewComponents.swift`, `LibraryMediaCards.swift`, `ExcerptListCardGrid.swift`, `WorkbenchFileView.swift`, `SchemaWorkbenchSearchShell.swift`, `SubtitleTableView.swift` & coordinators)**:
   - Implemented `L-01` topbar (`Sidebar Toggle` -> `Back` -> `Forward` -> `Recent` segments -> `Task` -> `Settings`, including `Disabled` and `Selected` states), sidebar (`Search` -> `Recent` -> `Library` -> `File` -> `Excerpt` when expanded in `Docked` or `Overlay`), and `L-01.3` page content traversal.
   - Implemented `Search` and `Excerpt` Detail (`Normal Mode` and `Select Mode`) accessibility sequences, including `Search Field` + `Inline Clear` (`✕`) auto-exit on disappearance, `Filter`, `Sort`, header `#` `Checkbox`, available rows (`Checkbox` -> `8px` rounded `Cues` interactive text without underline -> `dots-three`), and unavailable rows (`dots-three` only in `Normal Mode`, skipped in `Select Mode`).
   - Implemented `Recent`, `Library` Overview & Detail, `Excerpt` Overview cover card grids with `Select` synchronization and directional navigation (`↑` `↓` `←` `→` / D-pad / Left Stick) active only when accessibility focus is inside the card grid.
   - Implemented `File` Level 1/2/3 accessibility (`Add Folder` -> `Index All` -> `Status Indicator` in all states -> `Breadcrumb` parent links -> folder cards + `dots-three` -> episode container file rows `dots-three` only), wrapped `WorkbenchFileView` in `WorkbenchAccessibilityReader` so focus ring changes immediately re-render File page controls/cards/menus, added top focus ring clearance in the File page scroll surface so the first folder card's top focus ring is not clipped, and aligned `WorkbenchTabs`, `BreadcrumbLink`, and `WorkbenchStatusIndicator` focus ring corner radius to `--radius-field` (`6px`).

## Verification
- Updated `MenuHighlightModelTests.swift`, `PointerHoverGateTests.swift`, `SubtitleTableRowActionMenuTests.swift`, and `PlaybackNormalShortcutTests.swift`.
- Added `WorkbenchAccessibilityStep1Tests.swift` (including `filePageObservesAccessibilityFocusAndActivatesAddFolderAndCardMenus`).
- Ran `swift test --package-path apps/macos-native --filter WorkbenchAccessibilityStep1Tests`.
- Outcome matched expectations.
