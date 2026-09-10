# Keyboard focus no longer follows the system setting, and nothing opens focused

Human-owned documents:

- `docs/human/requirements/20260911-UI-Keyboard Focus Ignores System Setting And Has No Default Focus.md`
- `docs/human/design/UI Application Rules.md`
- `docs/human/design/UI Design System.md`

## Why

Two different mechanisms put a focus ring or a caret on screen without anyone asking for one.

The first is the system's Keyboard navigation switch (System Settings → Keyboard). While it is on, every button, switch and menu in the App can take the keyboard, and a window that appears hands the keyboard to the first of them. That is the ring the owner saw on the Edit Cover dialog's X and on the first button of the launch page. With the switch off, none of that happens. The App therefore behaved in two different ways depending on a system setting it never looked at.

The second happens with the switch in either position. A window that becomes key with nothing focused puts the caret in its first text field. It does this when it first appears, and again every time it comes back from another window or App. This is why the Search page opened with the caret already in its search field, and why the list editor would have opened with the caret in List Name once its X could no longer take the keyboard. It was measured in a standalone probe with the switch off, and the main window, which the App lays out before showing it, did the same.

Neither can be switched off for the App as a whole. Standalone probes showed that SwiftUI ignores an App-level override of the keyboard-access answer, and that the preference cannot be overridden for one App either, not even on the command line: the value comes from the system session, not from the App's defaults. The requirement's direction is to treat the switch as permanently off. What decides the outcome is therefore each control's own focusability, plus undoing the automatic caret whenever a window becomes key.

## What changed

**Buttons and other controls never take the keyboard.** Every button, switch and menu control is excluded from keyboard focus, with the same modifier the App already used in eleven places. It works the same with the switch on or off: probes with the switch on showed App-drawn buttons, native bordered buttons, switches and pop-up menus all dropping out of the Tab order, and no longer being handed focus when a window opens. Tab and Shift-Tab now stop only at text inputs, and at the subtitle table's selection surfaces, which were already there with the switch off and show nothing when reached.

- The shared controls exclude themselves: Button, Primary, Destructive, Icon Button, the inline clear button, popover rows, the cover summary's play button and the table header's checkbox. So do the controls that are not built from them: Settings' mode buttons, maintenance buttons, switches and language menu, the Shiori list card, the facet filter rows, and the player's icon, mute, speed and speed-menu buttons.
- Those shared controls used to draw a focus ring whenever the system focused them. That can no longer happen, so the focus state, the ring and the per-version helper that turned off the system's own ring on macOS 14 and later are gone. The helper was the only version branch involved.
- The Task and Settings entries in the top bar each carried their own exclusion, with a comment about launch focus. The icon button they wrap now does that itself, so both were removed.
- The table's "Tab into the checkboxes" is reached by tabbing onto the header's checkbox. That checkbox no longer takes the keyboard, so the entry is closed, as the requirement asks. The keyboard handling inside the table that follows the entry is left in place for when the entry comes back.

**Nothing opens focused.** A window that becomes key with nothing focused now has AppKit's automatic caret taken back in the same turn, before it draws. Focus the window still had when it last stopped being key is left alone, so coming back from another App or window returns to what the user had. The main window, the Settings window and the list editor carry this. Rename does not, because its caret is meant to be in New Name. Edit Cover, the Task panel and Confirmation have no text input for AppKit to pick. Command Panel's search field and Rename's field keep the explicit autofocus they already had.

**A dialog takes the focus from the page for good.** When the dialog layer opens, the page's focus is cancelled, the same way a menu cancels it, so closing the dialog brings nothing back.

**Confirmation opens on Cancel.** Buttons no longer take the keyboard, so the dialog draws Cancel's Focused state itself. The shared Button gained a flag for this and no longer tracks system focus. Space presses Cancel through a key listener scoped to the dialog's own window. Enter keeps its default-action shortcut and Esc still dismisses the sheet. Tab has nowhere to go, so the ring stays on Cancel.

The Select Mode overlay already had a key listener scoped to its own window. It was lifted out, unchanged, into a shared view that both the overlay and Confirmation use.

No token was added, changed or removed.

Files:

