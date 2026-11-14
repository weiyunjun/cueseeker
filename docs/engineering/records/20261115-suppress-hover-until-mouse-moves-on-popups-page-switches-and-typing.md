# Suppress Hover Until Mouse Moves On Popups, Page Switches, And Typing

- Date: 2026-11-15
- Related Requirement: `docs/human/requirements/20261115-UI-Suppress Hover Until Mouse Moves On Popups Page Switches And Typing.md`
- Scope: `CueSeekerApp`, `CueSeekerAppTests`

## Changes Made

- **Reused `PointerHoverScrollState.shared` with `0.5pt` screen-displacement wake threshold and clean suppression/overlay-close lifecycle** (`Shared/PointerHover.swift`, `Shared/CueSeekerMainWindow.swift`, `Shared/AppPointerShape.swift`, `App/AppDelegate.swift`):
  - Added `.cueSeekerHoverSuppressed`, `wakeMovementThreshold = 0.5`, `hasMovedAtLeastWakeThreshold(from:to:)`, `suppressedOriginScreenLocation` capture in `suppressHoverUntilMouseMoves()`, `clearSuppressionForOverlayClose(recalculate:)`, and `@discardableResult notePointerMoved(atScreenLocation:)` on `PointerHoverScrollState`.
  - Updated `CueSeekerWindow.sendEvent` to pass `NSEvent.mouseLocation` on `.mouseMoved` so zero-displacement synthetic AppKit `.mouseMoved` events do not clear suppression, while real `>= 0.5pt` motion wakes all hover listeners, `PointerHoverSession`, `WindowFocusHoverSession` (`syncPointerMoved()`), `CardHighlightModel`, `MenuHighlightModel`, and `AppPointerShape` without crossing `InterfaceLayerRegistry.isFrozen` inside `WindowFocusHoverSession`.
  - Guarded `AppPointerShape` (`reclaimAfterRealMovement()`, `pointerMoved(in:at:)`, `noteCardHover(...)`) against active hover suppression using shared `hasActiveTextDrag`, and extended `noteKeyboardOrControllerSuppressedHover()` to reset both `.grab` and `.iBeam` back to `.arrow` when not actively dragging text.
  - Enabled `settingsWindow.acceptsMouseMovedEvents = true` and triggered suppression in `AppDelegate.showSettings(_:)`.
- **Distinguished overlay closes vs `.playbackPage` transitions and top-level menus vs hover submenus** (`Shared/InterfaceLayerRegistry.swift`, `Shared/MenuGate.swift`, `Shared/MenuHighlightModel.swift`, `Shared/MenuSubmenu.swift`, `Shared/CardHighlightModel.swift`, `Shared/WorkbenchControls/WorkbenchDialogLayer.swift`):
  - Triggered `suppressHoverUntilMouseMoves()` when opening layers, menus (`registerOpenMenu`), stacked dialogs (`WorkbenchDialogLayer`), and entering or exiting `.playbackPage`, while calling `clearSuppressionForOverlayClose(recalculate: true)` BEFORE unfreezing when closing non-page overlays (`menuDidClose` when host layer is no longer frozen, stacked confirmation/dialog pop back to an underlying dialog).
  - Updated `MenuHighlightModel.open(..., initiallySuppressed:)` and `notePointerMoved(atScreenLocation:)` + `clearKeyboardSuppression()`, routed `.mouseMoved` wake checks through `MenuGate.route(event)` (skipping `client.notePointer` when sub-threshold), removed unconditional wake from `MenuSubmenu.notePointer`, and passed `initiallySuppressed: true` in `PlaybackStore`, `SettingsSubtitleCategory`, `SchemaWorkbenchSearchShell`, and `SubtitleTableCoordinator+Menus` (`rowActionDestinationHighlight`) so hover-opened submenus ignore stationary mount hover without clearing parent menu highlight or breaking `MenuSubmenuSafeArea`.
  - Synced `CardHighlightModel` suppression state with `PointerHoverScrollState.shared` across `init`, `reset`, and unfreeze, and cleared suppression before `guard !isFrozen` in `notePointerMoved()`.
