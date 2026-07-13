# Search, Shiori, and Context Table Row Layout and Interaction

## Human-Owned Source

- `docs/human/requirements/20260713-Feature-Search Shiori Context Table Row Layout And Interaction.md`

## Scope

Implement the accepted table update in independently verified Git steps. This
record currently covers the `Time Range` label and the shared vertical row
geometry, row interaction, clipboard foundations, and body text-selection
interaction used by Search, Shiori, and Context. It also covers the complete
shared table-text interaction and complete-result source integration through
Step 13.

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

## Step 8 Completion Audit: Stable Row Action Targets

- Froze the complete `SubtitleTableRow` when a Row Action Menu opens, so every
  menu command continues to target the right-clicked Primary Cue even if an
  asynchronous Context prepend or result reload replaces the row at that
  display index before the command is chosen.
- Routed Play, Open Subtitle Folder, Context, all row-copy commands, and Remove
  Shiori through the frozen command target, and cleared that target whenever
  the Row Action Menu closes or another menu type opens.
- Added a regression that replaces the current `rowProvider` value at the same
  index after opening the menu and verifies all seven actions still use the
  original row; it also verifies a closed menu cannot reuse the stale target.

## Step 8 Completion Audit Verification

- `swift test --filter 'subtitleTableViewRowMenuActionsKeepTheOriginalTargetAfterItsIndexChanges|subtitleTableViewUnifiedRowMenuDispatchesActionsToTheTargetRow|subtitleTable.*RowActionMenu'`
  - Passed all 6 selected Swift Testing tests.
- `swift test --filter 'subtitleTableView|subtitleTable.*RowActionMenu'`
  - Passed all 74 selected Swift Testing tests.
- `git diff --check`
  - Passed.

## Step 8 Completion Audit: Exact Ordinary Search Copy Boundary

- Required ordinary Search to reach the `.exact` count state before it can
  expose a complete-result text-copy source. An `.exactProgress` snapshot is
  still renderable, but it can no longer present its currently known rows as
  the complete Search result.
- Required the complete ordered Cue ID snapshot cardinality to match the exact
  result count when the source is created.
- Revalidated the current exact state, result count, and complete ordered Cue
  ID snapshot before and after every copy batch, so a previously captured
  source aborts if the Search boundary changes while copying.
- Added direct regression coverage for exact, empty-exact, exact-progress,
  incomplete, over-complete, and invalid result boundaries.

## Step 8 Exact Ordinary Search Copy Boundary Verification

- `swift build`
  - Passed.
- `swift test --filter 'workbenchSearchTextCopyBoundaryRequiresExactCountAndCompleteCueIDs|tableSandboxSearchRowsUseCurrentCueIDsForDistantRanges|subtitleTableViewTextCopyLoadsExactBatches'`
  - Passed all 3 selected Swift Testing tests.
- `swift test --filter 'subtitleTable|tableSandboxSearchRowsUseCurrentCueIDsForDistantRanges|cueContext|workbenchSearchTextCopyBoundaryRequiresExactCountAndCompleteCueIDs'`
  - Passed all 126 selected Swift Testing tests.
- `git diff --check`
  - Passed.

## Step 8 Completion Audit Final Verification

- `swift test`
  - Passed all 7 XCTest cases and all 609 Swift Testing tests after both audit
    fixes were combined.
- `git diff --check`
  - Passed.

## Step 9 Cursor Changes

- Removed the row Checkbox from the table's pointing-hand cursor regions while
  preserving its existing click and keyboard behavior.
- Removed the playback subtitle-focus scrollbar's pointing-hand override and
  made the shared Scrollbar Thumb explicitly register the default arrow cursor,
  preventing an overlapping interactive cell from leaking its cursor through
  the overlay without changing scrollbar drag behavior.

## Step 9 Verification

- `swift test --filter 'subtitleTableViewLimitsPointingHandToCueAndTagsContent|tableScrollbarPrimitiveRegistersArrowCursorForThumbs'`
  - Passed both selected Swift Testing tests.
- `swift test --filter 'subtitleTableView.*Cursor|tableScrollbarPrimitive|subtitleFocus.*Scrollbar'`
  - Passed all 14 selected Swift Testing tests.
- `git diff --check`
  - Passed.

## Step 10 Cue Typography Changes

- Derived a positive baseline offset from each Cue style's fixed line height
  and natural system-font line height, visually centering Primary and Extra Cue
  glyphs without changing row geometry or line wrapping.
