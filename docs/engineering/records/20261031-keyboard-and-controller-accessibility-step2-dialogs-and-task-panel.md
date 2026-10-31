# 2026-10-31 Keyboard and Controller Accessibility — Step 2 (Modal Dialogs & Task Panel)

## Requirement Reference
- `docs/human/requirements/20261031-UI-Keyboard And Controller Accessibility Across Workbench Dialogs Settings And Playback.md`
- `docs/human/design/ui/UI Accessibility Rules.md`
- `docs/human/design/playback/Controller.md`

## Summary of Changes (Step 2)
1. **Dialog Accessibility State & Routing Infrastructure (`WorkbenchAccessibility.swift`, `AppCoordinator.swift`, `AppCoordinator+WorkbenchAccessibility.swift`, `AppDelegate.swift`, `ContentView.swift`, `WorkbenchDialogHeader.swift`)**:
   - Added `WorkbenchDialogAccessibilityID`, `WorkbenchDialogTextInputKind`, `WorkbenchDialogAccessibilityTarget`, and `@Environment(\.workbenchDialogID)` injected across all 13 main-window dialogs (`L-06.1` ~ `L-06.11`).
   - Implemented topmost active dialog detection (`activeDialogAccessibilityID()`), active dialog session `objectWillChange` subscription, target enumeration (`currentDialogAccessibilityTargets()`), enabled state queries (`isDialogAccessibilityTargetEnabled(_:)`), focus reconciliation (`reconcileDialogAccessibilityFocus()`), cyclic focus movement (`moveDialogAccessibilityFocus(forward:)`), and target activation (`activateDialogAccessibilityTarget(_:)`).
   - Enforced the two-stage `Esc` / controller `◯` dismissal contract (1st `Esc` / `◯` clears the accessibility focus ring while preserving ordinary text input typing focus; 2nd `Esc` / `◯` or `Esc` / `◯` when unfocused closes the topmost dialog) and prevented `Return` from triggering any dialog footer button when no control has an accessibility focus ring.
2. **Dialog Text Inputs & Form Controls (`WorkbenchNativeTextFields.swift`, `WorkbenchTextAreaInput.swift`, `WorkbenchFormControls.swift`)**:
   - Added `focusFromAccessibility()` and `unfocusFromAccessibility()` across single-line text fields (`autofocus` fields select all text when focused from unfocused state; other fields place the caret at the end), secure password fields, and multi-line text areas (`Description`).
   - Synchronized text input typing focus with dialog accessibility focus (`Tab` / `Shift + Tab` / `R1` / `L1` entering an enabled text input immediately enters typing focus; moving to another control immediately resigns typing focus; 1st `Esc` / `◯` clears the outer focus ring while keeping typing focus).
3. **Individual Modal Dialogs & Task Panel (`L-06.1` ~ `L-06.11`)**:
   - **`L-06.1 Edit Cover Dialog` & `L-06.2 Excerpt List Editor Dialog` (`LibraryOverviewComponents.swift`, `LibraryEditCoverDialog.swift`, `ExcerptListEditor.swift`)**: Added outer focus ring support to `LibraryCoverChooser` without displaying the hover `Choose Image` overlay, and wired cover chooser (when not in crop mode), `Name`, `Description`, `Cancel`, and `Save`/`Create`.
   - **`L-06.3 Rename Dialog` (`LibraryRenameDialog.swift`)**: Wired `Close` (`×`) -> `New Name` -> `Cancel` -> `Confirm` and ensured pressing `Tab` from initial autofocus unfocuses `New Name` and focuses `Close` (`×`).
   - **`L-06.4 Remote Folder Dialogs` (`RemoteFolderDialogSharedViews.swift`, `WebDAVFolderDialog.swift`, `SMBFolderDialog.swift`, `FTPFolderDialog.swift`, `NFSFolderDialog.swift`)**: Wired Step 1 connection fields and buttons (keeping disabled fields/buttons in the `Tab` sequence while `isSubmitting`) and Step 2 browser breadcrumb links, enabled folder cards + circular `Checkbox` focus rings, and `Back` / `Cancel` / `Add` buttons.
   - **`L-06.5 Export to Anki Dialog` (`AnkiExportDialog.swift`)**: Wired `Close` (`×`), Front/Back `+` buttons, badge row `x` remove buttons (auto-exiting accessibility focus upon item removal), `File Name`, `Location`, `Choose Folder`, `Cancel`, and `Export`.
   - **`L-06.6 Filter Dialog` (`CueFacetFilterPanel.swift`)**: Wired `Close` (`×`), all facet filter chips in section order, `Reset`, `Cancel`, and `Show`.
   - **`L-06.7 Confirmation Dialog` (`WorkbenchConfirmationDialog.swift`)**: Removed the default focus ring on `Cancel` when opening, removed unfocused `Space`/`Return` button activation, and wired `Close` (`×`) -> `Cancel` -> `Confirm`/action buttons.
   - **`L-06.8 File / Folder Detail Dialog` (`WorkbenchFileDetailDialog.swift`)**: Wired `Close` (`×`) -> paired file switcher trigger (`File Detail`) and `Close` (`×`) only (`Folder Detail`).
   - **`L-06.9 ~ L-06.11 Task Panel & Task Detail Dialog` (`TaskPanel.swift`)**: Wired `Current` / `Completed` / `Incomplete` tabs -> `Close` (`×`) -> task card `dots-three` buttons (revealing the `dots-three` button on accessibility focus as well as hover/open menu), and handled stacked dialog transitions (`Task Panel` <-> `Task Detail Dialog` / `Confirmation Dialog`).

## Verification
- Added `WorkbenchAccessibilityStep2Tests.swift` covering all Step 2 dialogs (`L-06.1` ~ `L-06.11`), disabled control traversal, text input focus synchronization, two-stage `Esc` / `◯`, unfocused `Return` suppression, Anki badge removal auto-exit, and stacked dialog focus handoff.
- Ran `swift test --package-path apps/macos-native --filter WorkbenchAccessibilityStep`.
- Outcome matched expectations.