- **Unified table, preview, scrollbar, Settings, navigation, and input suppression triggers and button press safety** (`Shared/HoverEffectModifier.swift`, `Shared/SubtitleTable/*`, `Shared/TableScrollbarPrimitive.swift`, `Playback/SubtitleFocus/PlaybackCollagePreview.swift`, `Playback/PlaybackStore.swift`, `Settings/SettingsSubtitleCategory.swift`, `Shared/WorkbenchControls/WorkbenchFormControls.swift`, `WorkbenchNativeTextFields.swift`, `WorkbenchTextAreaInput.swift`, `App/WorkbenchLayoutState.swift`, `Tasks/TaskQueueStore.swift`, `Shared/WorkbenchAccessibility.swift`, `Library/RemoteFolderDialogSharedViews.swift`, `App/AppCoordinator+RemoteFolderDialogs.swift`, `Search/WorkbenchSearchView.swift`, `Excerpt/WorkbenchExcerptTableView.swift`):
  - Prevented `PressableButtonStyle` from setting or leaving `isHovered = true` while hover is suppressed or cursor is hidden.
  - Subscribed `SubtitleTableView.Coordinator`, `PlaybackCollagePreview`, and `TableScrollbarOverlayView` to `.cueSeekerHoverSuppressed` and unified hover guards onto `isHoverSuppressed`.
  - Added `suppressHoverUntilMouseMoves()` on user text edits (strictly guarded against programmatic/external text assignments and `clearTextAndFocus()`), Workbench route/section/sidebar changes, Command Panel page navigation, Settings category/color-popover changes, remote folder step/connection navigation, Task tab changes, and SubtitleTable selection mode toggles (leaving in-playback episode switches on an already open `.playbackPage` untouched).
- **Updated and added unit tests** (`Tests/CueSeekerAppTests/PointerHoverGateTests.swift`, `MenuHighlightModelTests.swift`, `LibraryCardMenuPlacementTests.swift`, `PlaybackProgressScrubberThumbnailTests.swift`, `WorkbenchAccessibilityStep1Tests.swift`):
  - Added `wakeMovementThresholdRequiresHalfPointScreenDisplacement` (`PointerHoverGateTests`) and `initiallySuppressedMenuIgnoresStationaryAndSubThresholdMovesUntilRealDisplacement` (`MenuHighlightModelTests`).
  - Added `PointerHoverScrollState.shared.resetForTesting()` in `LibraryCardMenuPlacementTests` and simulated `notePointerMoved()` for test-driven mouse-move steps in `PlaybackProgressScrubberThumbnailTests` and `WorkbenchAccessibilityStep1Tests`.

## Verification

- `swift build --package-path apps/macos-native`: Build complete (`0.40s`).
- `swift test --package-path apps/macos-native --no-parallel` targeted suites after final edit:
  - `PlaybackProgressScrubberThumbnailTests|WorkbenchAccessibilityStep1Tests|TableScrollbarPrimitiveTests|TaskCardMenuTests|SubtitleTableRowActionMenuTests`: `54 passed` (`0` failed).
  - `CardHighlightModelTests|LibraryCardMenuPlacementTests|MenuHighlightModelTests|PointerHoverGateTests|PointerShapeModelTests`: `53 passed` (`0` failed).
  - `SubtitleTable|Settings`: `249 passed` (`0` failed).
  - `RemoteFolder|Dialog|Tooltip|Collage`: `110` run, `1` pre-existing failure (`TooltipTests.swift:652` standalone `TooltipCenter` `NSWindow.willCloseNotification` expectation; all `RemoteFolder`, `FileDetailDialog`, `PlaybackCollagePreview`, `WorkbenchSelectableTextTests` cases passed).
- Unfiltered `swift test --package-path apps/macos-native --no-parallel` still hits pre-existing unrelated failures (`AppLocalizationTests`, `CueGroupRefreshScopeIntegrationTests`, `LibraryFolderAdditionTests`, `LibraryFolderRemovalTests`, `PlaybackPageFocusIsolationTests`, `PlaybackPlaylistSourceTests`, `PlaybackReturnContextTests`, `PlaybackSubtitleFocusLayoutTests`, `PlaybackSubtitleFocusSessionStoreTests`) and stops stdout in `RecentPlaybackSessionRegressionTests` (`RecentPlaybackSessionRegressionTests` passes `10/10` standalone).
- Interactive UI/cursor/hover end-to-end verification remains with the user for acceptance.

## Incremental Update (Cross-Window Hover Clearing, Playback Overlay Symmetry, and Overlay Tab Suppression)

- **Added `clearsFrozenHover` full-window switch clearing on `PointerHoverScrollState.suppressHoverUntilMouseMoves(clearsFrozenHover:)` and `PointerHoverSession.clearHoverForInterfaceSwitch()`** (`Shared/PointerHover.swift`, `Shared/CardHighlightModel.swift`, `Shared/SubtitleTable/SubtitleTableCoordinator+SelectionAndInput.swift`, `Shared/SubtitleTable/SubtitleTableChromeAndHeaderViews.swift`, `Shared/TableScrollbarPrimitive.swift`):
  - Full-window switches clear `PointerHoverSession` (`deliveredIsHovered` / `deliveredLocation`, probe tracking flags, hand shape), `CardHighlightModel` (`hoveredID`, `rawHoveredID`, `hoveredActionButtonCardID`, `AppPointerShape.noteCardHover`), `SubtitleTableView.Coordinator` (`clearHover(ignoringFreeze: true)` + `headerView?.clearHoverState(ignoringFreeze: true)`), and `TableScrollbarOverlayView` (`hoveredAxis`) even if the layer is frozen or covered, while preserving existing freeze-retention for local menus, dialogs, and `Command Panel`.