- Kept text hit regions, selection rectangles, and underline widths unchanged;
  the custom underline follows the compensated TextKit glyph baseline.

## Step 10 Verification

- `swift test --filter 'subtitleCue|subtitleTextLayout|subtitleTableViewResolvesDocumentedDynamicRowHeightsAndPrimarySlotAlignment|subtitleTableViewUsesTallestVisibleColumnAndCentersCheckbox|subtitleTableViewExtraCueLeftAndRightHitRegionsStillTargetPrimaryRow|subtitleTableViewShowCueGroupReflowPreservesPrimaryFirstLineAndPresentationState'`
  - Passed all 19 selected Swift Testing tests.
- `git diff --check`
  - Passed.

## Step 11 Global Text Selection Clearing Changes

- Added one App-local left-mouse-down router that synchronously broadcasts the
  gesture and returns the original event unchanged, so controls keep their
  native click behavior.
- Made every attached table clear its existing text selection when that event
  occurs in any CueSeeker window. A same-gesture table drag can then establish
  a new selection, while right-click continues to preserve the old selection.
- Superseded Step 6's earlier Checkbox text-selection preservation rule to match
  the newer human-owned requirement; Checkbox batch selection remains
  independent from table text selection.

## Step 11 Verification

- `swift test --filter 'cueSeekerPointerEventRouterBroadcastsAndReturnsLeftMouseDown|subtitleTableViewAppLeftMouseDownClearsEveryAttachedTableSelection|subtitleTableViewKeepsCheckboxStateSeparateWhileCheckboxClickClearsTextSelection'`
  - Passed all 3 selected Swift Testing tests.
- `swift test --filter 'cueSeekerPointerEventRouter|subtitleTableView'`
  - Passed all 72 selected Swift Testing tests.
- `git diff --check`
  - Passed.

## Step 12 Extended Text-Drag Origin Changes

- Classified the change as platform UI/UX: SwiftUI defines the eligible
  workbench geometry, while AppKit owns pointer routing and native table text
  selection. No durable product semantics were added to presentation code.
- Made ordinary Body cell padding, Selection Column whitespace, and the blank
  viewport below a short result set arm table text selection without creating
  a selection on Mouse Down alone. The permanent 3-point drag threshold must
  be crossed before the logical selection begins.
- Preserved direct-action arbitration: Cue interactive padding and the complete
  Shiori Tags cell still suppress their click after a drag, but only an actual
  Cue or Tag text hit can become a text-selection anchor. The Checkbox body
  remains a batch-selection-only control.
- Projected non-text Body origins to the nearest logical table position, with
  short-table whitespace targeting the final actual row and an empty Body
  falling back to fixed Header text.
- Added one passive event monitor per Search/Shiori/Context shell. It returns
  every original event unchanged, arms only from measured eligible whitespace,
  and begins selection only after the gesture crosses 3 points and first
  enters the table. Once begun, selection can leave the table and retain the
  existing edge auto-scroll behavior.
- Explicitly excluded Search/Filter, Count Summary, batch actions, View,
  Sidebar, Topbar, Titlebar, table controls, and popup or confirmation layers;
  the Utility Bar spacer and page padding remain valid origins. Missing first-
  layout geometry safely disables arming instead of guessing.
- Bound the shell session weakly to the current table Coordinator, cancelled it
  for blocked, detached, replaced, or cross-window gesture lifecycles, and made
  a successful external drag give the table first-responder ownership for
  subsequent `Cmd+A` and `Cmd+C`.
- Made empty-result hints pass pointer hit testing to the table underneath.
  The table-only logical selection, complete-result `Cmd+A`, TSV/HTML copy
  structure, Checkbox selection, and right-click preservation rules are
  otherwise unchanged.

## Step 12 Verification

- `swift test --filter 'SubtitleTableExternalTextSelection|SubtitleTableVirtualRowTests|WorkbenchEmptyHintTests'`
  - Passed all 90 selected Swift Testing tests.
- Added real-window event-routing coverage for Shell-local coordinate
  conversion, eligible Utility whitespace, excluded Count/Action/View and
  table origins, table-entry transition, event completion, and another-window
  cancellation.
- Added regression coverage for ordinary padding, Selection Column whitespace,
  short and empty result bodies, Cue/Tags click-versus-drag arbitration,
  first-responder transfer, detached targets, 3-point threshold behavior,
  armed auto-scroll gating, and empty-hint pointer pass-through.
