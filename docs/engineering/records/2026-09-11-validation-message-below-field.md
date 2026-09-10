# The validation message moves under its field

Human-owned documents:

- `docs/human/requirements/20260911-UI-Validation Message Below Field.md`
- `docs/human/design/UI Design System.md`

## Why

Text Field and Text Area kept one line free for their validation message between the label and the box. With no error on screen that line had nothing to belong to, so it read as an unexplained gap between a label and its own field — the oddness the owner pointed at. When an error did appear, it sat above the box the user had just typed into, so the eye had to travel back up to learn what was wrong.

Most form systems (Material, Ant Design, Carbon, Polaris, Primer, Fluent) put the message under the field; the ones that put it above (GOV.UK, USWDS) only take that space while a message is showing. Moving the line under the box keeps the reservation — which is what stops a centred dialog from jumping when an error appears — and changes only where the empty line sits. Under the box, the empty line reads as ordinary spacing between fields.

## What changed

One file. The shared field container behind both form controls now stacks label, box, message instead of label, message, box. The stack's existing gap separates each pair, so the message sits as far under the box as the label sits over it, and a field's total height is unchanged. The reserved line, its type, colour, one-line limit and the error border are untouched, and none of the three call sites changed.

Files:

- `apps/macos-native/Sources/CueSeekerApp/Shared/WorkbenchControls/WorkbenchFormControls.swift`

## Verification

Debug E2E controller, main window 1445×821 at 2×, with the existing `click`, `rightClick`, `keyPress` and `capture` commands; no E2E facility was added. The New List, Create, menu item, Rename and Settings coordinates were read off this session's captures and are not documented procedure coordinates. Each pair of captures was compared pixel by pixel inside the sheet.

- New List (Shiori → New List). With no name, List Name sits directly on its box. Create with no name puts `Enter a list name.` directly under the red-bordered box. The sheet is 792×390 at the same origin before and after the error, the size recorded for this dialog on 2026-09-02. The only pixels that change are in the name field's column, from the box's top border to the end of the message (sheet points x 428–768, y 84–140.5); cover, Description, support text and buttons are identical.
- Rename Folder (File → Edit → right-click the Clannad folder). New Name sits directly on its box. Rename with the name unchanged puts `The name is unchanged` under the box and holds the dialog open. The sheet is 388×274 before and after, and the only change is again the field column (x 24–364, y 134.5–193).
- Dark. After switching Appearance to Dark in the app's own Settings, the same four captures give the same sheet sizes and the same changed regions, with the message in the dark danger colour. Appearance was set back to Light afterwards.
- The Task panel showed no task at the end; no rename was queued.

`swift test`: 1176 tests, run with and without this change on the same tree. With it, 12 tests fail: native playback timeline, audio and presentation, the auto-pause seek boundary, the cue-group refresh-scope waits, and the two Debug E2E scene-geometry cases. Without it the same 12 fail plus three more (library folder removal twice, shared persistence migration), all from the suite's existing environment- and timing-dependent set. No failure is new, and none of them reads a form field.

## Follow-up: form spacing and the Description box

### Why

With the message under the box, three things read wrong in the list editor. The label sat 4pt over its box — about 6.5pt from the label's baseline to the border — which the owner found too tight. The gap from the List Name box down to the Description label was 35pt: the 19pt reserved line plus the 16pt field gap. And the Description box now ended 19.5pt above the cover's bottom edge, because the reserved line that used to sit above the box had moved below it; the old text area height had been sized for the old order.

### What changed

- The label sits `--spacing-2` over its box. The message stays `--spacing-1` under it, so it still groups with the box it describes rather than with the next label.
- The list editor's field gap drops from `--spacing-4` to `--spacing-2`, taking the List Name box to Description label distance from 35 to 27.
- `--height-form-text-area` goes from 77.5 to 96.75, so the Description box ends on the cover's bottom edge. Its reserved line hangs below the cover, beside the support text, where the band is about 29pt; the dialog's height is set by the cover column, so it stays 390.
- The Rename dialog only takes the label change and grows from 274 to 278. Its Current Name label-to-path gap is plain text, not a box, and stays `--spacing-1`.
- The unit test that held the form's height equal to the cover's now holds the Description box's bottom equal to the cover's bottom, which is the new rule; the text area height it pins moves with the token.

