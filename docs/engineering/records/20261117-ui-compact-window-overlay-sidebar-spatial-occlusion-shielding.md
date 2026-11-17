# 2026-11-17 Compact Window Overlay Sidebar Spatial Occlusion Shielding

- **Covering Requirement**: `docs/human/requirements/20261117-UI-Compact Window Overlay Sidebar Spatial Occlusion Shielding.md`
- **Referenced Design & Engineering Documents**:
  - `docs/engineering/02_git_workflow.md`
  - `docs/engineering/04_architecture_rules.md`
  - `docs/human/design/ui/UI Index.md`
  - `docs/human/design/ui/UI Interaction Rules.md`
  - `docs/human/design/ui/UI Layouts - Workbench.md`
- **Branch / Baseline**: `main` (pre-requirement baseline `0f51266`, requirement commit `18c7151`)

## Scope

1. Register a centralized compact-window `Overlay` `Sidebar` spatial occlusion region in `InterfaceLayerRegistry` and tag top-level overlay UI subtrees (`overlaySidebar`, `sidebarToggle`) with `.interfaceSublayer(.overlaySidebar)` without introducing an extra listener map or subclass-casting cursor branches.
2. Route unified hover/`Tooltip`, boundary slide-in/slide-out pointer updates, cursor shape adjudication, click/text-selection isolation, `SubtitleTable` hover/selection, `WorkbenchSelectableText` bounds clipping, and `TableScrollbarOverlayView` gating through `InterfaceLayerRegistry` occlusion checks while removing hardcoded `!isOverlaySidebarVisible` overrides from `ContentView`.
3. Document the centralized spatial-occlusion rule in `docs/engineering/04_architecture_rules.md`, add headless unit tests for `WindowOcclusionRegion` coordinate and sublayer rules, and keep non-test `apps/macos-native/Sources/` net additions strictly within `200` lines across `<= 10` files.

## Summary of Changes

1. **Centralized Window Occlusion Registry & Compact Sidebar Probe (`InterfaceLayerRegistry.swift`, `ContentView.swift`)**:
   - Added `InterfaceSublayer` (`.content`, `.overlaySidebar`), `WindowOcclusionRegion`, `windowOcclusionRegions`, `hasWindowOcclusionRegions`, `setWindowOcclusionRegion(_:forKey:)`, `isPointOccluded(_:on:sublayer:)`, `unoccludedWindowRect(_:on:sublayer:)`, `InterfaceLayerContext.sublayer`, and `View.interfaceSublayer(_:)`. Region updates asynchronously synchronize `PointerHoverSession.syncScrollSettled()` and `AppPointerShape.reevaluate()`.
   - In `AppTopBar` (`ContentView.swift`), tagged `sidebarToggle` and `overlaySidebar` with `.interfaceSublayer(.overlaySidebar)`, attached a passive `WindowOcclusionRegionProbe` (`hitTest(_:) -> nil`) to report the expanded `overlaySidebar` window frame on `.workbenchPage`, and removed hardcoded `isActive: !isOverlaySidebarVisible` from `backButton` and `forwardButton`.

2. **Unified Hover, Boundary Re-evaluation, Cursor Shape, and Underlying Control Shielding (`CueSeekerMainWindow.swift`, `PointerHover.swift`, `AppPointerShape.swift`, `SubtitleTableCoordinator+SelectionAndInput.swift`, `SubtitleTableChromeAndHeaderViews.swift`, `WorkbenchSelectableText.swift`, `TableScrollbarPrimitive.swift`)**:
   - Extended `CueSeekerWindow` / `CueSeekerMainWindow` with `interfaceLayers` and `isOccludedWorkbenchPoint(_:)`: suppressed occluded workbench text selection clicks, unfocused text input right-clicks/focus switches, and tracked control sessions; added `PointerHoverSession.syncWindowOcclusionPointerMoved(in:at:)` dispatch during `.mouseMoved` whenever `interfaceLayers?.hasWindowOcclusionRegions == true`.
   - Added `sublayer`, `isWindowPointOccluded(_:)`, unified `probeLocalPointIfInside(_:)`, and `syncWindowOcclusionPointerMoved(in:at:)` in `PointerHover.swift` so both standard hover/`Tooltip` probes and location-tracked probes exit hover immediately upon entering the `Overlay` `Sidebar` and activate upon sliding into the exposed area across the `240px` boundary.
   - Updated `AppPointerShape.surfaceShape(at:)` to return `.arrow` over occluded `.workbenchPage` points when menus/modals do not own an active I-beam override, without enumerating `NSView` input subclasses.
   - Guarded `SubtitleTableView.Coordinator` (`isPointOccluded`, `externalTextSelectionWindowRect`, `isWindowPointInSelectableDataRegion`, `beginExternalTextSelection`, `headerPointerShape`, `pointerShape`, `handleMouseHover`, `handleMouseDown`, `handleHeaderMouseDown`, `handleRightMouseDown`) and `SubtitleVirtualTableHeaderView.updateHoverState()`.
   - Synced `session.sublayer` and guarded `hitTest(_:)`, `clippedVisibleWindowRect(for:)`, `mouseDown(with:)`, and `rightMouseDown(with:)` in `WorkbenchSelectableTextNSView`.
   - Guarded `TableScrollbarOverlayView` (`isPointOccluded(atWindowPoint:)` skipping `.workbenchPage` occlusion when an open menu is uncovered) in `handleFocusNotification()`, `hitTest(_:)`, `mouseMoved(with:)`, and `mouseDown(with:)`.