- Independent read-only review found no remaining functional blocker after the
  threshold, detached-target, empty-hint, and Shiori confirmation-boundary
  fixes.
- `swift build`
  - Passed.
- `swift test`
  - Passed all 7 XCTest cases and all 630 Swift Testing tests.
- `git diff --check`
  - Passed.

## Step 13 Semantic Text-Drag Origin Fix

- Superseded Step 12's named workbench-region measurements and component-based
  allow/exclude list. A left Mouse Down in window content outside the table is
  now eligible by default unless the actual hit surface has an interaction.
- Classified enabled native controls, editable or selectable text views,
  scrollbars, Titlebar/Topbar drag surfaces, and custom SwiftUI controls by
  their live hit semantics. Disabled controls become noninteractive origins;
  adding or moving ordinary layout content no longer requires another drag-
  origin rule.
- Limited custom-control markers to their real action surfaces, including the
  visual Header Checkbox before its cell expands. Search fields remain whole-
  field controls, while Filter control padding, Sidebar whitespace, Utility Bar
  gaps, Count Summary, and other click-inert content remain valid origins.
- Made the fixed Header route click-inert blank space through the existing
  3-point text-drag arbitration. Sort triggers and the visual Checkbox keep
  their actions, while a click without a drag on Header blank space remains a
  no-op.
- Made semantic hit resolution follow the topmost visible surface. Popover and
  confirmation blanks are passive origins, their child controls remain active,
  rounded corners fall through to the popup-dismiss surface, and a parent
  Playback cover cancels and blocks the hidden workbench table session.
- Preserved table-only selection output, complete-result `Cmd+A`, structured
  TSV/HTML copying, right-click behavior, and the rule that an external drag
  creates a selection only after entering the table.
- Stabilized the existing width-reflow integration test by explicitly hiding
  Sidebar and normalizing the real content width from 1100 to 1180 before
  asserting reflow. This removes dependence on screen-constrained initial
  `NSWindow` fitting without changing production layout or reflow behavior.

## Step 13 Verification

- `swift build`
  - Passed.
- `swift test --filter 'subtitleTableExternalTextSelection|subtitleTableTextSelectionHitTesting|subtitleTableScrollbar|subtitleTableViewHeader|widthReflowStaysWithMountedTableWhileMountedFocusRemainsStable'`
  - Passed all 21 selected Swift Testing tests.
- Added real-window coverage for Count Summary, its leading inset, Sidebar
  whitespace, Utility Bar gaps, action controls, Titlebar, table entry,
  cross-window cancellation, and parent-cover lifecycle blocking.
- Added Header coverage for trailing blank space, sort-trigger padding, the
  visual Checkbox versus surrounding blank space, and click-versus-drag
  arbitration.
- Added semantic-layer coverage for native and custom controls, disabled
  regions, rounded passive panels, popup-dismiss surfaces, and Scrollbar Thumb
  versus transparent Track hit testing.
- `swift test`
  - Passed all 7 XCTest cases and all 633 Swift Testing tests.
- `git diff --check`
  - Passed.

## Outcome

Steps 1 through 13 match their accepted outcomes. The table paths
present `Time Range`, share symmetric vertical row geometry, and use the unified
row action model and accepted mouse hit behavior. Text selection now has a
viewport-independent logical state across the fixed Header and Body, standard
select-all/copy commands, and edge auto-scroll. Structured copying preserves
visible table columns and multiline-cell boundaries for spreadsheet paste
targets without coupling text selection to Checkbox state. Complete-result
copying uses exact, immutable Search, filter-only, Context, and Shiori source
boundaries without forcing unloaded rows into the virtualized display model.
Checkboxes and scrollbars retain their default cursor while Cue and Shiori Tag
click targets keep their pointing-hand feedback. Primary and Extra Cue glyphs
are visually centered inside their fixed line-height boxes without changing
the surrounding row or selection geometry. Any CueSeeker-window left click
clears stale table text selection before the original control handles the
event, while right-click preserves the selection. Table padding and allowed
workbench whitespace can now originate a table-only drag selection. Outside
Titlebar and Topbar, this follows actual click semantics instead of a named
component list: click-inert content remains eligible as layouts evolve, while
real controls and popup-dismiss surfaces keep their actions.
