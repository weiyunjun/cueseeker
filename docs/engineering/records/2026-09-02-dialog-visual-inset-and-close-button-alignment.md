# Dialog Visual Inset And Close Button Alignment

Human-owned requirement:
`docs/human/requirements/20260902-UI-Dialog Visual Inset And Close Button Alignment.md`

Related design: `docs/human/design/UI Design System.md`
(Dialogs / Dialog, Confirmation Dialog, Icon Button, Typography, Padding, Size).

## Why

A dialog's edges were laid out against boxes rather than against what a reader
actually sees, and the three sources of error stacked in the same corner.

The close button sat inside the header row as a 32-point box holding a 14-point
glyph, so nine points of empty box separated the visible X from the edge the
buttons below it lined up on: the X read as pushed inward by ten points even
though its box was flush. The same box was the tallest thing in the header row,
so it centred the title against itself and pushed the title down four and a half
points. And the container's padding was measured to the title's line box, which
starts five points above the first capital letter, so the top inset read five
points larger than the other three no matter what number the padding carried.

Trimming that last gap is ordinary typographic practice, not a font limitation:
it is what CSS spells `text-box-trim` with `text-box-edge: cap` and what Figma
calls vertical trim. Horizontal side bearings are deliberately left alone —
they differ per letter (1.5pt under a cap, 0.5pt under the body text's first
letter), so trimming them would break the left alignment between a dialog's
title and its body.

## Implementation

New metrics, each recorded next to the constant it derives from:

- `--inset-dialog` = `20`, the one visual inset every dialog edge keeps.
- `--size-dialog-close-button` = `24`, the close button's own box, replacing the
  shared `--size-icon-button` so the focus ring stays in proportion to the
  smaller glyph. The hit area stays at or above the 24-point accessibility floor.
- `--size-dialog-close-icon` moved from `14` to `12`, superseding the value
  accepted on 2026-09-01.
- `redesignDialogCloseGlyphInk` = `9.5`, the measured ink of SF Symbol `xmark`
  at 12pt medium, and `redesignDialogCloseBoxSlack`, half the difference between
  the box and that ink.
- `redesignDialogTitleCapTopInset`, computed at load from `NSFont`'s own
  ascender, descender, cap height and default line height rather than written
  down as a number, so a change of title size or weight recomputes it instead of
  silently breaking the inset. It resolves to 4.967 for the 20pt semibold title.
- `redesignDialogTopPadding` = `--inset-dialog` minus that give-back, 15.033.

`WorkbenchIconButton` gained an optional `boxSize` beside its existing optional
`iconSize`; every other instance keeps `--size-icon-button`.

`WorkbenchDialogHeader` is now the title alone. The close button moved to a
`workbenchDialogCloseButton` modifier that hangs it off the dialog container's
top-right corner, outside the layout flow, inset by
`--inset-dialog` minus the box slack so that the glyph — not the box — lands on
the inset. Confirmation, Edit Cover and the Shiori List Editor each apply the
modifier after their background and border, and each replaced `padding(24)` with
the top/horizontal/bottom split above.

The task panel takes the smaller glyph and box and the same
placed-by-its-glyph rule, expressed as a negative trailing padding that gives
back the box slack inside the tab bar's unchanged 16-point inset. Its four edges
are explicitly out of scope, and the tab bar's own padding is untouched.

## Verification

- `swift build` — clean.
- `swift test` — 1125 tests. The failures are the repository's existing
  environment- and timing-dependent set: native playback media timelines, the
  auto-pause seek boundary and the cue-group refresh-scope waits. They are the
  same set recorded on the previous two requirements and none of them touch
  dialog layout.

Debug in-app E2E against the running App, main window `1445 x 821`, scale 2,
using `click`, `rightClick`, `keyPress` and `capture`. No E2E command or test
facility was added. Every figure below is read out of the captured PNGs in
device pixels and converted to points; the dialog's frame edge is taken as the
outermost border pixel, and the title and body figures convert measured ink to
the text box and the cap line using the font's own bearing and cap metrics.

Confirmation (Delete List), frame measured at exactly `360.0 x 178.0`:

| Distance | Measured |
| --- | --- |
| Title text box → left edge | 20.00 |
| Body text box → left edge | 20.00 |
| Rightmost button → right edge | 20.00 |
| Bottom button → bottom edge | 20.00 |
| Close glyph → right edge | 20.00 |
| Title cap line → top edge | 20.22 |
| Close glyph → top edge | 20.00 |

The spread across the set is 0.22 points, inside the requirement's one-point
band. The close glyph measures 9.50 x 9.50, matching the ink the offsets were
built from.

Shiori List Editor, frame `792.0 x 382.0`: title text box 20.00, title cap line
20.22, close glyph right 20.00 and top 20.50, rightmost button 20.00, bottom
button 20.00.

Edit Cover, frame `760.0 x 600.0`: title text box 20.00, title cap line 20.22,
close glyph right 20.00 and top 20.50, rightmost button 20.00, bottom button
20.00.

Task panel: close glyph 9.50 x 9.50 with its right edge 15.50 from the panel's
right edge, against the tab bar's unchanged 16-point inset; its vertical
position in the tab bar is unchanged because the box still centres in the row.

Not verified in the running App:

- **Dark theme.** The change adds no color and no theme-conditional code, so the
  seven distances above are the same in both themes by construction, but they
  were measured in Light only. Confirming Dark on screen stays a manual
  acceptance step.
