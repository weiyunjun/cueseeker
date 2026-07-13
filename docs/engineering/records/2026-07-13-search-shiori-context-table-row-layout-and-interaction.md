# Search, Shiori, and Context Table Row Layout and Interaction

## Human-Owned Source

- `docs/human/requirements/20260713-Feature-Search Shiori Context Table Row Layout And Interaction.md`

## Scope

Implement the accepted table update in independently verified Git steps. This
record currently covers the `Time Range` label and the shared vertical row
geometry, row interaction, and text-selection/clipboard foundations used by
Search, Shiori, and Context.

## Step 1 Changes

- Updated the shared Search and Shiori column schema titles.
- Updated Search, Shiori, and shared table header fallback values.
- Updated direct tests for column visibility, virtual table headers, and copied
  TSV headers.

## Verification

- `swift build`
  - Passed.
- `swift test --filter 'schemaWorkbenchColumnVisibilityMenuLocksCuesAndSkipsCheckboxColumn|schemaWorkbenchColumnVisibilityMenuUsesShioriColumnOrder|subtitleTableClipboardCopiesHeadersAndExpandsCueLines|subtitleTableClipboardCopiesCrossHourTimeRangeWithFullFormat|subtitleTableViewMapsTextColumnsWhenDisplayTitleIsHidden|subtitleTableViewUsesExplicitColumnOrderForTextColumns'`
  - Passed all 6 selected Swift Testing tests.
- Exact-string source scan for `"Time"` in the macOS App sources and tests.
  - No remaining exact `"Time"` table label was found.
- `git diff --check`
  - Passed.

## Step 2 Changes

- Replaced aggregate Extra Cue line geometry with per-Cue-Item measurement so
  the documented 8-point spacing is applied between Cue Items, not between
  wrapped or source lines inside one Cue.
- Made row height use the tallest complete visible-column content block plus
  equal 8-point top and bottom padding.
- Centered Cue blocks, metadata, Display Title, complete Tag blocks, and the
  row-selection Checkbox independently within the final row height.
- Reused the same Cue Item and Tag block geometry for drawing and content hover
  hit regions.
- Matched interactive-cell vertical hover padding to row padding and expanded
  height-cache invalidation to all height-affecting row content.

## Step 2 Verification

- `swift build`
  - Passed.
- `swift test --filter 'subtitleCue|subtitleTableViewResolvesDocumentedDynamicRowHeights|subtitleTableViewUsesTallestVisibleColumn|subtitleTableRowHeightCache|subtitleTableHeightInvalidation'`
  - Passed all 20 selected Swift Testing tests.
- `swift test --filter 'subtitleTableView|subtitleTableHover|subtitleCue'`
  - Passed all 59 selected Swift Testing tests.
- `git diff --check`
  - Passed.

## Step 3 Changes

- Added a pure unified Row Action Menu model with stable action identifiers,
  accepted user-facing labels, symbols, ordering, and divider placement.
- Kept Search and Context on the same action sequence and added the separated
  `Remove Shiori` action only for Shiori.
- Kept `Copy Cue Group Text` conditional on `Show Cue Group`.
- Left the existing menu presentation and mouse hit regions unchanged until the
  next integration step.

## Step 3 Verification

- `swift build`
  - Passed.
- `swift test --filter 'subtitleTable.*RowActionMenu|subtitleTableRowActionMetadata'`
  - Passed all 4 selected Swift Testing tests.
- `git diff --check`
  - Passed.

## Step 4 Changes

- Integrated the unified Row Action Menu model into the table presentation so
  every non-Selection data cell opens the same row menu over its full cell area.
- Replaced column-specific left-click actions with the accepted direct actions:
  Cue text plays, the complete Shiori Tags cell opens its popover, and only the
  visible Checkbox body changes row selection.
- Removed hover emphasis and pointing-hand cursor regions from plain Display,
  metadata, Speaker, and Language text while retaining exact interactive
  regions for the Checkbox, Cue text, and Shiori Tags cell.
- Routed all unified menu actions to the existing play, folder, Context, copy,
  and Shiori-removal callbacks, including `Open Subtitle Folder` and `Copy Time
  Range`.

## Step 4 Verification

- `swift build`
  - Passed.
- `swift test --filter 'subtitleTableView|subtitleTable.*RowActionMenu|subtitleTableRowActionMetadata'`
  - Passed all 58 selected Swift Testing tests.
- `git diff --check`
  - Passed.

## Step 5 Changes

- Added an independent table-text selection state with Header/Body document
  positions, visible-column ordinals, UTF-16 offsets, directional anchor/focus,
  normalized ranges, safe per-cell range projection, explicit selected-empty
  cell structure, and an O(1) logical all-results sentinel.
- Reworked structured table copying so each source result remains one table row
  and source newlines remain inside their original cell.
- Added quoted TSV encoding for embedded tabs, newlines, and quotes, plus HTML
  table and native tabular-text representations on one pasteboard item.
- Switched the existing Search and Shiori batch table-copy paths to the new
  structured pasteboard representations; single-cell Row Action Menu copying
  remains plain text.

## Step 5 Verification

- `swift build`
  - Passed.
- `swift test --filter 'subtitleTableClipboard|subtitleTableTextSelection'`
  - Passed all 15 selected Swift Testing tests.
- `git diff --check`
  - Passed.

## Outcome

Steps 1 through 5 match their accepted intermediate outcomes. The table paths
present `Time Range`, share symmetric vertical row geometry, and use the unified
row action model and accepted mouse hit behavior. Text selection now has a
viewport-independent logical state, and structured copying preserves table and
multiline-cell boundaries for spreadsheet paste targets.
