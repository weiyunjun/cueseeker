# 2026-10-22 Menu Open State Exclusivity And Exit Transition

## Requirement Reference
- `docs/human/requirements/20261022-Bug-Menu Open State Exclusivity And Exit Transition.md`

## Summary of Changes
1. **Synchronous Layer Unfreeze & Exit Transition for `PointerHoverSession`**:
   - Added a weak session registry and `PointerHoverSession.broadcastLayerFrozenChanged(_:matching:)` in `PointerHover.swift`, invoked synchronously by `InterfaceLayerRegistry` in `setOpen`, `registerOpenMenu`, and `menuDidClose`.
   - Attached a non-hit-testing `PointerHoverProbe` view to `PointerHoverModifier` so `PointerHoverSession.setFrozen(_:)` can synchronously check whether the live pointer is still inside the control's visible bounds when a menu closes and its layer unfreezes (even when `MenuGate` swallowed intermediate `.mouseMoved` events while the menu was open).
   - When an open menu closes (`menuDidClose`) — including during a synchronous right-click menu relay onto a `SubtitleTableView` row — any previously open menu trigger button whose pointer has moved outside its bounds immediately clears its `Hover` highlight before the newly opened menu re-freezes the layer, ensuring both the menu and the trigger button's gray background exit together.
   - Posted `.cueSeekerScrollDebounceSettled` when a layer finishes unfreezing so `CueSeekerHostingView` resynchronizes pointer hover state at the current pointer position.

## Verification
- Added `synchronousMenuRelayClearsStaleTriggerButtonHoverWhenPointerMovedAwayWhileMenuWasOpen` in `PointerHoverGateTests.swift`.
- Ran `swift test --package-path apps/macos-native --filter "PointerHoverGateTests|InterfaceLayerFreezeTests|MenuInputBarrierTests|CardHighlightModelTests|PointerShapeModelTests"` (all 46 tests passed).
