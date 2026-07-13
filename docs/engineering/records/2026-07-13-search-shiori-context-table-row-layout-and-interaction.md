# Search, Shiori, and Context Table Row Layout and Interaction

## Human-Owned Source

- `docs/human/requirements/20260713-Feature-Search Shiori Context Table Row Layout And Interaction.md`

## Scope

Implement the accepted table update in independently verified Git steps. This
record currently covers the `Time Range` label and the shared vertical row
geometry used by Search, Shiori, and Context.

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

## Outcome

Steps 1 and 2 match the accepted requirement. The table paths present
`Time Range`, preserve the internal `time` identity, and now share symmetric
vertical row geometry without coupling other columns to the Primary Cue line.
