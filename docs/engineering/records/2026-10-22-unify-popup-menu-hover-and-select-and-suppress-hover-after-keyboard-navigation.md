# 2026-10-22 Unify Popup Menu Hover And Select And Suppress Hover After Keyboard Or Controller Navigation

## Requirement Reference
- `docs/human/requirements/20261022-UI-Unify Popup Menu Hover And Select And Suppress Hover After Keyboard Or Controller Navigation.md`

## Summary of Changes
1. **Unified Popup Menu Highlight & Removed Default Selection**:
   - Updated `MenuHighlightModel` so that `open(selectablePositions:defaultPosition:)` always starts with `highlightedPosition == nil` (`selectedPosition` and `hoveredPosition` are unified onto `highlightedPosition`).
   - Updated `MenuHighlightModel.moveHighlight(by:)` so that when `highlightedPosition == nil`, pressing Up (`offset < 0`) highlights the last selectable item and pressing Down (`offset > 0`) highlights the first selectable item; when an item is already highlighted, Up/Down moves by 1 selectable item and stops at boundaries without wrapping.
   - Unified the row background rendering in `WorkbenchPopoverRow` and `PlaybackChromeMenuButtonStyle` so that highlighted/hovered menu rows use the existing `Hover` visual style (`WorkbenchRedesignColors.bgHover`, `WorkbenchRedesignColors.dangerBgHover`, `PlaybackTheme.menuItemHoverBackground`).
   - Updated `MenuSubmenuState` and its callers (`PlaybackStore`, `PlaybackChromeMoreMenu`, `SubtitleTableView`) so submenus open with no default highlighted item while pinning the parent trigger item's highlight in the parent menu, and pressing Left arrow closes the submenu while keeping the parent trigger item highlighted.
   - Ensured pressing Return/Enter when `highlightedPosition == nil` in an open menu or submenu consumes the key without executing an action or closing the menu.
2. **Pointer Hover Suppression After Keyboard or Controller Selection Navigation**:
   - Extended `PointerHoverScrollState` with `isSuppressedByKeyboardOrController` and `isHoverSuppressed`, entered whenever keyboard or controller navigation moves selection/highlight in Playback cover cards (`PlaybackMediaSelectionStore.move`), Command Panel root or recent card grids (`AppCoordinator+PlaybackCommandPanel`), or popup menus/submenus (`MenuHighlightModel.moveHighlight`, `MenuSubmenuState.open`, `MenuSubmenuState.closeSubmenu`).
   - Immediately clears active mouse `Hover` on sibling items in the same layer (`CardHighlightModel`, `PointerHoverGate` / `PointerHoverModifier`, `MenuHighlightModel`) and resets any card `.grab` cursor shape back to `.arrow` via `AppPointerShape.reevaluate()`.
   - Preserves keyboard/controller Hover suppression across wheel scroll debounce settling (`settleScroll()`), exiting only upon actual pointer movement (`notePointerMoved()`).

## Verification
- Verified unit tests in `MenuHighlightModelTests`, `CardHighlightModelTests`, `PointerHoverGateTests`, `PlaybackMoreMenuTests`, `PlaybackNormalShortcutTests`, and `SubtitleTableRowActionMenuTests`.