Files:

- `apps/macos-native/Sources/CueSeekerApp/Shared/WorkbenchControls/WorkbenchFormControls.swift`
- `apps/macos-native/Sources/CueSeekerApp/Shared/WorkbenchControls/WorkbenchControls.swift`
- `apps/macos-native/Sources/CueSeekerApp/Shiori/ShioriListEditor.swift`
- `apps/macos-native/Tests/CueSeekerAppTests/WorkbenchInputControlsTests.swift`

### Verification

Debug E2E controller as above; figures are sheet points read off the captures.

- New List, empty and error: List Name's baseline sits 10.5 over its box (layout gap 8). The box runs 88–128, the message 132–147, the Description label box starts at 155, so the box-to-label distance is 27. The Description box runs 180–276.75 and its bottom border lands on the same pixel row as the cover's bottom edge (277.0). Sheet 792×390, buttons 326–366, unchanged.
- Edit List on an existing list with a cover: the same figures, the same alignment. Closed with Escape, nothing saved.
- Rename Folder: sheet 388×278. New Name's baseline sits 10.5 over its box and `The name is unchanged` appears under it; no rename was queued.
- Dark: New List's error state gives the same figures.

## Follow-up: the cover dialogs' sizes become tokens

### Why

The Shiori List Editor and Edit Cover set their header-to-body and body-to-footer gap to a bare 20, and their sizes to bare numbers — 792 wide with a 380 cover column, and 760×600 — since they were first written. None of those values were in the design document, which gave the gap as `--spacing-4`. The owner's rule is that every UI value is a named token recorded in the design document.

### What changed

- `--gap-cover-dialog-region` (20) is the region gap of both dialogs.
- `--width-shiori-list-editor-cover` (380) is the cover column's width. `--width-dialog-form-region` (340) names the form column width the code already kept as a constant.
- The list editor's 792 is no longer written anywhere: it is computed as cover column plus column gap plus form column plus the two dialog insets, the way the Rename dialog already computes its width. No token was added for it.
- `--width-edit-cover-dialog` (760) and `--height-edit-cover-dialog` (600) size Edit Cover.
- The alignment test reads the two column widths from the same tokens.

Every value is the one it replaces, so nothing on screen moves.

Files:

- `apps/macos-native/Sources/CueSeekerApp/Shared/WorkbenchControls/WorkbenchControls.swift`
- `apps/macos-native/Sources/CueSeekerApp/Shiori/ShioriListEditor.swift`
- `apps/macos-native/Sources/CueSeekerApp/Library/LibraryEditCoverDialog.swift`
- `apps/macos-native/Tests/CueSeekerAppTests/WorkbenchInputControlsTests.swift`

### Verification

- New List: sheet 792×390, and every measured edge — label, box, message, Description, cover, buttons — is where the previous build put it.
- Edit Cover (Library → right-click the Clannad card → Change Cover): sheet 760×600. The support text's box ends at 516 and the buttons start at 536, a 20 gap; the cover area starts 20 under the title. Closed with Escape; nothing was saved.
- `swift test` after each follow-up: 1176 tests. The failing set stayed inside the environment- and timing-dependent set of the first run and its baseline, except for one test each time — library folder removal progress after the spacing change, search facet refresh scope after the token change. Each passed three times out of three when run alone, and both belong to families that already flake under the full suite's load. Neither reads a dialog.

## Known limits

The rename message for invalid characters is longer than one line at this width and is still cut off by the one-line limit. The requirement keeps that limit, so this change does not address it.

Only Rename Folder was captured. Rename Files uses the same field.

In several captures the cover shows its `Choose Image` hover overlay. The controller does not move the real pointer, and the owner's pointer was resting over the cover, so the overlay is real hover, not part of the change.

The Confirmation dialog was left as it is: its header-to-message gap is 12 where the design document gives a 16 region gap, and the document itself gives its action gap as `--spacing-3` in one place and `--spacing-2` in another. Settling that is outside this requirement.

