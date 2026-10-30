# 2026-10-31 Sidebar Overlay, Escape IME, Dialog Return, and Settings Native Controls Cleanup

## Requirement Reference
- `docs/human/requirements/20261031-UI-Sidebar Overlay Escape IME Dialog Return And Settings Native Controls Cleanup.md`

## Summary of Changes
1. **Overlay Sidebar Mouse-Leave Auto-Collapse Removal (`ContentView.swift`, `AppTopbarLayout.swift`, `WorkbenchLayoutState.swift`)**:
   - Removed `OverlaySidebarPointerMonitorView`, `OverlaySidebarPointerMonitorNSView`, and `collapseOverlaySidebarOnMouseLeaveIfNeeded` so that in compact windows (`< 840pt`), an expanded overlay sidebar no longer auto-collapses when the pointer moves outside its `240pt` bounds, collapsing only when clicking the topbar `Sidebar Toggle` button (or when window width crosses below threshold).
2. **Gamepad Hiding Player UI Rule Removal (`AppCoordinator+ControllerInput.swift`, `PlaybackChromeVisibilityModel.swift`, `PlaybackStore.swift`, `PlaybackVideoStage.swift`)**:
   - Removed `PlaybackStore.requestPointerHide()`, `pointerHideRequests`, `pointerHideRequestGeneration`, and `PlaybackChromeVisibilityModel.pointerHideRequested()` so gamepad input in Playback (windowed or fullscreen) behaves like keyboard input without hiding the Player UI or pointer cursor immediately.
3. **Command Panel Escape with IME Marked Text (`AppCoordinator+PlaybackInputRouter.swift`, `WorkbenchFormControls.swift`)**:
   - Updated `handlePlaybackCommandPanelKeyDown` to return `false` before handling `Esc` (`keyCode == 53`) when `commandPanel.page == .root`, `textInputState.isEditableFocused`, and `textInputState.hasMarkedText` are true, allowing the event to reach the focused text editor / IME and dismiss the candidate composition first without closing Command Panel.
   - Updated `WorkbenchSingleLineTextInput`'s `cancelOperation(_:)` handler to discard and clear active marked text while returning `true` if invoked while `hasMarkedText()` is true, keeping the input field focused.
4. **Business Dialog Primary Button Return Shortcut Removal (`LibraryEditCoverDialog.swift`, `ExcerptListEditor.swift`, `LibraryRenameDialog.swift`, `AnkiExportDialog.swift`, `CueFacetFilterPanel.swift`)**:
   - Removed `.keyboardShortcut(.defaultAction)` from the bottom-right primary action buttons in `Edit Cover`, `Excerpt List Editor`, `Rename Folder / Rename Files`, `Export to Anki`, and `Filter`, leaving `Confirmation Dialog` (`WorkbenchConfirmationDialog`) unchanged.
5. **Settings Native Controls Replacement (`SettingsLanguageCategory.swift`, `SettingsSubtitleCategory.swift`, `SettingsLayout.swift`, `SettingsMaintenanceCategory.swift`, `SettingsStore.swift`, `SettingsView.swift`, `AppCoordinator.swift`, `AppCoordinator+Indexing.swift`, `AppDelegate.swift`)**:
   - Replaced the native `Picker(.menu)` in `Settings / General / Language` with the unified `220pt` (`--width-settings-popup`) dropdown trigger (`SettingsSubtitleFontTrigger`) and `C-04.1 Menu / Dropdown Menu` (`SettingsLanguageMenu` built on `WorkbenchPopoverPanel` and `WorkbenchPopoverRow` with radio checkmarks and `MenuGateClientView`).
   - Replaced the native `.alert` in `Settings / Maintenance / Compact` with `WorkbenchConfirmationDialog` hosted inside `WorkbenchDialogLayer` in `SettingsView`, syncing the Settings window's red close button (`isEnabled`) and blocking `Cmd+Q` / Dock quit (`AppCoordinator.isBlockingConfirmationPresented` in `AppDelegate.applicationShouldTerminate`) while the confirmation dialog is open.

## Verification
- Updated and added unit tests in `WorkbenchLayoutStateTests.swift`, `PlaybackChromeVisibilityModelTests.swift`, `PlaybackNormalShortcutTests.swift`, `PlaybackSubtitleFocusKeyboardActionTests.swift`, and `SettingsStorePlaybackTests.swift`.
- Ran `swift test --package-path apps/macos-native --filter "WorkbenchLayoutStateTests|PlaybackChromeVisibilityModelTests|PlaybackNormalShortcutTests|PlaybackSubtitleFocusKeyboardActionTests|SettingsStorePlaybackTests"`.
- Outcome matched expectations.
