# 2026-11-17 Tooltip Hover Gate Unification and Truncated Selectable Text Reporting

- **Covering Requirement**: `docs/human/requirements/20261117-UI-Tooltip Hover Gate Unification And Truncated Selectable Text Reporting.md`
- **Referenced Design & Engineering Documents**:
  - `docs/engineering/02_git_workflow.md`
  - `docs/engineering/04_architecture_rules.md`
  - `docs/human/design/ui/UI Index.md`
  - `docs/human/design/ui/UI Interaction Rules.md`
  - `docs/human/design/ui/Tooltip Usage Registry.md`
- **Branch / Baseline**: `main` (pre-requirement baseline `e5745ec`, requirement commit `e2b28a7`)

## Scope

1. Delete `TooltipTrackingRepresentable` and `TooltipTrackingNSView` from `Tooltip.swift` and unify `TooltipModifier` onto `PointerHover` (`PointerHoverProbeView`, `PointerHoverSession`, and `PointerHoverScrollState`) so stationary pointers over newly opened dialogs/panels do not trigger `hoverBegan`.
2. Enforce `TooltipCenter` pressed/drag interaction blocking (`NSEvent.pressedMouseButtons != 0`, active selectable-text drag selection) and same-target wake-movement re-arming from `CueSeekerWindow.sendEvent` (`.mouseMoved` exceeding `PointerHoverScrollState.wakeMovementThreshold`) with full `hoverDelay` (`1s`) and no skip-window fast path.
3. Move truncation detection and tooltip reporting into `WorkbenchSelectableText` / `WorkbenchSelectableTextNSView` using TextKit layout results (`isTextTruncated`) and `visibleWindowClipRect()` via shared `PointerHoverProbeView`, migrate all 3 `WorkbenchSelectableText` + `.workbenchTruncatedTextTooltip` call sites (`PlaybackCommandPanel`, `SchemaWorkbenchSearchShell`, `TaskPanel`), and replace the hidden `Text` + dual `GeometryReader` / `PreferenceKey` plumbing in `TextTruncationObserverModifier` with direct `NSFont` single-line measurement for the remaining 4 static `Text` callers (`WorkbenchPageTitle`, `LiquidGlassVideoTopBar`, `SettingsView`, `CueFacetFilterPanel`).

## Summary of Changes

1. **Unified Tooltip Hover Probe & Window Wake Routing (`PointerHover.swift`, `Tooltip.swift`, `CueSeekerMainWindow.swift`)**:
   - Deleted `TooltipTrackingRepresentable` and `TooltipTrackingNSView` from `Tooltip.swift`, exposed `onPointerHoverSession` plus `PointerHoverSession` (`windowHitRect`, `onDisappear`, `onBoundsChanged`) and shared clip-rect `mouseMoved` handling in `PointerHoverProbeView` (`PointerHover.swift`), and migrated `TooltipModifier` onto `onPointerHoverSession` + `TooltipCenter.syncHover`.
   - Added `isBlocked` / `isSuppressed` gates, `suppressedOriginScreenLocation`, and `notePointerMoved(atScreenLocation:)` in `TooltipCenter`, simplified `HoveredTarget` around `TooltipActiveItem` (removing duplicate `updateTarget`), and wired `CueSeekerWindow.sendEvent` (`.mouseMoved` when `!PointerHoverScrollState.shared.isHoverSuppressed`) in `CueSeekerMainWindow.swift` to wake `suppressedTargetID` after moving at least `PointerHoverScrollState.wakeMovementThreshold` while requiring the full `hoverDelay` (`1s`).
2. **Cohesive Selectable-Text & Static-Text Truncation Reporting (`WorkbenchSelectableText.swift`, `Tooltip.swift`, `WorkbenchControlMetrics.swift`, Callers)**:
   - Computed `isTextTruncated` inside `WorkbenchSelectableTextNSView.updateTextLayout()` (single-line truncation or multi-line `truncatedGlyphRange` inspection via `hasTruncatedGlyphLineFragment()`), added optional `truncationTooltipScenarioID` and `truncationTooltipSurface` on `WorkbenchSelectableText`, attached `PointerHoverProbeView` sized to `layoutBounds` with `windowHitRect = { visibleWindowClipRect() }`, and preserved pressed-mouse / drag suppression while reporting clipped bounds to `TooltipCenter`.
   - Migrated `PlaybackCommandPanel.swift` (`truncated.command_panel.secondary_title`), `SchemaWorkbenchSearchShell.swift` (`truncated.toolbar.batch_selection_banner`), and `TaskPanel.swift` (`truncated.dialog.title`) to `WorkbenchSelectableText(..., truncationTooltipScenarioID:)`.
   - Replaced `TruncatedTextRenderedWidthKey`, `TruncatedTextIntrinsicWidthKey`, and hidden `Text` measurement in `TextTruncationObserverModifier` with direct `(text as NSString).size(withAttributes: [.font: font]).width` comparison using `NSFont` (`WorkbenchControlMetrics.redesignNSFontWeightPageTitle`, `LiquidGlassVideoTopBar.swift`, `SettingsView.swift`, `CueFacetFilterPanel.swift`).
