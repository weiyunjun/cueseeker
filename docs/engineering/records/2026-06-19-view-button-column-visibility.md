# View Button Column Visibility

Human requirement:

- `docs/human/requirements/20260619-Feature-View Button Feature.md`

## Scope

This record covers the Test Search 2 View button column visibility feature.

## Implementation Notes

- Added a column visibility menu model that derives items from the current
  workbench column configuration.
- Excluded the checkbox/index column from the View menu.
- Kept the Cues column visible, checked, and disabled in the View menu.
- Routed visible columns from `SchemaWorkbenchSearchShell` into
  `WorkbenchTestSearch2View` instead of ignoring the shell callback value.
- Extended `SubtitleTableView` so Display Title, Speaker, and Language column
  visibility affects the shared table layout, header hosts, row drawing, text
  lookup, horizontal content width, and hover button positioning.
- Kept Cues as the fixed visible text column so cue playback and row action
  controls keep a stable anchor.
- Clamped the horizontal scroll offset after content width changes so hiding
  right-side columns cannot leave the header, body, or scrollbar thumb offset
  beyond the new content bounds.
- Follow-up: after the human requirement corrected the fourth menu item from
  `Title` to `Language`, restored the `language` column display title and menu
  test expectation to `Language`.

## Virtualization And Scrollbar Constraints

- No row materialization path was added.
- `visibleRowRange(in:)` and `drawRowsNow(in:)` still render only the current
  viewport plus the existing overscan.
- `SubtitleVirtualRowHeightCache` remains fixed-height and is not invalidated
  by column visibility changes.
- The redesign scrollbar overlay still derives horizontal visibility from
  `documentView.frame.size` and the viewport size after `resizeDocument()`.

## Verification

Commands run from `apps/macos-native/`:

```text
swift test --filter 'SchemaWorkbench|SubtitleTable'
swift test --quiet
```

Results:

- Column visibility menu model excludes checkbox/index and locks Cues.
- Hidden Display Title remaps text lookup so Cues remains the first data column.
- Hiding optional columns shrinks document width, hides the horizontal
  scrollbar when content fits, and clamps horizontal offset to zero.
- Focused table virtualization tests passed.
- Full test run passed 307 Swift Testing tests and 7 XCTest CASS rendering
  tests. The run also printed the existing playback history disk I/O warning.
