# Shiori Multi-List

## Human-Owned Source

- `docs/human/requirements/20260723-Feature-Shiori Multi-List.md`
- `docs/human/requirements/20260708-Bug-UI Refresh Scope Contract.md`
- `docs/human/design/UI.md`
- `docs/human/design/Toast Usage Registry.md`

## Scope

Implement the accepted Shiori multi-list persistence, overview and detail
workflows, list editing, row transfer actions, and shared Toast presentation on
the native macOS app.

## Step 1 Changes

- Migrated database schema 33 to 34 without dropping the existing Shiori list
  or its entries.
- Added list name, normalized name, multiline description, optional cover
  path, creation order, and the initial `Default` list metadata.
- Added list validation, create, edit, delete, ordering, and last-list deletion
  protection to `CueSeekerCore`.
- Added per-list Cue counts and CueID-deduplicated overview counts.

## Step 1 Verification

- Selected schema migration, list CRUD and validation, sorting, delete
  protection, and overview count tests passed (4 tests).
- `git diff --check` passed.

## Step 2 Changes

- Changed transitional Save Shiori behavior to use the first list in the
  documented creation-time order.
- Added explicit list-scoped Shiori save, lookup, snapshot, count, and resolved
  item queries.
- Added atomic Move and Duplicate operations. Both preserve the Shiori creation
  time and tag assignments; Move deletes the source only after the destination
  relation and tags have been written.
- Added stable errors for unavailable destinations and duplicate CueIDs in a
  destination list.

## Step 2 Verification

- Selected list-scoped save, Move, Duplicate, metadata preservation, validation,
  and existing Shiori persistence tests passed (4 tests).
- `git diff --check` passed.

## Step 3 Changes

- Generalized the centered Confirmation Dialog to support any ordered
  combination of neutral, primary, and destructive actions, including separate
  default and Cancel keyboard semantics.
- Added shared single-line and fixed-height multiline form controls with
  persistent labels, validation messages, error borders, focus rings, native
  selection, and vertical scrolling.
- Added the App Center Toast component with 5-second default duration, natural
  wrapping, documented enter/exit/reflow motion, four-visible FIFO stacking,
  individual Hover pause, App-inactive pause, and accessibility announcements.
- Added the six accepted Shiori Toast requests with their registry Scenario IDs
  and exact text.
- Reused the existing image validation, decoding, 16:9 crop editor, and JPEG
  processor for Shiori list covers, with a separate safely bounded storage
  directory.

## Step 3 Verification

- Selected Toast scenario, stack, queue, pause, and Shiori cover storage tests
  passed (4 tests).
- The full native app and test targets compiled while running the selected
  tests.
- `git diff --check` passed.

## Step 4 Changes

- Added non-persisted Shiori overview/detail route state so a list selection is
  scoped to the current app session.
- Added Shiori overview state for the ordered list summaries and deduplicated
  Cue count.
- Changed the existing Shiori table hydration path to load only its active list
  and reject stale responses after the active list changes.
- Refreshes overview counts after Shiori saves, removals, and indexed-content
  mutations.
- Kept the existing Shiori table search, filters, summary, View controls,
  columns, empty hint, and playback navigation behavior.

## Step 4 Verification

- Selected overview loading, detail routing, list-scoped table hydration,
  route-state, and existing removal tests passed (3 tests).
- The full native app and test targets compiled while running the selected
  tests.
- `git diff --check` passed.

## Step 5 Changes

- Added the Shiori overview summary, adaptive list-card grid, default and stored
  covers, count badges, fixed-height truncated metadata, and video-card context
  menu behavior.
- Added New and Edit list dialogs with inline 16:9 cover cropping, shared form
  controls, accepted validation messages, dirty-state handling, and the
  three-action Save Changes confirmation.
- Added list deletion confirmation, last-list disabled state, cover cleanup,
  and overview/detail navigation while retaining the existing detail table.

## Step 5 Verification

- Selected editor validation, dirty-state, create, edit, delete, overview, and
  cover-storage tests passed (5 tests across the Step 4 and Step 5 runs).
- The full native app and test targets compiled while running the selected
  tests.
- `git diff --check` passed.

## Step 6 Changes

- Added Shiori row-menu Move and Duplicate parents with the accepted order,
  icons, dividers, disabled state, destination ordering, current-list
  exclusion, and right-chevron submenu indicator.
- Added a connected two-panel Action Submenu with native-style delayed Hover,
  immediate click, Right Arrow, Left Arrow, Escape, outside-click, pointer
  transfer, and parent-highlight behavior.
- Connected Move and Duplicate to the atomic database operations, refreshed
  the affected list presentation, and mapped success, missing destination,
  duplicate CueID, and generic failures to the registered Toast requests.
- Initialized the transitional active Shiori list from the current
  creation-time order and updated table-mount and raw-schema tests for the new
  overview/detail and list-metadata contracts.

## Step 6 Verification

- `swift build` passed.
- Selected row-menu ordering, submenu state, original-target stability,
  transfer, Toast, list model, editor, overview, cover, and schema tests passed
  (17 tests in the final core run).
- The Cue Group mounted-surface integration suite passed (14 tests), including
  the updated Shiori overview-to-detail route.
- The Playback Subtitle Focus keyboard-action suite passed (17 tests) and the
  native media timeline suite passed (5 tests) when rerun independently.
- The full 852-test concurrent run completed with existing timing and disk-I/O
  sensitive media tests failing only under whole-suite load; the affected
  suites passed in the independent reruns above.
- `git diff --check` passed.

## Step 6 Follow-up Fix

- Moved the destination submenu into an independent host so opening it does not
  resize, reposition, or animate the parent menu.
- Read the triggering Action Menu Item's rendered frame instead of inferring
  its vertical position from row counts.
- Converted the trigger's top-down SwiftUI frame into the table container's
  bottom-up AppKit coordinates, aligned both top edges, and set the horizontal
  panel gap to zero.
- Kept the two real menu panels interactive during direct pointer transfer
  without treating the rectangular area around them as part of either menu.

## Step 6 Follow-up Verification

- The native app and test targets compiled successfully.
- Focused tests verify the rendered Move item is below the parent menu top,
  both menu edges touch, both tops align after coordinate conversion, the
  submenu receives pointer hits, the parent menu stays fixed, and direct
  pointer transfer remains open.
- `git diff --check` passed.

## Refresh Scope Follow-up

- Kept the loaded Shiori overview visible while a required full query is in
  flight and preserved the last valid snapshot if that query fails.
- Applied list create, edit, delete, Move, Duplicate, and Remove results to the
  affected list summaries instead of clearing and reloading the overview.
- Removed the redundant overview query and active-list change when returning
  from list detail.
- Removed Move and Remove results from the resident current-list projection
  without clearing the complete table.
- Marked the hidden Shiori table stale after a Playback Shiori save without
  clearing or reloading it behind the Playback surface.

## Refresh Scope Follow-up Verification

- Selected Shiori list editor, overview, transfer, database, and Playback
  Subtitle Focus tests passed (35 tests).
- The complete Cue Group refresh-scope integration suite passed (14 tests).
- Regression coverage verifies that list mutations do not return the loaded
  overview to its loading state, returning to the overview preserves the
  current list snapshot, and Move keeps the current table loaded while updating
  only the affected relation and count badges.
- `git diff --check` passed.

## Outcome

- Steps 1 through 6 implement the accepted Shiori multi-list persistence,
  overview/detail routing, list editor, cover workflow, row transfers,
  confirmations, and registered Toast behavior.
