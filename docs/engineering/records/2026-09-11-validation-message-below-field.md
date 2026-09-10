# The validation message moves under its field

Human-owned documents:

- `docs/human/requirements/20260911-UI-Validation Message Below Field.md`

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

## Known limits

The rename message for invalid characters is longer than one line at this width and is still cut off by the one-line limit. The requirement keeps that limit, so this change does not address it.

Only Rename Folder was captured. Rename Files uses the same field.

`UI Design System.md` still lists the Text Field and Text Area anatomy as Label, Validation Message, Container. Per the owner's instruction the design documents are updated after this round of UI tuning is accepted, so that gap is expected until then.
