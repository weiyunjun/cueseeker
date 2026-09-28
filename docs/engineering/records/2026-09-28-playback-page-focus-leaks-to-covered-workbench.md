# Playback page focus leaks to covered workbench

Human-owned documents:

- `docs/human/requirements/20260928-Bug-Playback Page Focus Leaks To Covered Workbench.md`

## Why

When the Playback page was displayed:
1. `CueSeekerMainWindow` previously checked only dialog modality (`isBehindDialog`, active when `dialogSize != nil`) and open menu lock (`isFocusLocked`).
2. When the user pressed Tab / Shift-Tab during playback (or accidental Tab via Bluetooth delay on `Cmd+Tab`), AppKit's key view loop selected the only editable key view in the window: `WorkbenchSearchField` in the covered Workbench layer.
3. Once focused, `AppCoordinator.isEditableTextInputFocused()` returned `true` without checking layer visibility or whether the view was covered, which caused `handlePlaybackKeyDown` to return `false` and delegate playback shortcuts (`A`, `D`, `P`, `Space`) to the covered search input field.
4. Game controller `rightShoulder` also triggered Tab keystrokes that leaked into the underlying search field when outside overlay sessions, while Shift-Tab in `PlaybackSubtitleFocusOverlay` did not navigate back to the previous module.
5. In addition, `SearchView.swift`'s `mainContent` container only had `allowsHitTesting(!showsPlaybackRoute)` but lacked `.disabled(showsPlaybackRoute)` and `.accessibilityHidden(showsPlaybackRoute)`.

## What changed

- **Window Focus and Key View Layer Isolation (`CueSeekerMainWindow.swift`)**:
  - Enforced `isUncovered(view)` on all `makeFirstResponder` calls, rejecting any view that is covered by a higher interface layer.
  - Replaced dialog-only key view cycling with universal `selectUncoveredKeyView(from:step:)` for both `selectKeyView(following:)` and `selectKeyView(preceding:)`, guaranteeing that Tab and Shift-Tab pass over any views covered by higher layers.
  - Made `isUncovered(_ view: NSView)` internal so other coordinator modules can query view coverage.
- **SwiftUI Container-Level Isolation (`SearchView.swift`)**:
  - Added `.disabled(showsPlaybackRoute)` and `.accessibilityHidden(showsPlaybackRoute)` to `mainContent`, completely deactivating underlying Workbench controls and removing them from accessibility navigation while playback is active.
- **Layer-Scoped Text Input Detection and Focus Cleansing (`AppCoordinator+Playback.swift`)**:
  - Updated `isEditableTextInputFocused()` and `hasMarkedTextInFocusedEditor()` to verify that the active first responder is `isUncovered`. Orphaned or covered focus returns `false` so playback shortcuts are never suppressed.
  - In `handlePlaybackKeyDown`, if the first responder is found to be covered, it immediately drops the orphaned focus (`makeFirstResponder(nil)`).
  - In `handlePlaybackKeyDown`, updated keyCode 48 (Tab) handling in `subtitleFocusSession` to support Shift-Tab to select the previous module (`selectPreviousModule()`), while bare Tab selects the next module (`selectNextModule()`).
- **Controller Shoulder Alignment (`AppCoordinator+ControllerInput.swift`)**:
  - Updated `rightShoulder` in `handlePlaybackControllerInput` to symmetrically invoke `subtitleFocusSession.selectNextModule()` when in an overlay session.
- **Interface Layer Open Focus Yield (`InterfaceLayerRegistry.swift`)**:
  - Updated `setOpen` so opening `.playbackPage` calls `givePageFocusUp()` to drop page focus on transition.
- **Tests**:
  - Added `PlaybackPageFocusIsolationTests.swift` covering:
    - `windowMakeFirstResponderRefusesCoveredViewAndAcceptsUncoveredView`
    - `windowKeyViewSelectionSkipsCoveredViews`
    - `coveredTextInputDoesNotSuppressPlaybackShortcuts`
    - `openingPlaybackPageCoversWorkbenchPage`
    - `playbackKeyDownDropsOrphanedCoveredFirstResponder`
  - Added Shift-Tab test assertions to `playbackOverlayTabCyclesModulesAndIgnoresKeyRepeat` in `PlaybackSubtitleFocusKeyboardActionTests.swift`.

Files:

- `apps/macos-native/Sources/CueSeekerApp/App/AppCoordinator+ControllerInput.swift`
- `apps/macos-native/Sources/CueSeekerApp/App/AppCoordinator+Playback.swift`
- `apps/macos-native/Sources/CueSeekerApp/Search/SearchView.swift`
- `apps/macos-native/Sources/CueSeekerApp/Shared/CueSeekerMainWindow.swift`
- `apps/macos-native/Sources/CueSeekerApp/Shared/InterfaceLayerRegistry.swift`
- `apps/macos-native/Tests/CueSeekerAppTests/PlaybackPageFocusIsolationTests.swift`
- `apps/macos-native/Tests/CueSeekerAppTests/PlaybackSubtitleFocusKeyboardActionTests.swift`

## Verification

- Built macOS native app cleanly: `swift build --package-path apps/macos-native` (0 errors, 0 warnings).
- Executed `PlaybackPageFocusIsolationTests`: all 5 tests passed.
- Executed `PlaybackSubtitleFocusKeyboardActionTests`: Tab and Shift-Tab cycle tests passed.
- Executed `PlaybackNormalShortcutTests`: all 16 tests passed.
- Executed `InterfaceLayerFreezeTests`: all 7 tests passed.
- Executed `WorkbenchDialogLayerTests`: all tests passed.
