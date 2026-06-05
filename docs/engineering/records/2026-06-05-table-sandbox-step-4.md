# Table Sandbox Step 4 — Phase B2: Cross-Row/Column Text Selection

Human requirement:

- `docs/human/requirements/20260605-Feature-UI Redesign.md`

## Scope

Phase B2 adds custom text selection over the virtualized table (selection lives
in the data model as start/end markers; highlight is painted only on visible
cells, so virtualization/reuse is preserved). B2 is implemented in small,
separately built sub-steps because one large change repeatedly failed to apply.

### Sub-step 1+2 — selection primitives (this commit)

Additive only; no behavior change yet.

- `SubtitleTextLayout`: added `length`, `characterIndex(forPoint:)` (nearest
  insertion point for a text-local point) and `selectionRects(forCharacterRange:)`
  (enclosing rects for painting the highlight).
- `SubtitleTextCellView`: added a `selectedRange`, optional vertical centering
  (for header cells), a `contentOrigin`, plus `textLength`,
  `characterIndex(at:)` and `setSelectedRange(_:)`. `draw` now paints
  `selectedTextBackgroundColor` behind the selected glyphs (text color
  unchanged) before drawing the text.

### Sub-step 3 — selection model + header cells + cmd+A (this commit)

- Added `TableTextPosition` (Comparable document position: row -1 = header,
  column 0/1/2, char), and coordinator selection state (`anchor`/`focus`).
- Converted the frozen header to three `SubtitleTextCellView` cells (row -1) so
  the header highlights and hit-tests uniformly with the body.
- Added `orderedSelection`, `cellRange` (per-cell sub-range from the global
  selection), `refreshSelectionHighlights` (header + visible rows),
  `selectAll`, `clearSelection`, and `cellFullText`/length helpers.
- `viewFor` now stamps each cell's row/column and applies the current
  selection range, so scrolled-in cells show the right highlight.
- The table accepts first responder and grabs focus on click;
  `performKeyEquivalent` handles cmd+A → select all table text. (Testable now:
  click the table, press cmd+A → header + all rows highlight.)

### Planned remaining sub-steps

- Mouse drag selection across rows and columns.
- cmd+C copy as TSV (tab between columns, newline between rows).
- Drag auto-scroll at the top/bottom edges, including extending into the header.

## Verification

- `swift build --target CueSeekerApp` succeeded after sub-step 1+2.
- No visible behavior yet (primitives only); end-to-end checks come once the
  selection input is wired.

## Outcome

Primitives in place and building; remaining sub-steps build on them.
