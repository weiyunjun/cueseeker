# Dialog width tiers, dialogs that fit the window, and one dialog container

Human-owned documents:

- `docs/human/requirements/20260911-UI-Dialog Size Tiers.md`
- `docs/human/design/UI Design System.md` (to be updated by the owner after acceptance)

## Why

The five dialogs had five widths, each from its own source: Confirmation 360 written in place, Rename 388 and the Shiori List Editor 792 summed from their columns, Edit Cover 760 × 600 and the Task panel 460 × 440 from tokens of their own. None of them fitted the window: a dialog wider or taller than the window was cut by its edge. The Task panel had no title, 16pt insets instead of the dialogs' 24, and drew its own background, shadow and border over the ones the dialog layer draws; Confirmation drew a border of its own too.

## What changed

**Width tiers.** New in code: `--width-dialog-small` 360, `--width-dialog-medium` 480, `--width-dialog-x-large` 720. `--width-dialog-large` 600 has no dialog, so it is not in code yet. Confirmation and Edit Cover take small, Rename medium, the Task panel x-large, and the Shiori List Editor x-large or small (below). The Task panel's height becomes 500. Gone: the Task panel's width and header height, Edit Cover's width and height, the list editor's cover width and form width, and the text area's height.

**Fitting the window.** The dialog layer hands every dialog the window less `--spacing-6` on each side. A dialog takes its tier's width or that width, whichever is smaller. A dialog taller than that height keeps its title and buttons and scrolls what lies between them: a small layout stacks header, content and footer, and when the three are too tall the content, a scroll view, gives up the difference. A scroll view asked for no particular height answers with its content's, so a content that fits takes exactly its own height. The scroll view spans the dialog's full width with the inset inside it, so its overlay scrollbar runs in the inset, not over the content.

**Shiori List Editor.** While the window leaves 720 for it (a window 768 wide or more) it has two columns; below that it is 360 wide with the cover above the name and the description. One layout is switched in place, so the fields keep their text and focus when the window crosses the width. The cover is the small dialog's content width in both layouts, 312 × 175.5; the two-column form column is what is left, 336. The Description box still ends on the cover's bottom edge: its height is the cover's height less what stands above it in the form column (the List Name label, field and reserved message line, and the Description label, with their gaps), computed from the type's line heights, 58.5. The one-column layout keeps that height. Its content is the part that scrolls.

**Edit Cover.** 360 wide, its height its content's. The cover is the content width at 16:9, and a chosen image is cropped in that same frame, as in the list editor.

**Rename.** 480 wide; the current name and the field span the content width.

**Task panel.** Title `Task` with the dialogs' close button in the corner, the Tabs centred under the title, then the card list; `--spacing-4` between the three. The list reaches the dialog's sides and bottom, with the cards one inset in from the sides and the last card one inset above the bottom. Its own background, shadow, clip and border are gone; the dialog layer draws them as for every dialog. The close button is now the dialogs' shared one, which gained a switch so Escape presses it in a dialog without a Cancel button; the panel keeps Escape for itself unless a Confirmation stands over it, as before.

**Container.** All five dialogs fill `--color-bg-surface` and none draws a border of its own. Confirmation's own border and rounded fill are gone.

The new tokens are named in code comments and go into `UI Design System.md` once the owner accepts the result.

Files:

