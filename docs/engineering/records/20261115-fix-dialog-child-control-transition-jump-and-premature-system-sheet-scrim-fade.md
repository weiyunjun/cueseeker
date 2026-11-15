# 2026-11-15 Fix Dialog Child Control Transition Jump and Premature System Sheet Scrim Fade

- **Date**: 2026-11-15
- **Covering Requirement**: `docs/human/requirements/20261115-UI-Fix Dialog Child Control Transition Jump And Premature System Sheet Scrim Fade.md`
- **Related Design**: `docs/human/design/ui/UI Tokens.md`, `docs/human/design/ui/UI Components - Domain.md`, `docs/human/design/ui/UI Interaction Rules.md`
- **Branch / Baseline**: `main` (initial requirement commit `6ba187a` -> initial implementation `9170329` -> updated requirement `73ebd69`)
- **Scope**: `CueSeekerApp`, `CueSeekerAppTests`

## Changes Made

1. **Restore a single `Animatable` dialog transition modifier to eliminate mid-transition child control jumps (`WorkbenchDialogLayer.swift`, committed in `9170329` and retained unchanged)**:
   - Added `TransitionFrame` and pure computation helper `transitionFrame(progress:isEntering:reducesMotion:)` on `WorkbenchDialogMotion` in `apps/macos-native/Sources/CueSeekerApp/Shared/WorkbenchControls/WorkbenchDialogLayer.swift`:
     - Standard motion (`reducesMotion == false`): computes synchronized per-frame whole-dialog `opacity` and `offsetY` from linear `progress` (`0 -> 1` entering, `1 -> 0` exiting) via `UnitBezier.value(at:)` and `WorkbenchDialogMotion` tokens — entering uses `enterEasing` (`0.27s`) for vertical offset and `fadeInDuration` (`0.12s`) + `fadeInEasing` for opacity; exiting uses `elapsed = 1 - clampedProgress` with `exitEasing` (`0.27s`) for offset and `fadeOutDuration` (`0.22s`) + `fadeOutEasing` for opacity.
     - Reduce Motion (honoring both the parameter and `@Environment(\.accessibilityReduceMotion)`): keeps `offsetY = 0` and interpolates opacity linearly in place (`0.18s`).
   - Restored `AnyTransition.workbenchDialog` as a single `Animatable` progress modifier `WorkbenchDialogMotionEffect` (`progress: Double`, `isEntering: Bool`, `reducesMotion: Bool` + `@Environment(\.accessibilityReduceMotion)`) driven linearly by `WorkbenchDialogLayer.dialogTransactionAnimation` without nested non-linear `.animation(...)` wrappers, retaining `DebugInteractionLatencyProbe.recordDialogAnimationFrame` and removing unused `enterAnimation` / `exitAnimation` / `fadeInAnimation` / `fadeOutAnimation` and `WorkbenchDialogSlideModifier`.
   - Kept persistent `.compositingGroup()` on `WorkbenchDialogChrome` and existing `wantsLayer = true` on `NSView` hosts so final frames do not flicker.

2. **Remove redundant system-sheet scrim-hiding state to eliminate bright flashes on open and dismiss (simplified per updated requirement `73ebd69`)**:
   - Interactive acceptance of `9170329` showed that because `NSOpenPanel` runs out-of-process, `windowWillBeginSheet` fires before the remote panel renders its backdrop while `completionHandler` / `windowDidEndSheet` fires after dismiss animation completes, causing a bright-then-dark flash at both ends when toggling the app scrim off and back on.
   - `WorkbenchDialogLayer.swift`: Removed `@Environment(\.isSystemSheetAttached)` and `WorkbenchDialogMotion.showsScrim(hasOpenDialogs:isSystemSheetAttached:)`, driving `dialogScrim` visibility solely from `hasOpenDialogs` (`!dialogIDs.isEmpty`) so the app scrim stays continuously visible beneath stacked native system sheets.
   - `InterfaceLayerRegistry.swift`: Removed `isSystemSheetAttached`, `setSystemSheetAttached(_:)`, `IsSystemSheetAttachedKey`, `EnvironmentValues.isSystemSheetAttached`, and the `InterfaceLayerCoverageBridge` environment injection.
   - `AppDelegate.swift` and `CueSeekerMainWindow.swift`: Removed `windowWillBeginSheet`, `windowDidEndSheet`, `updateSystemSheetAttachment`, and unused `CueSeekerWindow.interfaceLayers` wiring.
   - `AppWindowControls.swift`: Removed `SystemSheetPresentation.releaseScrimOnCompletion` and `interfaceLayers` / `window.sheets.count` reads, keeping a minimal `present(window, completionHandler)` forwarding helper.

3. **Update pure-logic unit tests (`WorkbenchDialogLayerTests.swift`)**:
   - Retained dialog open/close state, curve token, outer clip, and `dialogTransitionFrameComputesSynchronizedOpacityAndOffset` pure-logic tests; removed obsolete `showsScrim` assertions, `systemSheetCompletionRestoresScrimEarlyAndPreservesDialogLayerState`, and helper `isSystemSheetAttached` arguments without synthetic windows or production test backdoors.

## Verification

Executed after the final code and test edits:

1. **Build verification**:
   - `swift build --package-path apps/macos-native`: `Build complete! (13.97s)`, zero warnings or errors in modified files.
2. **Targeted headless pure-logic tests (filtered, zero window popups)**:
   - `swift test --package-path apps/macos-native --no-parallel --filter "WorkbenchDialogLayerTests|InterfaceLayerFreezeTests|WorkbenchDialogFitTests"`
   - Result: `13` Swift Testing cases passed (`0` failed) across `InterfaceLayerFreezeTests`, `WorkbenchDialogFitTests`, and `WorkbenchDialogLayerTests`.
3. **End-to-end acceptance**:
   - Zero jump on dialog footer buttons and top-right `✕` close control plus mid-transition hover/autofocus stability were accepted at `9170329`; continuous scrim behavior when presenting and cancelling/confirming system file panels (`Edit Cover`, `Export to Anki`) or system alerts over open dialogs, as well as adding local folders on the `File` page without an open dialog, remained with the user for interactive acceptance prior to syncing `docs/human/design/`.
