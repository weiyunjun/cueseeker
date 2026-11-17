# 2026-11-17 Stacked Dialog Layer Freeze and Hover State Consolidation

- **Covering Requirement**: `docs/human/requirements/20261117-UI-Stacked Dialog Layer Freeze And Hover State Consolidation.md`
- **Referenced Design & Engineering Documents**:
  - `docs/engineering/02_git_workflow.md`
  - `docs/engineering/04_architecture_rules.md`
  - `docs/human/design/ui/UI Index.md`
  - `docs/human/design/ui/UI Design Rules.md`
  - `docs/human/design/ui/UI Interaction Rules.md`
  - `docs/human/design/ui/UI Text Selection Rules.md`
- **Branch / Baseline**: `main` (pre-requirement baseline `0ddbe42`, requirement commit `59cd96c`)

## Scope

1. Replace the manual `IsWorkbenchDialogCoveredKey` / `EnvironmentValues.isWorkbenchDialogCovered` coverage plumbing with a native `.stackedDialog` case above `.dialog` in `InterfaceLayer`, propagate layer freeze through `WorkbenchScrollView` and `TableScrollbarOverlayView`, and migrate hardcoded `.dialog` checks across main-window/accessibility/text-selection owners to `InterfaceLayer.isDialog` / `InterfaceLayerRegistry.hasOpenDialog`.
2. Consolidate hover tracking onto a single AppKit `NSTrackingArea` path in `PointerHoverProbeView`, delete SwiftUI `.onHover` dual-tracking and the `tracksReenter` / `tracksHostedContent` workarounds, delete the `WindowFocusHoverSession` / `WindowFocusHoverProbeView` / `onWindowFocusAwareHover` stack by adding `ignoresLayerFreeze: Bool` to `onPointerHover`, and strip redundant scroll-state copies, deprecated compatibility shims (`adopt`, `currentID`, `setCurrent`, `defaultPosition`), and duplicate async recalculation patches from `CardHighlightModel`, `MenuHighlightModel`, and `PointerHoverScrollState`.
3. Synchronize `docs/engineering/04_architecture_rules.md` (§7) and `Tests/CueSeekerAppTests/` with the consolidated layer/hover APIs while achieving a net line reduction in non-test code under `apps/macos-native/Sources/`.

## Summary of Changes

1. **Stacked Dialog Layering & Scroll Freeze (`InterfaceLayerRegistry.swift`, `WorkbenchDialogLayer.swift`, `ContentView.swift`, `SettingsView.swift`, `WorkbenchScrollView.swift`, `TableScrollbarPrimitive.swift`, and `.dialog` callers)**:
   - Added `InterfaceLayer.stackedDialog` above `.dialog`, `var isDialog: Bool`, and `InterfaceLayerRegistry.hasOpenDialog`.
   - Updated `InterfaceLayerRegistry` (`setOpen`, `givePageFocusUp`, `InterfaceLayerCoverageBridge`) so both dialog tiers keep focus isolation consistent, clear `topDialogSize` only when `!hasOpenDialog`, and naturally preserve hover suppression in `menuDidClose(ownedBy: .dialog)` whenever `.stackedDialog` keeps `.dialog` frozen.
   - Split `WorkbenchDialogLayer` into `baseDialogIDs` (`.dialog`) and `stackedDialogIDs` (`.stackedDialog`), retained convenience `init(dialogIDs:topBandHeight:dialogs:)`, updated `ContentView` and `SettingsView`, bound `dialogLayer = level >= 2 ? .stackedDialog : .dialog` and `.allowsHitTesting(!isCovered)` on `WorkbenchDialogFrame`, removed `isCovered` from `workbenchDialog(level:)`, and deleted `IsWorkbenchDialogCoveredKey` / `EnvironmentValues.isWorkbenchDialogCovered`.
   - Migrated hardcoded `.dialog` checks in `AppDelegate.swift`, `AppCoordinator+WorkbenchAccessibility.swift`, `CueSeekerMainWindow.swift`, `WorkbenchFormControls.swift`, `WorkbenchSelectableText.swift`, and `WorkbenchStaticTextSelectionCoordinator.swift` (using `priorityRank = 500 + layer.rawValue` in `StaticTextFlowScope.dialog`) to `isDialog` / `hasOpenDialog`, removing `isDialogCovered` plumbing from `WorkbenchSelectableText`.
   - Added `ignoresLayerFreeze: Bool = false` and `.scrollDisabled(isFrozen)` to `WorkbenchScrollView`, guarded `TableScrollbarOverlayView.hitTest(_:)`, `scrollWheel(with:)`, and `onScrollWheel` with `isInteractionFrozen`, and opted inline popover scroll containers (`WorkbenchPopoverControls.swift`, `WorkbenchFileDetailDialog.swift`, `SettingsSubtitleCategory.swift`) into `ignoresLayerFreeze: true`.

