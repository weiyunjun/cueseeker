# 2026-10-23 Table Context Menu Keyboard Navigation Jitter Fix

## Requirement Reference
- `docs/human/requirements/20261023-Bug-Table Context Menu Keyboard Navigation Jitter Fix.md`

## Referenced Design Documents
- `docs/human/design/ui/UI Components - Controls.md`
- `docs/human/design/ui/UI Interaction Rules.md`

## Implementation Summary
1. **Whole-point menu layout metrics (`MenuMetrics.swift`)**:
   - Rounded `wanted.width` and `wanted.height` up to whole points (`ceil`) in `MenuItemStack.sizeThatFits` and `MenuItemStack.placeSubviews`, and compared against `floor(cap)` in `MenuItemStack.reserve(forContentHeight:)`.
   - Updated `MenuHeightCap.sizeThatFits` to return whole-point dimensions (`CGSize(width: ceil(wanted.width), height: max(0, min(ceil(wanted.height), floor(height))))`), eliminating fractional size mismatches between `NSHostingView.fittingSize` and SwiftUI's internal layout pass.
2. **Scrollable-only highlight reveal (`WorkbenchPopoverControls.swift`)**:
   - Tracked `MenuItemStack` height in `WorkbenchPopoverPanel` (`@State private var contentHeight: CGFloat = .infinity`) and guarded `contentHeight > floor(maximumHeight)` inside `revealHighlight(_:)`, avoiding no-op `ScrollViewReader.scrollTo` transactions on unclipped menus during keyboard/controller navigation.
3. **Integer-aligned table menu and submenu frames (`SubtitleTableCoordinator+Menus.swift`)**:
   - Added `integralMenuFrame(_:)` to snap `origin.x` and `origin.y` to nearest whole points, `width` to `ceil`, and `height` to `floor` in `openingMenuFrame`, `repositionOpenMenu`, and `showRowActionDestinationSubmenu`.
   - Synchronously laid out `menuHost` and `submenuHost` (`layoutSubtreeIfNeeded()`) after assigning their final frames and before un-hiding, and cleared `pendingMenuReposition` at the end of `showMenu`.
   - Removed temporary `MenuJitterProbe` diagnostic logging and local log file after end-to-end verification confirmed zero jitter across all menus.

## Verification
- Added `menuPanelSnapsFractionalMeasurementsAndKeepsUnclippedScrollBoundsStableOnKeyboardNavigation` in `MenuPanelHeightTests.swift` and `subtitleTableViewRightClickMenuAndSubmenuFramesAreIntegerAlignedAtFractionalCoordinates` in `SubtitleTableVirtualRowTests.swift`.
- Ran `swift test --package-path apps/macos-native --filter "MenuPlacementTests|MenuPanelHeightTests|SubtitleTableRowActionMenuTests|SubtitleTableVirtualRowTests"` (all 148 tests passed, matching expectations).