- `apps/macos-native/Sources/CueSeekerApp/Shared/WorkbenchControls/WorkbenchControls.swift`
- `apps/macos-native/Sources/CueSeekerApp/Shared/WorkbenchControls/WorkbenchDialogLayer.swift`
- `apps/macos-native/Sources/CueSeekerApp/Shared/WorkbenchControls/WorkbenchDialogHeader.swift`
- `apps/macos-native/Sources/CueSeekerApp/Shared/WorkbenchControls/WorkbenchFormControls.swift`
- `apps/macos-native/Sources/CueSeekerApp/Shared/WorkbenchControls/WorkbenchConfirmationDialog.swift`
- `apps/macos-native/Sources/CueSeekerApp/Library/LibraryEditCoverDialog.swift`
- `apps/macos-native/Sources/CueSeekerApp/Library/LibraryRenameDialog.swift`
- `apps/macos-native/Sources/CueSeekerApp/Shiori/ShioriListEditor.swift`
- `apps/macos-native/Sources/CueSeekerApp/Tasks/TaskPanel.swift`
- `apps/macos-native/Sources/CueSeekerApp/Resources/{en,zh-Hans,zh-Hant}.lproj/Localizable.strings` (`task.title`)
- `apps/macos-native/Tests/CueSeekerAppTests/WorkbenchDialogFitTests.swift` (new)
- `apps/macos-native/Tests/CueSeekerAppTests/WorkbenchControlMetricsTests.swift`
- `apps/macos-native/Tests/CueSeekerAppTests/WorkbenchInputControlsTests.swift`

## Verification

`swift build` is clean.

New and updated tests: the tier widths, the margin, the Task panel height and the list editor's derived sizes (312, 336, 58.5); a dialog's width is its tier, or what the window leaves when that is less; the header–content–footer layout takes its content's height when it fits and stops at its limit when it does not. The existing test that the Description box ends on the cover's bottom edge passes at the new sizes. A scratch probe first confirmed that a scroll view offered no height answers with its content's.

`swift test`: 1179 tests, 15 fail — native playback timeline, audio and presentation, the auto-pause boundary, the refresh-scope waits, library folder removal under load, and the two Debug E2E scene-geometry cases, the same families the in-window dialogs record lists as failing on the tree before it. None reads a dialog.

**In the App**, after the owner closed their own copy: Debug E2E controller, main window 1445×821 at 2×, light and then dark through the `-appAppearanceMode` launch argument so the owner's setting was never written, with the existing `click`, `rightClick`, `scroll`, `keyPress`, `setWidth` and `capture` commands; no E2E facility was added. Coordinates were read off this session's captures, and every context menu was captured before an item in it was clicked. Measured in pixels:

- Shiori List Editor, window 1445: 720 wide; the cover 312 × 175.5, 24 from the left; column gap 24; the form column 336; the Description box's bottom edge on the same pixel row as the cover's. With the editor open, `setWidth` 740: 360 wide, one column, the same cover, List Name 40 and the Description box 58.5 tall, 24 below the buttons; the List Name field kept its focus across the switch. In dark, two wheel scrolls over the two-column editor left the cover on the same rows.
- Task panel: 692 × 500 at window 740, 720 × 500 at 1445; title, close button, Tabs centred under the title; cards 24 from both sides. Dark: the panel and the cards both `#18181B`, the cards set off by their `#3F3F46` border; the panel's edge is only the dialog layer's outline and 20% highlight.
- Confirmation over the Task panel: 360 wide, the panel veiled under it, the red light grey; its edge is the outline and then white, with no grey line inside it. Cancel returned to the panel with the record still there. In dark, Escape closed the Confirmation and left the panel open; a second Escape closed the panel.
- Rename Folder: 480 wide, the field across the content width with 24 either side; at window 480 it is 432 wide with 24 either side. Cancel left the folder's name as it was.
- Edit Cover: 360 × 376, the cover 312 × 175.5 with 24 on either side. Cancel left the cover as it was.

Not driven: the one-column list editor in a window too short for it, which the owner checks by hand because the controller cannot set the window's height; text typed into List Name before the layout switch, because the App was not the active App at that moment and the controller refused the keys (the text lives in the editor's session, not in the fields); and a Task card list long enough to scroll to its end.

## Known limits

- The Task panel's close button no longer shows a `Close` tooltip or carries its own accessibility identifier; it is the close button the other dialogs have, which has neither.
- The scrollbar's 4pt inset from its scroll area's edge is in code but not in the design document.
- The Debug E2E controller can set the main window's width but not its height, so the one-column list editor scrolling in a short window cannot be driven automatically. The owner chose to check it by hand rather than add the capability.
