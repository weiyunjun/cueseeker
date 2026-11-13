# Dialog Transition Motion And System Sheet Scrim Sync

- Date: 2026-11-14
- Related Requirement: `docs/human/requirements/20261114-UI-Dialog Transition Motion And System Sheet Scrim Sync.md`
- Scope: `CueSeekerApp`, `CueSeekerAppTests`

## Changes Made

- **Replaced CPU per-frame transition with tokenized GPU curves and Reduce Motion support**:
  - Updated `WorkbenchDialogMotion` in `apps/macos-native/Sources/CueSeekerApp/Shared/WorkbenchControls/WorkbenchDialogLayer.swift` to centralize the dialog motion tokens (`--duration-dialog-motion: 0.27`, `--duration-dialog-fade-in: 0.12`, `--duration-dialog-fade-out: 0.22`, `--duration-dialog-reduce-motion: 0.18`, `--distance-dialog-motion: 34`, `--easing-dialog-enter`, `--easing-dialog-exit`, `--easing-dialog-fade-in`, `--easing-dialog-fade-out`, `--easing-dialog-scrim`) along with `UnitBezier.animation(duration:)`, `scrimAnimation(reducesMotion:)`, `dialogTransactionAnimation(reducesMotion:)`, and `showsScrim(hasOpenDialogs:isSystemSheetAttached:)`.
  - Replaced the per-frame `Animatable` modifier (`WorkbenchDialogMotionEffect`) with compositor-backed `AnyTransition.workbenchDialog` combining `WorkbenchDialogSlideModifier` (vertical translation skipped under Reduce Motion) and separate fade-in / fade-out timing curves, plus a pure fade fallback when `accessibilityDisplayShouldReduceMotion` or `@Environment(\.accessibilityReduceMotion)` is enabled.
- **Eliminated end-of-transition flash and decoupled Scrim, titlebar band, and dialog composition**:
  - Generalized `WorkbenchExteriorClipShape` in `apps/macos-native/Sources/CueSeekerApp/Shared/WorkbenchRedesignTokens.swift` with configurable `cornerStyle` (default `.continuous`), and applied even-odd exterior clipping (`cornerStyle: .circular`) to `dialogOutline` inside `WorkbenchDialogChrome`.
  - Moved `.compositingGroup()` directly onto `WorkbenchDialogChrome` (after `.shadowToken(...)`) so the offscreen backing layer persists across entrance, rest, and exit without switching composition modes at transition end.
  - Replaced conditional scrim insertion inside `WorkbenchDialogLayer` with a persistent `WorkbenchRedesignColors.dialogScrim` layer at `zIndex(0)` driven smoothly by `showsScrim`, separated `TitlebarBackgroundView` into an un-faded top band at `zIndex(0.5)`, isolated `.animation(dialogTransactionAnimation, value: dialogIDs)` onto `ZStack { dialogs() }` at `zIndex(1)`, and animated `WorkbenchDialogChrome`'s `isCovered` veil using `WorkbenchDialogMotion.scrimAnimation`.
  - Enabled `wantsLayer = true` on embedded AppKit subviews (`WorkbenchSelectableTextNSView`, `WorkbenchNativeSingleLineTextField`, `WorkbenchSingleLineContainerOverlayView`, `FocusedTextInputCompanionView`, `WorkbenchNativeSecureTextField`, `WindowKeyDownMonitor.MonitoringView`, and `SettingsWindowCloseButtonSyncView.SyncView`).
- **Synchronized custom Scrim restoration with macOS system sheet dismissal**:
  - Added `weak var interfaceLayers: InterfaceLayerRegistry?` on `CueSeekerWindow` (`CueSeekerMainWindow.swift`), wired both main window (`appState.interfaceLayers`) and Settings window (`settingsInterfaceLayers`) in `AppDelegate.swift`, and updated `windowWillBeginSheet` / `windowDidEndSheet` to route through the target window's registry.
  - Added `SystemSheetPresentation` (`presentFilePanel`, `presentAlert`, `releaseScrimOnCompletion`) in `AppWindowControls.swift` and updated all `NSOpenPanel` and `NSAlert` sheet call sites (`AppCoordinator+AnkiExport.swift`, `LibraryStore+Execution.swift`, `ExcerptStore+Execution.swift`, `WorkbenchFileView.swift`) so `isSystemSheetAttached` clears immediately when the active sheet's completion handler executes (`activeSheetCount <= 1`), aligning custom scrim fade-in with macOS sheet dismissal.
- **Added automated unit tests**:
  - Added `dialogMotionTokensCurvesAndExteriorClipMatchSpec` and `systemSheetCompletionRestoresScrimEarlyAndPreservesDialogLayerState` in `apps/macos-native/Tests/CueSeekerAppTests/WorkbenchDialogLayerTests.swift`.

## Verification

- `swift build` in `apps/macos-native`: Build complete (`0.32s`), zero warnings in modified files.
- `swift test --no-parallel` targeted suites in `apps/macos-native` (0 failures across all runs):
  - `WorkbenchDialogLayerTests` (`dialogLayerIsOpenWhile...`, `dialogMotionTokensCurvesAndExteriorClipMatchSpec`, `systemSheetCompletionRestoresScrimEarlyAndPreservesDialogLayerState`): `3 passed`
  - `WorkbenchDialogFitTests|SettingsAndDialogsStaticTextSelectionTests|WorkbenchSelectableTextTests`: `27 passed`
  - `WorkbenchInputControlsTests`: `12 passed`
  - `WorkbenchAccessibilityStep1Tests|WorkbenchAccessibilityStep2Tests|WorkbenchAccessibilityStep3Tests|WorkbenchAccessibilityStep4Tests`: `26 passed`
  - `InterfaceLayerFreezeTests|FileDetailDialogTests|PointerHoverGateTests|AnkiPackageExporterTests`: `42 passed`
  - `DebugInteractionLatencyProbeTests` (`7 passed`) + `ExcerptListEditorTests` (`4 passed`)
  - `SettingsStorePlaybackTests` (`11 passed`)
- Visual/interactive E2E acceptance (in-window dialog transitions, flash elimination, and system sheet scrim continuity) remains with the user.
