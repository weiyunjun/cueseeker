# 2026-11-11: Unify Cover Card Hover and Pointer Reevaluation Rules

## Requirement Source
- `docs/human/requirements/20261111-Bug-Unify Cover Card Hover And Pointer Reevaluation Rules.md`
- `docs/human/design/ui/UI Interaction Rules.md`
- `docs/human/design/ui/UI Components - Domain.md`

## Summary of Changes
1. **Unify Cover Card Hover Entry onto `onPointerHover` (`LibraryMediaCards`, `ExcerptListCardGrid`, `LibraryCardContextMenuHost`)**:
   - Switched `LibraryVideoCard`, `LibraryFolderCard`, and `ExcerptListCard` from the focus-only `.onWindowFocusAwareHover` wrapper onto the unified `.onPointerHover` modifier (`PointerHoverSession` + `PointerHoverGate` + `PointerHoverProbeView`), while keeping `CardHighlightModel` as the single authority for `Select` vs `Hover` and `effectiveShowsHand` (`Grab` on card body, default arrow on the `dots-three` action button).
   - Synchronized `PointerHoverSession.resyncHoverForMenuRelay(on:in:)` when opening cover-card menus (`LibraryCardContextMenuHost.openMenu`) and on card press actions so stationary right-clicks and cross-card menu relays reconcile live pointer containment before freezing.
2. **Layer Unfreeze Order, Scroll Settle Reevaluation, and Re-entry Tracking (`InterfaceLayerRegistry`, `PointerHover`, `CardHighlightModel`, `04_architecture_rules.md`)**:
   - Ordered `PointerHoverSession.broadcastLayerFrozenChanged(false, ...)` before `CardHighlightModel.broadcastLayerFrozenChanged(false, ...)` on menu dismissal and higher-layer close, and invoked `AppPointerShape.reevaluate()` when an unfrozen layer closes its menu, so `CardHighlightModel` and `AppPointerShape` immediately reflect live pointer containment (clearing stale card `Hover`, `dots-three` visibility, and `Grab` cursor over blank areas, or lighting a newly hovered card without extra mouse movement).
   - Added `PointerHoverSession.syncScrollSettled()` in `PointerHoverScrollState.settleScroll()` so unfrozen `onPointerHover` surfaces re-sample live pointer containment after the `300ms` scroll debounce settles.
   - Added `tracksReenter` on `PointerHoverProbeView` so when an active hover is cleared by unfreeze or scroll settle while SwiftUI `.onHover` never observed `mouseExited` (e.g., while `MenuGate` swallowed motion events), `PointerHoverProbeView` arms a crossing tracking area to catch immediate pointer re-entry.
   - Guarded `isHostingWindowFocused` in `CardHighlightModel.setFrozen(false)` and `syncHoveredID()` so unfreezing an unfocused window never restores `Hover` or claims `Grab`.
   - Updated `docs/engineering/04_architecture_rules.md` to document that cover cards also route through `onPointerHover`.
3. **Unit & Integration Tests (`CardHighlightModelTests`, `PointerHoverGateTests`)**:
   - Added `coverCardsUseUnifiedPointerHoverAndReevaluateHoverAndCursorOnMenuAndDialogUnfreeze` in `CardHighlightModelTests` verifying zero legacy `WindowFocusHoverProbeView` instances on cover cards and validating `Hover`, `dots-three` visibility, and pointer shape across menu open/dismiss over blank space, menu open/dismiss onto another card, `dots-three` button menu dismissal, and dialog layer unfreeze.
   - Added `pointerHoverProbeViewRecoversReentryWhenExitedWhileMenuSwallowedMotion` in `PointerHoverGateTests` verifying immediate re-entry and subsequent exit recovery after unfreeze clears hover.

## Verification
- Ran `swift test --package-path apps/macos-native --no-parallel --filter "PointerHoverGateTests"` (`15` tests passed).
- Ran `swift test --package-path apps/macos-native --no-parallel --filter "CardHighlightModelTests|PointerShapeModelTests|MenuInputBarrierTests|InterfaceLayerFreezeTests|MenuHighlightModelTests|TaskCardMenuTests|FileCardMenuTests|WorkbenchAccessibilityStep1Tests|WorkbenchAccessibilityStep4Tests"` (`85` tests passed).
- Result matched all requirement and UI interaction expectations; end-to-end visual and cursor verification is ready for user acceptance.
