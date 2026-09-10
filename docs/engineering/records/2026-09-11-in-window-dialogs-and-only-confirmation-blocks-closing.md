# Dialogs are drawn inside the main window, and only Confirmation keeps the App open

Human-owned documents:

- `docs/human/requirements/20260911-UI-In-Window Dialogs And Only Confirmation Blocks Closing.md`
- `docs/human/design/UI Application Rules.md`
- `docs/human/design/UI Design System.md`

## Why

Edit Cover, the Shiori List Editor, Rename, the Task panel and Confirmation were system sheets. A sheet holds its window: while one is attached, AppKit disables the red light and refuses Quit. The requirement keeps that hold for Confirmation only.

AppKit offers no public way to keep a sheet and free the red light: it disables the button through an internal flag and sets it again whenever the App is reactivated. The owner chose to stop using sheets for the dialogs rather than fight that flag. With no sheet attached, the window's controls and the App's quit are the App's to decide.

## What changed

**One dialog layer at the window root.** The five `.sheet` presentations are gone. The window root draws the open dialogs above the page and the toasts: a veil over the whole window, the dialogs centred in it, and a Confirmation above the Task panel when the panel raises one. The Task panel now raises its confirmations through the App-level confirmation holder like every page does, so the layer can stack them.

**The sheet's look, measured and redrawn.** Everything the sheet contributed was measured from the old build on macOS 15.5, light and dark, and drawn by the layer instead:

- Veil: a flat colour over everything, fitted to within one level per channel. `--color-dialog-scrim` Light `#AAAAAA`, Dark `#161819`, `--opacity-dialog-scrim` 60%. A dialog with a Confirmation above it takes the same veil clipped to itself; the page stays veiled once, as the nested sheet left it.
- Corner: the sheet clipped every dialog to a 10pt circular corner, over the dialogs' own 8pt ones. `--radius-dialog` 10px.
- Edge: a one-device-pixel line just outside the corner, black at 19% light and 94% dark; in dark a 1pt white 20% line just inside it. The dialog's own border and background are untouched.
- Shadow: one layer, `0 18px 40px`, black at 25% light and 43% dark (`--shadow-dialog`).
- Size and place: the sheet window took the dialog's size rounded up to whole points and centred it in the window with its origin rounded to whole points; the layer does the same. The sub-point strip that rounding leaves is filled with the dialog background.
- Motion: frame-by-frame recordings of the sheet gave a 0.27s linear veil fade; the dialog slides 34pt into place on `cubic-bezier(0.4, 0.2, 0.58, 1)` and is opaque after 0.12s, and leaves along the same curve backwards while fading for the whole 0.27s (`--duration-dialog-motion`, `--duration-dialog-fade-in`, `--distance-dialog-motion`, `--easing-dialog-motion`).

These are new tokens. They live in code now, marked with their names, and go into `UI Design System.md` once the owner accepts the look.

**What the sheet did for input, done in the window.**

- The veil takes every click, right-click and wheel event over the page, and the window controls stay above it. Its band along the top, at the page's top-bar height, moves the window on a drag and zooms it on a double-click, through the same view the top bars use.
- The keyboard stays in the top dialog. The main window refuses focus to any view outside the dialog, and Tab and Shift-Tab walk the key-view loop past everything the veil covers, so they go round the dialog's own fields as they went round its window.
- The player's shortcuts, which only ever saw the main window's keys, now stand down while a dialog is open, and so does game-controller input.
- The player treated a sheet as a loss of focus (the main window stopped being key): its Player UI hid and it stopped hiding the cursor. It now reads an open dialog the same way.
- The Command Panel's result reel took the wheel over its whole rectangle, whatever lay on top. It now lets the wheel through while a dialog covers it.
- Rename was missing from the dialog layer's open state; the page under it is now frozen like under the other dialogs.
- Esc closed a Confirmation by dismissing its sheet, not through a button. The Confirmation now closes on Esc itself, next to the Space it already handled.
- A file panel is still a system sheet. It now attaches to the main window, and the system dims the whole window under it, so the layer's veil fades out while one is attached and the page stays dimmed once.

**Closing.** The red light is disabled while a Confirmation is open and enabled otherwise, through the button's public `isEnabled`, which nothing resets without a sheet. `applicationShouldTerminate` refuses Cmd+Q and the Dock's Quit while a Confirmation is open, unless the quit event carries a system reason (shut down, restart, log out, quit all), which it lets through; the confirmed action then never runs. With any other dialog on top, nothing holds the window or the App.

Files:

- `apps/macos-native/Sources/CueSeekerApp/Shared/WorkbenchControls/WorkbenchDialogLayer.swift` (new)
- `apps/macos-native/Sources/CueSeekerApp/Workbench/ContentView.swift`
- `apps/macos-native/Sources/CueSeekerApp/Tasks/TaskPanel.swift`
- `apps/macos-native/Sources/CueSeekerApp/Shared/WorkbenchControls/WorkbenchConfirmationDialog.swift`
- `apps/macos-native/Sources/CueSeekerApp/Shared/WorkbenchControls/WorkbenchControls.swift`
- `apps/macos-native/Sources/CueSeekerApp/Shared/WorkbenchRedesignTokens.swift`
- `apps/macos-native/Sources/CueSeekerApp/Shared/InterfaceLayerRegistry.swift`
- `apps/macos-native/Sources/CueSeekerApp/Shared/CueSeekerMainWindow.swift`
- `apps/macos-native/Sources/CueSeekerApp/Shared/AppWindowControls.swift`
- `apps/macos-native/Sources/CueSeekerApp/App/AppDelegate.swift`
- `apps/macos-native/Sources/CueSeekerApp/App/AppCoordinator.swift`
- `apps/macos-native/Sources/CueSeekerApp/Playback/PlaybackChromeVisibilityModel.swift`
- `apps/macos-native/Sources/CueSeekerApp/Playback/PlaybackVideoStage.swift`
- `apps/macos-native/Sources/CueSeekerApp/Playback/SubtitleFocus/PlaybackCommandPanel.swift`

## Verification

macOS 15.5 only. Nothing branches on the system version; macOS 13 and 14 were not run.

**Look.** Before any code changed, the old build was captured with the Debug E2E controller: all five dialogs, the Task panel with a Confirmation over it, and Edit Cover with its file panel, in light and dark (dark through the `-appAppearanceMode` launch argument, so the owner's setting was never written). The new build was captured at the same places and compared pixel by pixel. Inside every dialog the two builds are identical to within 3 levels. Over the page, the veil differs by less than one level on average, the shadow by one to one and a half. What remains is at the pixel level: the window frame's own 1pt highlight along the top edge sits above the page, so the veil cannot reach it and it stays a little brighter; the corners' antialiasing; and a faint second pixel outside the edge in light that was not drawn. With a file panel open, the page, Edit Cover and the panel match the old brightness.

**Motion.** The system sheet's motion was recorded frame by frame in a standalone probe with ScreenCaptureKit, and the curve above fits it to within half a pixel. The layer's motion was not recorded; the owner compares it by eye.

**Behaviour, in the new build through the E2E controller:**

- Edit Cover, the Shiori List Editor, Rename and the Task panel each leave the red light coloured; a click on it closes the App. Cmd+Q closes it with Edit Cover or the Task panel open.
- A Confirmation greys the red light; a click on it and Cmd+Q leave the App and the Confirmation open. Esc closes it, and Enter and Space each run Cancel; the folder it asked about was still there.
- Over the Task panel, a Confirmation greys the red light and holds Cmd+Q; after Esc the panel is back, the light is coloured again, and a click on it closes the App.
- With Edit Cover open, wheel events over the page and over the sidebar, a click on the sidebar, a right-click on a card and a click on the sidebar toggle changed nothing on screen.
- Rename opens with its name selected; Tab and Shift-Tab reselect it. The list editor opens with nothing focused; Tab goes from List Name to Description; Shift-Tab inside Description stays there. A pristine build of the previous code, expanded with `git archive` into a scratch directory, did exactly the same.

Left to the owner, because the controller cannot drive them: the Dock's Quit, logging out with a Confirmation open, dragging and double-clicking the top band, hover under the veil, keys and the pointer while the Shiori List Editor is open over the playback page, and Cmd+Q while a file panel is open (the panel's content belongs to a system process the controller cannot reach).

**Differences that remain by design:**

- Over the Task panel, the old nested sheet also greyed the yellow and green lights. Now they stay available, as with a Confirmation over the page, and as the requirement keeps them.
- A file panel over Edit Cover or the list editor now attaches to the main window. The red light greys while it is open, as the system does for any sheet, and the yellow and green lights stay available.
- A dialog larger than the window is now cut by the window's edge. A sheet was a window of its own and reached past it: in the old build, narrowing the window under Edit Cover pushed the sheet off the display.

`swift build`: clean. `swift test`: 1176 tests, compared against the pristine copy with `CUESEEKER_MEDIA_RUNTIME_ROOT` pointed at the repository's runtime, so the working tree was never reverted. Both fail 15, 14 of them shared: native playback timeline, audio and presentation, the auto-pause boundary, the refresh-scope waits, library folder removal under load, and the two Debug E2E scene-geometry cases. The one on each side that differs is a library folder removal test, and that suite passes 8 of 8 alone. An earlier run of this tree had swapped a different pair, `sharedPersistenceMigrationCopiesLegacyValuesWithoutOverwritingSharedValues` for `searchFacetSelectionDoesNotRefreshGlobalOrInactiveSurfaces`; both pass alone. The layer, menu, task, shortcut, list editor, rename and confirmation suites pass together, 85 tests.
