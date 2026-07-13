# Search, Shiori, and Context Table Row Layout and Interaction

## Human-Owned Source

- `docs/human/requirements/20260713-Feature-Search Shiori Context Table Row Layout And Interaction.md`

## Scope

Implement the accepted table update in independently verified Git steps. This
record currently covers the `Time Range` label and the shared vertical row
geometry, row interaction, clipboard foundations, and body text-selection
interaction used by Search, Shiori, and Context. It also covers the complete
shared table-text interaction and complete-result source integration through
Step 8.

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

## Step 6 Changes

- Added TextKit UTF-16 hit testing and selection geometry, including composed
  glyph boundaries for emoji and other multi-code-unit characters.
- Mapped ordinary body text, multi-item Cue text, and Tag labels into one
  ordered logical table-text document while preserving their visual fragments.
- Added cross-cell and cross-row body dragging with a permanent 3-point drag
  threshold; Cue playback and the Shiori Tags popover now wait for mouse-up and
  are suppressed after a drag begins.
- Kept Checkbox clicks and right-click Row Action Menus independent from the
  table-text selection, and cancelled pending left-click actions when a menu
  opens.
- Added exact selectable-text I-beam regions while retaining pointing-hand
  regions for Cue, Shiori Tags, and Checkbox interactions.
- Limited selection redraws to visible rows whose selection projection changed,
  kept the no-selection drawing path allocation-light, and fixed fallback Cue
  fragment mapping so the Primary Cue is always retained.

## Step 6 Verification

- `swift build`
  - Passed.
- `swift test --filter 'subtitleTextLayout|subtitleTableView|subtitleTableTextSelection'`
  - Passed all 73 selected Swift Testing tests.
- Added regression coverage for forward and reverse cross-cell dragging,
  Checkbox and right-click selection preservation, Cue and Tag click-versus-drag
  arbitration, clipped long-Tag focus, UTF-16 glyph boundaries, selection redraw
  locality, and missing Cue measurement fallback.
- `git diff --check`
  - Passed.

## Step 7 Changes

- Added a fixed Header text-selection overlay that shares the Body selection
  model while preserving existing Header controls, hover behavior, and menu
  click semantics below the permanent 3-point drag threshold.
- Added standard AppKit responder actions for `Cmd+A` and `Cmd+C`; table select
  all covers every visible Header and Body text cell without changing Checkbox
  selection, while active text inputs keep their normal first-responder scope.
- Added selection-aware structured copying that preserves every visible column,
  leaves unselected cells empty, emits tab-separated rows for spreadsheet
  alignment, and keeps displayed Cue Groups inside one multiline cell.
- Added an optional exact-range async row loader for full-result copying, with
  512-row batches, exact-count validation, task cancellation, and pasteboard
  change-count protection against overwriting newer user content.
- Added horizontal and vertical drag-edge auto-scroll with fixed-Header/Body
  focus projection, viewport clamping, dynamic-row reflow, and lightweight
  Header frame synchronization during horizontal scrolling.

## Step 7 Verification

- `swift build`
  - Passed.
- `swift test --filter 'subtitleTableClipboard|subtitleTableView|subtitleTableTextSelection|subtitleTextLayout'`
  - Passed all 89 selected Swift Testing tests.
- Added regression coverage for Header dragging and menu arbitration,
  Header/Body crossing, Header side/top overflow, responder select-all,
  structured partial and all-result copying, exact loader batches, pasteboard
  races, and drag-edge auto-scroll geometry and viewport movement.
- `git diff --check`
  - Passed.

## Step 8 Changes

- Separated the virtualized display row count from the complete-result text-copy
  row count. `Cmd+A` uses the complete boundary and exact async loader, while
  ordinary drag selections continue to use the displayed `rowProvider`; this
  preserves Context window-local row indexes.
- Connected ordinary Search, filter-only Search, and Context to their existing
  paged database loaders, with Context routed first and loaded from stable
  source index zero using `anchorsInitialPage: false`.
- Snapshotted Search query, filters, folders, language, watch scope, total count,
  and complete ordered Cue IDs. Every copy batch validates the complete Cue ID
  snapshot plus exact range, row count, and total count before contributing any
  clipboard content.
- Connected Shiori copying to immutable submitted-search and filter snapshots,
  exact page validation, and the existing Shiori row mapping including Date
  Added, Cue Group, Language, and Shiori Tags.
- Persisted the filtered Shiori result count in `ShioriStore` so partially
  hydrated results retain their complete boundary across view suspension or
  remount, while reload and data invalidation clear the boundary.
- Added data-revision and reload-generation checks so an in-flight Shiori copy
  cannot combine rows from different result snapshots.

## Step 8 Verification

- `swift build`
  - Passed.
- `swift test --filter 'subtitleTable|tableSandboxSearchRowsUseCurrentCueIDsForDistantRanges|cueContext'`
  - Passed all 124 selected Swift Testing tests.
- `swift test --filter 'shiori|Shiori'`
  - Passed all 38 selected Swift Testing tests.
- `swift test`
  - Passed all 7 XCTest cases and all 607 Swift Testing tests.
- Added regression coverage proving a one-row displayed prefix can copy 513
  complete results in exact batches, partial drag copying never calls the
  full-result loader, and Shiori remount state preserves its filtered result
  count while invalidation clears it.
- `git diff --check`
  - Passed.

## Outcome

Steps 1 through 8 match their accepted outcomes. The table paths
present `Time Range`, share symmetric vertical row geometry, and use the unified
row action model and accepted mouse hit behavior. Text selection now has a
viewport-independent logical state across the fixed Header and Body, standard
select-all/copy commands, and edge auto-scroll. Structured copying preserves
visible table columns and multiline-cell boundaries for spreadsheet paste
targets without coupling text selection to Checkbox state. Complete-result
copying uses exact, immutable Search, filter-only, Context, and Shiori source
boundaries without forcing unloaded rows into the virtualized display model.
