# 2026-10-23 Layer Hover Reevaluation Isolation After Overlay Or Menu Dismiss

## Requirement Reference
- `docs/human/requirements/20261023-Bug-Layer Hover Reevaluation Isolation After Overlay Or Menu Dismiss.md`

## Referenced Design Documents
- `docs/human/design/ui/UI Design Rules.md`
- `docs/human/design/ui/UI Interaction Rules.md`
- `docs/human/design/ui/UI Components - Controls.md`

## Implementation Summary
1. **Responder-chain isolation & covering-layer suppression for `CueSeekerHostingView`**:
   - Added `performWithoutNextResponder(_:)` in `CueSeekerHostingView` (`AppPointerShape.swift`) to wrap `super.mouseEntered`, `super.mouseMoved`, and `super.mouseExited` calls on nested hosting views (`window?.contentView !== self`), preventing synthetic or local `mouseExited` events in nested table header/chrome hosts from bubbling up `NSResponder.nextResponder` and corrupting the root `window.contentView` hosting view's hover state.
   - Added `isHoverSyncSuppressedByCoveringLayer` on `CueSeekerHostingView` and overrode it in `SubtitleTablePageChromeHostingView` (`SubtitleTableChromeAndHeaderViews.swift`) to return `coordinator?.isPointerFrozen == true`, keeping nested table chrome hosts silent while covered or frozen.
   - Switched static text table column header cells in `updateHeaderHost` (`SubtitleTableChromeAndHeaderViews.swift`) to plain `NSHostingView`.
2. **Covered-layer silence in `SubtitleTableView`**:
   - Narrowed `SubtitleTableView.Coordinator.interfaceLayerContext.didSet` (`SubtitleTableView.swift`) so `updatePageChromeHosts()` only runs when the table's own `layer`, `isCovered`, or `isFrozen` state changes, ignoring transitions between higher layers above an already-covered table.
   - Guarded `!isCoveredByHigherLayer` in `SubtitleTableView.Coordinator.scrollDebounceDidSettle(_:)` (`SubtitleTableCoordinator+SelectionAndInput.swift`).
3. **Bidirectional geometric hover re-evaluation on layer unfreeze (`PointerHoverSession`)**:
   - Updated `PointerHoverSession.setFrozen(_:)` and `handleStateChanged()` (`PointerHover.swift`) so unfreezing a layer evaluates `currentPointerInsideView()` for both `true` (immediately activating `Hover` when the pointer is resting over a control on the newly active layer) and `false` (immediately clearing stale `Hover` when the pointer moved away while frozen or during synchronous menu transitions).

## Verification
- Added `exitingPlaybackOverlayWithNestedWorkbenchHostingViewPreservesPlayerButtonHover` in `PointerHoverGateTests.swift`.
- Ran `swift test --package-path apps/macos-native --filter "PointerHoverGateTests|InterfaceLayerFreezeTests|MenuInputBarrierTests|CardHighlightModelTests|PointerShapeModelTests"` (all 47 tests passed, matching expectations).
