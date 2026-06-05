# Table Sandbox Step 2 — AppKit Table Component (Phase B)

Human requirement:

- `docs/human/requirements/20260605-Feature-UI Redesign.md`

## Scope

Phase B: the reusable AppKit table, driven by static sample data, to align the
visual style before wiring real data in Phase C. This is platform UI/UX only.

- `SubtitleTableRow` row view-model and `SubtitleTableSampleData` (varied
  fake rows: short, bilingual two-line, and long wrapping cases).
- `SubtitleTableView` (`NSViewRepresentable`) wrapping an `NSScrollView` +
  view-based `NSTableView` with three columns: `#` / `Name` / `Cues`.
- Native semantic colors throughout (`textBackgroundColor`, `labelColor`,
  `secondaryLabelColor`, `separatorColor`) so the table follows light/dark; the
  rounded container border/background are refreshed on
  `viewDidChangeEffectiveAppearance`.
- Variable row height via `usesAutomaticRowHeights`; wrapping selectable
  `NSTextField` cells. Top alignment is enforced with a required top constraint
  plus a priority-999 bottom constraint that yields when a row is stretched to a
  taller sibling.
- `#` = visible row number (`row + 1`), computed at render, not stored.
- `Cues` cell reserves a fixed left slot for a low-key play button
  (`play.fill`, secondary tint, hover darkens). Phase B logs the tap; real
  playback is Phase C.
- Selectable text in every cell (including `#` and header) plus per-cell
  `cmd+C`. `cmd+A` is scoped to the table (via `performKeyEquivalent` checking
  the first responder is within the table): it selects all rows and `cmd+C` then
  copies the text content.
- Sticky custom header (`#`/`Name`/`Cues`, semibold secondary text, bottom
  hairline, no vertical separators) kept outside the scroll view so it stays
  pinned; horizontal grid hairlines between rows, no vertical grid lines; outer
  rounded container.
- `WorkbenchTestPageView` now shows the table on the Search and Shiori test
  pages; Library stays blank.

## Design choices and known caveats

- True per-character text selection spanning multiple cells is not feasible with
  per-cell `NSTextField`s. `cmd+A` is therefore implemented as select-all-rows
  (subtle highlight) + `cmd+C` copies the text. The copied text is `Name` + tab
  + `Cues` (cue newlines collapsed to spaces) per row; the `#` ordinal and play
  icon are excluded as non-content. Open question for the owner: whether to
  include `#` and how to format multi-line cues on copy.
- Header/column alignment assumes overlay scrollers (default on modern macOS).
  With classic (always-visible) scrollers the last column is slightly narrower
  than the header band; to be revisited if it shows up in testing.
- The select-all highlight covers the full row (including the play-icon area),
  not only the text, because selection is row-based.

## Verification

- `swift build --target CueSeekerApp` succeeded (`Build complete`).
- Visual/interaction verification is the owner's end-to-end test: open the Search
  and Shiori test pages and check wrapping + variable row height, top alignment,
  row hover, per-cell text selection, `cmd+A` + `cmd+C`, the play button, and
  light/dark following.

## Fix — broken row heights found in first end-to-end test

The owner's first E2E test showed rows not growing to fit wrapped text: cells
overlapped and long names overflowed into the Cues column. Root cause:
`usesAutomaticRowHeights` mis-measured the custom multiline `NSTextField` cells
(width undefined at measure time → single-line height → horizontal overflow and
overlapping rows).

Changes:

- Replaced automatic row heights with manual measurement in
  `tableView(_:heightOfRow:)` using `NSAttributedString.boundingRect` at the
  real column widths (Name fixed; Cues = current column width minus the play
  slot and insets), taking the taller of Name/Cues plus vertical insets.
- Recompute heights on width changes: the table posts frame-change
  notifications and the coordinator calls `noteHeightOfRows` so wrapping stays
  correct on window resize.
- Removed the full-table grid; each `SubtitleTableRowView` now draws its own
  bottom hairline, so separators appear only between real rows and the empty
  area below the last row stays clean.

## Selection model and font corrections (second E2E round)

The owner's second pass flagged that the row-based selection was wrong: it
showed an anti-human full-row highlight and inverted the text to white, and it
blocked normal in-cell text selection. The font was also too small/light versus
the production cue text. I had also wrongly proposed downgrading the agreed
cmd+A whole-table behavior because it was hard; that was reverted to the
original requirement.

Changes:

- Removed row selection entirely: `selectionHighlightStyle = .none`,
  `shouldSelectRow` returns false, and the row view no longer draws a selection.
  In-cell text is selectable again (drag-select + per-cell `cmd+C`).
- Restored the agreed cmd+A: it now selects all of the table's *text* (header
  `# Name Cues` plus every row's `#`, Name, Cues) and `cmd+C` copies all of it.
  The play icon is never highlighted.
- Highlight look matches real text selection: each label draws
  `selectedTextBackgroundColor` (translucent blue) behind only its text, and the
  text keeps its normal color (no white text). Implemented per-cell because the
  shared field editor can only show one native selection at a time; this is the
  only way to show the whole table selected at once while keeping the play
  buttons and columns.
- Clicking anywhere in the table, or starting an in-cell drag-selection, clears
  the select-all highlight.
- Fonts aligned with the production search/Shiori cue text: body (Name/Cues) is
  13.5 semibold with 4pt line spacing; the index is 12 secondary; header 11
  semibold. Row-height measurement uses the same attributed text so wrapping
  stays correct.

## Outcome

Build green after the selection/font corrections. Pending the owner's re-run of
the end-to-end visual check before Phase C wires real data and playback.
