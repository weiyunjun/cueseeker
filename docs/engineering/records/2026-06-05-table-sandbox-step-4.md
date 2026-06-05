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

### Sub-step 4 — mouse drag selection across rows/columns (this commit)

- `SubtitleTextCellView` now handles `mouseDown`/`mouseDragged`/`mouseUp` and
  delegates to the coordinator. The origin cell keeps the drag, so the
  coordinator maps each drag point (in window coordinates) to any row/column/
  header position via `position(atWindowPoint:)`.
- Coordinator `beginSelection` / `updateSelection` / `endSelection` set the
  anchor and follow the focus; `position(atWindowPoint:)` resolves the header,
  data rows, and below-last-row / left-right clamping.
- Empty-area clicks on the table clear the selection.

### Sub-step 5 — cmd+C copy as TSV (this commit)

- `copySelection` walks the selected rows (including the header) and, per row,
  joins the three columns' selected substrings with tabs (rows joined by
  newlines), replacing any in-cell newline with a space so it pastes cleanly
  into Excel. `performKeyEquivalent` handles cmd+C.

### Sub-step 6 — drag auto-scroll incl. header (this commit)

- During a drag, `applyDragSelection` calls `autoscroll(with:)` and a
  main-actor `Task` loop keeps scrolling + extending the focus while the pointer
  is held at the top/bottom edge. Dragging up reaches the frozen header (which
  participates as row -1); dragging down past the last row extends to its end.
  The loop ends on mouse-up or when the coordinator is gone.

## Verification

- `swift build --target CueSeekerApp` succeeded after every sub-step.
- End-to-end (owner): drag across rows and columns selects continuous text
  (header included), cmd+A selects all, cmd+C pastes as TSV, and dragging to the
  top/bottom edge auto-scrolls and keeps selecting.

### Sample data — expanded to 80 rows (testing aid)

The 8 base sample rows are repeated 10 times (80 rows, sequential ids) so the
sandbox has enough content to scroll and to test drag auto-scroll.

## Outcome

Phase B2 complete and building: cross-row/column text selection with the frozen
header participating, cmd+A / cmd+C (TSV), and drag auto-scroll — all on the
virtualized table. Next is B3 (hover Play/Copy buttons).
