# Settings leaves the Sidebar for the topbar, and its button stays lit while the window is open

Human-owned documents:

- `docs/human/requirements/20260908-UI-Settings Entry Moves To Topbar.md`

## Why

Settings sat at the bottom of the Sidebar, which meant it disappeared entirely whenever the Sidebar was collapsed — the only way back in was the system menu's ⌘,. The topbar's trailing region already holds what belongs to the App rather than to the page below it, and it is visible in every Workbench state, so that is where an App-level entry belongs. Moving it there also lets the button say whether the Settings window is currently open, which the Sidebar item never did.

The requirement also names a defect on the path that opens the window. Asking a window that is sitting in the Dock to come to the front draws it at its own place for a frame before the system notices it is still minimised, and the restore animation then plays from the Dock — so the user saw a settings window flash in the middle of the screen and then fly out of the Dock. The button's new lit state makes that path far more common: it stays lit while the window is minimised, so the user sees a lit button and clicks it.

## What changed

The Sidebar loses its Settings item and the spacer that pushed it to the bottom; the topbar's trailing region becomes a pair.

- `AppTopBar` now puts `TaskEntryButton` and a new Settings entry in one `HStack` spaced by `--spacing-1`. The Settings entry is a `WorkbenchIconButton` with `gearshape`, no badge, `focusable(false)`, and the accessibility identifier `topbar-settings-button`. Its action is the same notification the Sidebar item posted.
- `WorkbenchLayoutState` gained `isSettingsWindowOpen`. It follows the window's open and closed edges rather than its visibility, so minimising to the Dock keeps the button lit. It lives beside `isSidebarVisible` and `isAppFullscreen` rather than in a store of its own: the flag is written at most a few times per session, so there was nothing to gain from narrowing its invalidation scope, and a new observable type would have been an entity standing in for one boolean.
- `AppDelegate` sets that flag when it shows the window and clears it from the window's own `willCloseNotification`, deminiaturizes instead of ordering front when the window is in the Dock, and titles the window with the new key.
- `AppSidebarSettingsItem` and `AppSidebarItemButtonStyle` had no other caller once the Sidebar item went, so both are gone.
- `topbar.settings` is new in all three languages. The window title moved to `settings.window.title`, and `sidebar.settings` retired: after this change it would have named nothing in a sidebar, which is the confusion the owner asked to avoid.

Files:

- `apps/macos-native/Sources/CueSeekerApp/Workbench/ContentView.swift`
- `apps/macos-native/Sources/CueSeekerApp/App/WorkbenchLayoutState.swift`
- `apps/macos-native/Sources/CueSeekerApp/App/AppDelegate.swift`
- `apps/macos-native/Sources/CueSeekerApp/Resources/en.lproj/Localizable.strings`
- `apps/macos-native/Sources/CueSeekerApp/Resources/zh-Hans.lproj/Localizable.strings`
- `apps/macos-native/Sources/CueSeekerApp/Resources/zh-Hant.lproj/Localizable.strings`

## Verification

Debug E2E controller, main window 1445×821, light appearance. The Settings button's centre is 40pt from the window's trailing edge and the Task button's is 76pt, both 27pt down — that is the 24pt content padding, two 32pt boxes and the 4pt gap between them.

- At rest the Sidebar shows five navigation items and nothing below them; the topbar's trailing corner shows the task icon with the gear to its right, both borderless and unfilled.
- Clicking the gear opens the Settings window — the controller reports a second window titled `Settings`, 760×520 — and the gear paints the Open fill while the task button beside it does not.
- Clicking the Settings window's close button puts the gear back to its bare surface.
- Reopening, then minimising the Settings window to the Dock, leaves the gear lit with no Settings window in the scene. Clicking the lit gear brings the window back out of the Dock.

`swift test`: 1143 tests, 26 issues. The same suite on this commit's parent, with the code changes stashed, produced 30 issues across the same families — native playback timeline and audio, cue group refresh scope, application persistence, library folder removal, and the Debug E2E window-geometry cases. The set varies between runs; `CueGroupRefreshScopeIntegrationTests` passes in isolation and fails under the full run's load. Nothing in the difference touches the Sidebar, the topbar or Settings, and no test read either surface before this change.

## Known limits

The requirement's clause about the centred flash is a manual acceptance step, agreed with the owner. The flash lasts one or two frames, and the controller's capture is a still taken after the command settles, so it cannot prove the frames in between. The controller does show that the restore now comes out of the Dock rather than being ordered front, which is the mechanism the clause is about, but the owner has to confirm the absence of the flash by eye.

Hover on the new button is not automatable for the reason `docs/engineering/08_end_to_end_testing.md` §1.1 records: a synthesized `mouseMove` never reaches SwiftUI's `.onHover`. The Open state is the same fill as hover, so the token itself is proven; the hover trigger is not.

The coordinates above were derived for this run from the layout tokens and are not accepted procedure coordinates.

`UI Design System.md` still lists the Sidebar's Settings Region, its flexible spacer, and the `Sidebar Item / Action` variant, and its App Topbar Layout still names Task Entry alone. Per the owner's instruction the design documents are updated after this round of UI tuning is accepted, so that gap is expected until then.