3. **Headless Unit Tests (`TooltipTests.swift`, `WorkbenchSelectableTextTests.swift`)**:
   - Added `tooltipCenterBlocksWhileMousePressedOrHoverSuppressed` and `tooltipCenterRestartsFullDelayOnlyAfterWakeMovementWithinSameTarget` in `TooltipTests.swift`.
   - Added `selectableTextViewDetectsSingleLineAndMultilineTextKitTruncation` in `WorkbenchSelectableTextTests.swift`.

## Verification

- **Build check**:
  - `swift build --package-path apps/macos-native`: Build complete (`10.48s`, zero errors).
- **Non-test production code net delta check**:
  - `git diff --stat apps/macos-native/Sources/`: `11 files changed, 368 insertions(+), 457 deletions(-)` (net reduction of `89` lines in `apps/macos-native/Sources/`).
- **Sequential targeted test run (after final edit)**:
  - Command: `swift test --package-path apps/macos-native --no-parallel --filter "TooltipTests|WorkbenchSelectableTextTests|InterfaceLayerFreezeTests|WorkbenchDialogLayerTests|CardHighlightModelTests|MenuHighlightModelTests"`
  - Result: `73` of `74` tests passed in `5.119s`, including both new `TooltipTests` cases and `25` of `25` tests in `WorkbenchSelectableTextTests`; `1` pre-existing failure in `TooltipTests.tooltipRemainsVisibleAcrossWindowFocusLossAndDismissesOnWindowClose` (where `TooltipCenter()` defaults to `installEventMonitors: false`, already failing on baseline `e2b28a7`).
- **Filtered full package test run (after final edit, compiling all test targets including skipped suites)**:
  - Command: `swift test --package-path apps/macos-native --skip DebugE2EControllerTests --skip WorkbenchInputControlsTests --skip PointerHoverGateTests --skip CueGroupRefreshScopeIntegrationTests --skip PlaybackPageFocusIsolationTests`
  - Result: Compiled cleanly (`0.34s`); ran `1733` tests with `67` issues across `AppLocalizationTests.swift`, `CueFacetCountCacheTests.swift`, `ExcerptLifecycleAndInvalidItemsTests.swift`, `LibraryFolderAdditionTests.swift`, `LibraryFolderRemovalTests.swift`, `NativePlaybackMediaTimelineTests.swift`, `NativePlaybackPresentationTransitionTests.swift`, `PlaybackCollagePreviewTests.swift`, `PlaybackPlaylistSourceTests.swift`, `PlaybackPresentationTransitionTests.swift`, `PlaybackReturnContextTests.swift`, `PlaybackSubtitleFocusLayoutTests.swift`, `PlaybackSubtitleFocusSessionStoreTests.swift`, `TaskQueueStoreTests.swift`, `TooltipTests.swift`, and `WorkbenchPageScrollbarTests.swift`; `WorkbenchSelectableTextTests` and both new isolated `TooltipTests` cases passed `100%` (remaining `TooltipTests` issues under parallel execution stemmed from shared global `PointerHoverScrollState.shared` / `AppCursorVisibility` contention with concurrent suites).
- **Engineering doc language check**:
  - Verified with `bash scripts/verify_engineering_doc_lang.sh docs/engineering/records/20261117-ui-tooltip-hover-gate-unification-and-truncated-selectable-text-reporting.md`.

## Outcome

Tooltip hover tracking is unified on `PointerHover`, pressed/suppressed interaction gates and same-target wake re-timing are enforced in `TooltipCenter`, and `WorkbenchSelectableText` handles its own TextKit truncation detection and clipped tooltip reporting with an `89`-line net reduction across `apps/macos-native/Sources/`. Live visual tooltip timing, cursor-drag suppression, and truncated-text hover UX remain for user acceptance.