- `apps/macos-native/Sources/CueSeekerApp/Shared/OpensWithoutFocus.swift` (new)
- `apps/macos-native/Sources/CueSeekerApp/Shared/WindowKeyDownMonitor.swift` (new)
- `apps/macos-native/Sources/CueSeekerApp/Shared/WorkbenchSchemaSearch/SchemaWorkbenchSelectionActionOverlay.swift`
- `apps/macos-native/Sources/CueSeekerApp/Shared/WorkbenchControls/WorkbenchConfirmationDialog.swift`
- `apps/macos-native/Sources/CueSeekerApp/Shared/WorkbenchControls/WorkbenchControls.swift`
- `apps/macos-native/Sources/CueSeekerApp/Shared/CoverSummaryCard.swift`
- `apps/macos-native/Sources/CueSeekerApp/TableSandbox/SubtitleTableView.swift`
- `apps/macos-native/Sources/CueSeekerApp/App/AppCoordinator.swift`
- `apps/macos-native/Sources/CueSeekerApp/Workbench/ContentView.swift`
- `apps/macos-native/Sources/CueSeekerApp/Settings/SettingsView.swift` and the Appearance, Decode, Developer, Language, Maintenance, Play, Search and URL Scheme categories
- `apps/macos-native/Sources/CueSeekerApp/Shiori/ShioriListCardGrid.swift`
- `apps/macos-native/Sources/CueSeekerApp/Shared/WorkbenchSchemaSearch/CueFacetFilterPanel.swift`
- `apps/macos-native/Sources/CueSeekerApp/Playback/Chrome/PlaybackChromeIconButton.swift`, `PlaybackChromeSpeedMenu.swift`, `PlaybackChromeView.swift`, `PlaybackVolumeControl.swift`
- `apps/macos-native/Sources/CueSeekerApp/Shared/TopbarAppEntries.swift`, `apps/macos-native/Sources/CueSeekerApp/Tasks/TaskEntryButton.swift`

## Verification

macOS 15.5 only. The macOS 13 and 14 paths use the same code, with no version branch left, but were not run: this was agreed with the owner, and no macOS 13 or 14 machine or VM was added.

`swift build`: clean, with no warning in any changed file. `swift test`: 1176 tests, compared against a pristine `79f6add6` copy expanded with `git archive` into a scratch directory, with `CUESEEKER_MEDIA_RUNTIME_ROOT` pointed at the repository's runtime, so the working tree was never reverted. Both sides fail 14 tests, 13 of them shared: native playback timeline, audio and presentation, the auto-pause boundary, the cue-group refresh-scope waits, and the two Debug E2E scene-geometry cases. Only this tree fails `thumbstickRepeatsUntilItReturnsToTheDeadzone`; its suite passes 4 of 4 alone. Only the baseline fails `failedLibraryFolderRemovalPreservesFolderAndPresentationState`. Run alone, `CueGroupRefreshScopeIntegrationTests` fails the same two tests on both trees. The suites that cover the changed controls, dialogs, layers and menus pass together, 183 tests.

Debug E2E controller, main window 1445×821 at 2×, with the existing `click`, `rightClick`, `mouseMove`, `keyPress`, `inspect` and `capture` commands; no E2E facility was added. Coordinates were read off this session's captures and are not documented procedure coordinates; the Sidebar coordinates in the E2E document predate the current Sidebar.

Keyboard navigation on:

1. Launch on the Search page: no ring anywhere, and the search field's border is the unfocused grey with no caret.
2. The Task panel, Edit Cover (Library card → Change Cover) and New List all open with nothing focused. The X carries no ring, and New List's name field has no caret.
3. Rename Folder (File → Edit → right-click Ave Mujica) opens with the caret in New Name and the name selected; nothing else is focused. Cancelled.
4. On the player, K opens the Command Panel with the caret in its search field.
5. Delete Record, the Confirmation stacked on the Task panel, opens with Cancel's ring, and none on Delete or X. Space closes it, and so does Enter. The record was still there both times, and the exported file was never at risk: this dialog deletes the record only.
6. Two Tabs in that Confirmation leave the ring on Cancel.
7. Tab in the Workbench goes search field → two invisible table stops → search field; no button is reached. Tab in New List goes List Name → Description, and a further Tab types a tab character into Description. That is the text area's existing behaviour, not something this change touched. Tab in Settings reaches only the gap field; the switches never show a ring.
8. With the caret in the search field, clicking the top bar's Task entry and closing the panel with Esc leaves the search field without a caret.
9. The New List, Task, trash, gear and Select Mode buttons show no ring after being clicked.
10. Enter opens the Playback Overlay, and Tab moves it from Current to Playlist.

Also checked: the main window comes back from the Settings window with nothing focused. Select Mode's Esc still exits through the shared key listener. Tab in Select Mode rings no checkbox.

The real user data touched: Ave Mujica EP01 played for about a minute and a half, so its saved position moved from 20:52 to 22:17. Nothing was saved, renamed, created or deleted.

Keyboard navigation off: pending the owner switching the setting.

Manual, per the E2E document's cross-application rule: switch to another App with the caret in a field and come back. The caret should still be there.

## Noticed, not changed

- The dialog layer follows Edit Cover, the list editor, the Task panel and Confirmation, but not Rename, although `UI Application Rules.md` lists Rename among the dialogs. Rename only opens from a menu, and the menu has already cancelled focus by then, so this requirement is not affected. The dialog-layer freeze while Rename is open is a separate matter.