- **Unified `Workbench` ↔ `Playback` and `Playback` ↔ `Playback Overlay` transitions** (`Shared/InterfaceLayerRegistry.swift`):
  - `InterfaceLayerRegistry.setOpen` treats both `.playbackPage` and `.playbackOverlay` as full-window switches: triggers `suppressHoverUntilMouseMoves(clearsFrozenHover: true)` before freezing on open (clearing lower-layer hover immediately) and triggers `suppressHoverUntilMouseMoves(clearsFrozenHover: true)` instead of `clearSuppressionForOverlayClose` on close (suppressing hover until real mouse displacement), while keeping `clearSuppressionForOverlayClose(recalculate: true)` for local `.commandPanel`, `.dialog`, and menu dismissals (including over `Playback Overlay`).
- **Added hover suppression on `Playback Overlay` module tab switching** (`Playback/SubtitleFocus/PlaybackSubtitleFocusSessionStore.swift`):
  - `PlaybackSubtitleFocusSessionStore.selectedModule` `didSet` now calls `PointerHoverScrollState.shared.suppressHoverUntilMouseMoves(clearsFrozenHover: true)` before `AppPointerShape.reevaluateAfterInterfaceChange()` when switching among `Current`, `Playlist`, and `Collage`.
- **Incremental Verification**:
  - `swift build --package-path apps/macos-native`: Build complete (`12.62s`).
  - `swift test --package-path apps/macos-native --no-parallel --filter "CardHighlightModelTests|InterfaceLayerFreezeTests|LibraryCardMenuPlacementTests|MenuHighlightModelTests|PointerHoverGateTests|PointerShapeModelTests"`: `60 passed` (`0` failed).
  - `swift test --package-path apps/macos-native --no-parallel --filter "PlaybackProgressScrubberThumbnailTests|PlaybackSubtitleFocusSessionStoreTests|TableScrollbarPrimitiveTests|SubtitleTableRowActionMenuTests|WorkbenchAccessibilityStep1Tests|PlaybackCollagePreview"`: `81/83` passed (`2` issues from the pre-existing `PlaybackSubtitleFocusSessionStoreTests.subtitleFocusOverlayCommitsKeyboardTargetQueuedBeforeMount()`).
  - `swift test --package-path apps/macos-native --no-parallel --filter "SubtitleTable|WorkbenchDialogLayerTests|WorkbenchAccessibilityStep4Tests"`: `214 passed` (`0` failed).
  - End-to-end UI/hover acceptance remains with the user.

## Incremental Update 2 (Playback Button Press Alignment, Collage Preview Hover Freeze/Suppression Guards, and Menu Owner Open Check)

- **Aligned `isPressed` hover transitions across Playback chrome and Cue Queue button styles** (`Playback/Chrome/PlaybackChromeIconButton.swift`, `Playback/Chrome/PlaybackChromeView.swift`, `Playback/Chrome/PlaybackCueQueueControlBar.swift`):
  - Updated `PlaybackChromeIconButtonStyle`, `PlaybackSpeedChromeButtonStyle`, `PlaybackCueQueueToggleButtonStyle`, and `PlaybackCueQueueStepperIconButtonStyle` to match `PressableButtonStyle`: pressing only sets `isHovered = true` when `!PointerHoverScrollState.shared.isHoverSuppressed && !AppCursorVisibility.isCursorHidden`, and releasing clears `isHovered = false` if suppressed, cursor is hidden, or the primary mouse button remains held.
- **Fixed `PlaybackCollagePreview` frozen-hover retention and click/exit suppression guards** (`Playback/SubtitleFocus/PlaybackCollagePreview.swift`):
  - Passed `@Environment(\.interfaceLayers)` into `PlaybackCollagePreviewScrollContainerView` so `hoverDidSuppress(_:)` queries `interfaceLayers?.isFrozen(.playbackOverlay)` synchronously instead of reading SwiftUI's frame-delayed `isInteractionEnabled`; frozen magnification stays intact when a local overlay (`Command Panel`, `Task Panel`, or menu) opens over `Playback Overlay`, clearing only when `clearsFrozenHover` is `true` or `.playbackOverlay` is unfrozen.
  - Guarded `release(atWindowPoint:)` with `!PointerHoverScrollState.shared.isHoverSuppressed && !AppCursorVisibility.isCursorHidden` before activating `setHoveredSegment(index)`, and unified `mouseExited(with:)` from `!isScrolling` to `!isHoverSuppressed`.