3. **Architecture Rule & Headless Tests (`docs/engineering/04_architecture_rules.md`, `Tests/CueSeekerAppTests/InterfaceLayerFreezeTests.swift`)**:
   - Added the §7 architecture constraint placing local window spatial occlusion under `InterfaceLayerRegistry` and forbidding business controls from hardcoding `!isOverlaySidebarVisible`.
   - Added headless tests `windowOcclusionRegionRespectsSublayerAndLayerIsolation` and `unoccludedWindowRectClipsStraddlingControls` in `InterfaceLayerFreezeTests.swift`.

## Verification

- **Build check**:
  - `swift build --package-path apps/macos-native`: Build complete (`11.48s`, zero errors).
- **Non-test production code net delta check**:
  - `git diff --stat apps/macos-native/Sources/`: `9 files changed, 249 insertions(+), 72 deletions(-)` (net `+177` lines across `9` source files).
- **Targeted sequential test run (after final test edit)**:
  - `swift test --package-path apps/macos-native --no-parallel --filter "InterfaceLayerFreezeTests|WorkbenchDialogLayerTests|PointerShapeModelTests|TableScrollbarPrimitiveTests|WorkbenchSelectableTextTests|CardHighlightModelTests|MenuHighlightModelTests"`: `76` tests passed in `4.677` seconds (`0` failures).
- **Filtered package test run (excluding window-interactive suites per workflow rules)**:
  - Command: `swift test --package-path apps/macos-native --skip DebugE2EControllerTests --skip WorkbenchInputControlsTests --skip PointerHoverGateTests --skip CueGroupRefreshScopeIntegrationTests --skip PlaybackPageFocusIsolationTests`
  - Result: Compiled cleanly (`0` errors); `1735` tests executed with `73` pre-existing unrelated issues under parallel execution (matching baseline `AppLocalizationTests`, `CueFacetCountCacheTests`, `ExcerptLifecycleAndInvalidItemsTests`, `LibraryFolderAdditionTests`, `LibraryFolderRemovalTests`, `NativePlaybackMediaTimelineTests`, `NativePlaybackPresentationTransitionTests`, `PlaybackCollagePreviewTests`, `PlaybackPlaylistSourceTests`, `PlaybackPresentationTransitionTests`, `PlaybackReturnContextTests`, `PlaybackSubtitleFirstFrameTelemetryTests`, `PlaybackSubtitleFocusLayoutTests`, `PlaybackSubtitleFocusSessionStoreTests`, `TooltipTests`, and `WorkbenchPageScrollbarTests`); `InterfaceLayerFreezeTests`, `WorkbenchDialogLayerTests`, `PointerShapeModelTests`, `TableScrollbarPrimitiveTests`, `WorkbenchSelectableTextTests`, `CardHighlightModelTests`, and `MenuHighlightModelTests` had `0` failures.
- **Engineering doc language check**:
  - `bash scripts/verify_engineering_doc_lang.sh docs/engineering/04_architecture_rules.md docs/engineering/records/20261117-ui-compact-window-overlay-sidebar-spatial-occlusion-shielding.md`

## Outcome

Compact-window `Overlay` `Sidebar` spatial occlusion shielding is implemented across `9` files under `apps/macos-native/Sources/` with `+177` net lines, documented in `docs/engineering/04_architecture_rules.md`, and verified by headless unit tests. End-to-end interactive pointer, cursor, selection, and `Tooltip` visual acceptance in live compact windows remains for user verification.
