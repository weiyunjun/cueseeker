# Table Sandbox Step 3 — Phase B1: Virtualized Table with Self-Drawn Text Cells

Human requirement:

- `docs/human/requirements/20260605-Feature-UI Redesign.md`

## Scope

Phase B was re-scoped after end-to-end feedback: the per-cell `NSTextField`
approach could not support cross-row/cross-column text selection and reverted
its font on click. The agreed direction keeps a virtualized `NSTableView` (like
Excel: only visible rows rendered, cells reused) and implements text selection
as a model-level marker rendered onto visible cells (B2). B1 lays that
foundation; it still uses static sample data.

B1 changes (platform UI/UX only):

- Replaced the `NSTextField`-based cells with `SubtitleTextCellView`, a
  self-drawn cell backed by its own TextKit stack (`SubtitleTextLayout`:
  `NSTextStorage` / `NSLayoutManager` / `NSTextContainer`). This gives full
  control over drawing, measurement, and (in B2) hit-testing and partial
  selection highlights.
- Removed the inline play button; the Cues cell is now pure text. Hover
  Play/Copy buttons come in B3.
- Removed the previous row-selection / select-all / cmd handling; selection is
  rebuilt properly in B2.
- Kept: virtualization and cell reuse, frozen header outside the scroll view,
  manual variable row heights, word wrapping, row hover background, per-row
  bottom hairline (no full-table grid, no vertical lines), rounded container,
  native semantic colors following light/dark.
- Fonts aligned with the production cue text: body (Name/Cues) 13.5 semibold
  with 4pt line spacing; index 12 secondary; header 11 semibold. Row-height
  measurement uses the same TextKit layout as drawing, so wrapping stays exact.
- Row height no longer reserves a play-button slot in the Cues column.

## Verification

- `swift build --target CueSeekerApp` succeeded (`Build complete`).
- Visual check is the owner's end-to-end test: open Test Search / Test Shiori
  and confirm text renders with the correct font/size/wrapping, variable row
  heights, hover background, separators only between real rows, frozen header,
  and light/dark following. (No selection or buttons yet — those are B2/B3.)

## Fix — minimum row height (one line, not two)

Owner reported rows defaulting to roughly two lines tall. The minimum content
height used `NSFont.boundingRectForFont` (the font's max-glyph box, which
overestimates) as the floor. Replaced it with a precise single body line height
measured once via TextKit without inter-line spacing, so a one-line row is one
line tall. Rows still grow when the Name or Cues text actually wraps (e.g., long
names in the fixed-width Name column, or bilingual cues), which is intended.

## Outcome

Build green. Foundation ready for B2 (custom cross-row/cross-column selection,
cmd+A, cmd+C as TSV, drag auto-scroll including the header) and B3 (hover
Play/Copy buttons).