- **Tightened menu-close owner check and normalized overlay tab switching** (`Shared/InterfaceLayerRegistry.swift`, `Playback/SubtitleFocus/PlaybackSubtitleFocusSessionStore.swift`):
  - Guarded `InterfaceLayerRegistry.menuDidClose(ownedBy:)` with `isOpen(owner) && !isFrozen(owner)` so a full-window owner dismissed with an open menu cannot trigger `clearSuppressionForOverlayClose` on menu teardown.
  - Restored `PlaybackSubtitleFocusSessionStore.selectedModule` `didSet` to standard `suppressHoverUntilMouseMoves()` after cross-window full clear became self-contained in `InterfaceLayerRegistry`.
- **Incremental Verification 2**:
  - `swift build --package-path apps/macos-native`: Build complete (`6.79s`).
  - `swift test --package-path apps/macos-native --no-parallel --filter "CardHighlightModelTests|InterfaceLayerFreezeTests|MenuHighlightModelTests|MenuInputBarrierTests|PointerHoverGateTests|PointerShapeModelTests"`: `68 passed` (`0` failed, `0.890s`).
  - `swift test --package-path apps/macos-native --no-parallel --filter "PlaybackCollagePreview|PlaybackProgressScrubberThumbnailTests|PlaybackCueQueue|WorkbenchAccessibilityStep4Tests"`: `26 passed` (`0` failed, `1.141s`).
  - End-to-end UI/hover acceptance remains with the user.

## Incremental Update 3 (Workbench Surface Presentation Suppression Lock, Press-Hold Hover Freeze, and Card Hand Lifecycle Closure)

- **Locked Workbench route-switch hover suppression across full surface presentation** (`Shared/PointerHover.swift`, `App/WorkbenchLayoutState.swift`, `Workbench/WorkbenchWorkspaceView.swift`):
  - Added `beginWorkbenchTransitionSuppression()` / `completeWorkbenchTransitionSuppression(through:)` and `isAwaitingWorkbenchTransitionPresentation` on `PointerHoverScrollState`, driven by `WorkbenchRouteState.transitionRevision` and completed on the post-render turn after `WorkbenchWorkspaceView` actually commits the target surface (both immediate swaps and async `prepareWorkbenchSurfaceForPresentation` prewarms).
  - While a Workbench surface switch is awaiting presentation, incoming window `.mouseMoved` events refresh `suppressedOriginScreenLocation` without waking the outgoing page, preventing post-click wrist inertia from re-activating outgoing Level 1 cards or bouncing cursor shape (`Arrow -> Grab -> Arrow`).
- **Aligned mouse press-drag-release with `UI Interaction Rules.md` §5.1** (`Shared/CueSeekerMainWindow.swift`, `Shared/PointerHover.swift`, `Shared/AppPointerShape.swift`):
  - Stopped `.leftMouseDragged` / `.rightMouseDragged` from waking `PointerHoverScrollState` or re-evaluating non-text-drag pointer shapes (`AppPointerShape.hasActiveTextDrag`), and ignored raw hover transitions on non-location `PointerHoverSession`s while primary/secondary mouse buttons remain pressed in a window.
  - Added `PointerHoverScrollState.syncAfterMouseButtonReleased(atScreenLocation:)` on mouse button release (including AppKit modal control tracking loops) to reconcile exited/entered hover probes and pointer shape once at the release point when not suppressed.
- **Closed card hand-cursor registration lifecycle** (`Shared/CardHighlightModel.swift`, `Shared/PointerHover.swift`):
  - Unregistered replaced `rawHoveredID` entries in `CardHighlightModel.noteHover` / `notePress` and silently cleared card hover registrations (`followsPointer: false`) when `CardHighlightModel` or `PointerHoverModifier` unmounts or deallocates.
- **Incremental Verification 3**:
  - `swift build --package-path apps/macos-native`: Build complete (`14.48s`).
  - `swift test --package-path apps/macos-native --no-parallel --filter "PointerShapeModelTests|CardHighlightModelTests|MenuHighlightModelTests|InterfaceLayerFreezeTests"`: `38 passed` (`0` failed, `0.256s`).
  - `swift test --package-path apps/macos-native --no-parallel --filter "WorkbenchAccessibilityStep1Tests"`: `10 passed` (`0` failed, `0.795s`).
  - End-to-end interactive UI/cursor acceptance remains with the user.