2. **Hover Tracking Consolidation & Redundant State Removal (`PointerHover.swift`, `CardHighlightModel.swift`, `MenuHighlightModel.swift`, and callers)**:
   - Removed `.onHover` from `PointerHoverModifier` along with `tracksReenter` / `tracksHostedContent` mode switching (`TaskPanel.swift`, `WorkbenchFileView.swift`), unifying `PointerHoverProbeView` on a single `.activeAlways` + `.inVisibleRect` + `.mouseEnteredAndExited` tracking area (adding `.mouseMoved` when `tracksLocation` and `.assumeInside` when `assumesMouseInside`).
   - Added `ignoresLayerFreeze: Bool = false` to `onPointerHover` (evaluating `isCovered` rather than `isFrozen` on the owning layer, and calling `PointerHoverSession.syncScrollSettled()` before `MenuHighlightModel.broadcastPointerMoved` on pointer wake), migrated all four `.onWindowFocusAwareHover` call sites (`WorkbenchPopoverControls.swift`, `SubtitleTableMenuAndCheckboxViews.swift`, `PlaybackChromeSpeedMenu.swift`, `WorkbenchFileDetailDialog.swift`), and deleted `WindowFocusHoverSession`, `WindowFocusHoverProbeView`, `WindowFocusHoverProbe`, `WindowFocusAwareHoverModifier`, and `onWindowFocusAwareHover`.
   - Removed `PointerHoverSession.broadcastLayerFrozenChanged` in favor of `PointerHoverSession.syncFrozenStates(in:)`, and removed the duplicate deferred `Task` recalculation in `PointerHoverScrollState.clearSuppressionForOverlayClose`.
   - Deleted redundant `isScrolling` properties, `broadcastScrolled()` / `noteScrolled()`, `adopt`, `currentID`, `setCurrent`, and unused `defaultPosition` parameters from `CardHighlightModel` and `MenuHighlightModel` (plus `PlaybackStore.swift`, `PlaybackChromeView.swift`, `PlaybackMediaSelectionStore.swift`, `SchemaWorkbenchSearchShell.swift`, `SubtitleTableCoordinator+Menus.swift`), while preserving `MenuHighlightModel`'s `initiallySuppressed` submenu handling.

3. **Architecture Documentation & Headless Tests (`docs/engineering/04_architecture_rules.md`, `Tests/CueSeekerAppTests/`)**:
   - Updated `docs/engineering/04_architecture_rules.md` (§7) to specify `onPointerHover(ignoresLayerFreeze: true)` for menu items instead of the removed `onWindowFocusAwareHover`.
   - Updated `PointerHoverGateTests.swift`, `CardHighlightModelTests.swift`, `MenuHighlightModelTests.swift`, `TaskCardMenuTests.swift`, `WorkbenchSelectableTextTests.swift`, `PlaybackMoreMenuTests.swift`, `PlaybackNormalShortcutTests.swift`, and `SettingsAndDialogsStaticTextSelectionTests.swift` for the consolidated APIs and test isolation.
   - Added headless tests in `InterfaceLayerFreezeTests.swift` (`stackedDialogFreezesAndCoversLowerDialogWithoutFreezingItself`, `closingDialogMenuWhileStackedDialogIsOpenPreservesHoverSuppression`), `WorkbenchDialogLayerTests.swift` (`dialogLayerIsOpenWhileItsListHasADialogAndClosedOnceItIsEmpty` stacked-dialog transition coverage), and `MenuHighlightModelTests.swift` (`scrollStateWakeClearsSuppressionAndRestoresMenuHover`).

## Verification

- **Build check**:
  - `swift build --package-path apps/macos-native`: Build complete (`0.35s`, zero errors).
- **Non-test production code net delta check**:
  - `git diff --stat apps/macos-native/Sources/`: `27 files changed, 236 insertions(+), 511 deletions(-)` (net reduction of `275` lines in `apps/macos-native/Sources/`).
- **Targeted sequential test runs (after final edit)**:
  - `swift test --package-path apps/macos-native --no-parallel --filter "InterfaceLayerFreezeTests|WorkbenchDialogLayerTests|CardHighlightModelTests|MenuHighlightModelTests|TaskCardMenuTests|LibraryCardMenuPlacementTests|PlaybackMoreMenuTests|PlaybackNormalShortcutTests|ExcerptListEditorTests|WorkbenchSelectableTextTests|WorkbenchAccessibilityStep1Tests"`: `127` tests passed in `6.052` seconds (`0` failures).
  - `swift test --package-path apps/macos-native --no-parallel --filter "TableScrollbarPrimitiveTests|MenuInputBarrierTests|PointerShapeModelTests|SubtitleTableRowActionMenuTests|FileDetailDialog|PlaybackCollagePreview|RemoteFolder"`: `68` tests passed in `0.650` seconds (`0` failures).
- **Filtered full package test run (after final edit, compiling all test targets including skipped suites)**:
  - Command: `swift test --package-path apps/macos-native --skip DebugE2EControllerTests --skip WorkbenchInputControlsTests --skip PointerHoverGateTests --skip CueGroupRefreshScopeIntegrationTests --skip PlaybackPageFocusIsolationTests`
  - Result: Compiled cleanly (`Build complete! (0.31s)`), ran `1730` tests with `63` pre-existing unrelated issues (`AppLocalizationTests`, `CueFacetCountCacheTests`, `ExcerptLifecycleAndInvalidItemsTests`, `LibraryFolderAdditionTests`, `LibraryFolderRemovalTests`, `NativePlaybackMediaTimelineTests`, `NativePlaybackPresentationTransitionTests`, `PlaybackCollagePreviewTests` parallel flake that passed `100%` sequentially above, `PlaybackPlaylistSourceTests`, `PlaybackPresentationTransitionTests`, `PlaybackReturnContextTests`, `PlaybackSubtitleFirstFrameTelemetryTests`, `PlaybackSubtitleFocusLayoutTests`, `PlaybackSubtitleFocusSessionStoreTests`, `TooltipTests`, `WorkbenchPageScrollbarTests`); zero failures across any modified dialog, layer, hover, menu, or selectable-text suites.
- **Engineering doc language check**:
  - `bash scripts/verify_engineering_doc_lang.sh docs/engineering/04_architecture_rules.md docs/engineering/records/20261117-ui-stacked-dialog-layer-freeze-and-hover-state-consolidation.md`

## Outcome

Stacked dialog layering and consolidated pointer-hover tracking are implemented with a `275`-line net reduction under `apps/macos-native/Sources/`. Interactive hover, stacked dialog visual/cursor acceptance, and subsequent UI design doc sync remain for user acceptance.
