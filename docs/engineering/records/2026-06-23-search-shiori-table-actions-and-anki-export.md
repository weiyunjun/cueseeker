# Search Shiori Table Actions And Anki Export

## Human-Owned Source

- `docs/human/requirements/20260623-Feature-Search Shiori Table Actions And Navigation.md`

## Scope

Implement the documented Search/Shiori table behavior, Shiori navigation
replacement, row actions, empty hints, confirmation dialog, sidebar updates, and
batch Anki export.

## Classification

- Product semantics: Shiori now uses the same table-first workflow as Search,
  with Date Added, Display Title, Cues, and Language columns.
- Platform UI/UX: Search and Shiori share the redesigned shell, virtualized
  table, column visibility menu, selection summary, neutral Anki action, row
  action menu, empty hints, and custom confirmation dialog.
- Platform integration: Shiori removal writes through the existing database and
  refreshes Shiori state; Anki export now emits Display Title subdecks inside a
  timestamped APKG.
- Playback execution: opening Search results and Shiori rows still routes into
  existing playback flows.

## Changes

- Added Date Added support to the shared virtualized subtitle table and Shiori
  row model mapping.
- Replaced the Shiori route with a table-based Shiori surface that defaults to
  all saved Shiori rows sorted by newest Date Added.
- Kept Cues locked visible while Date Added, Display Title, and Language can be
  hidden through the shared View menu.
- Added selected-row Anki export actions to Search and Shiori.
- Updated APKG export to use `CueSeeker-yyyy-MM-dd HH.mm.apkg` filenames and
  route cards into `CueSeeker::<Display Title>` decks.
- Changed Search so an empty query with no effective filters shows an empty hint
  instead of loading every cue; value-less active rules such as Cues is not
  empty still trigger filter-only results.
- Simplified Search row actions to Copy Cue Text and added Shiori row removal
  through a custom confirmation dialog.
- Updated sidebar entries to Search, Recent, Library, and Shiori; legacy Library
  persisted state now migrates to Search.
- Added a database helper for Shiori cue-group languages and an AppCoordinator
  Shiori removal entry point.
- Added layout-state test coverage for the legacy Library route migration.
- Reworked the Shiori table data path so opening Shiori no longer hydrates the
  full `ShioriStore` list into table rows. The table now loads the first visible
  page, hydrates additional pages from visible-row callbacks, and prunes
  hydrated Shiori rows with the same bounded-row strategy used by Search.
- Added Shiori database paging ordered by newest Date Added, with batched
  language lookup for rows in the requested page.
- Updated Shiori playback, removal, and selected-row Anki export to resolve
  actions from hydrated row metadata and to page in missing selected rows before
  export.
- Reduced the shared Search/Shiori table hydration page size from 240 rows to
  50 rows, and made initial loads plus selected-row export backfill use the same
  page-size constant.
- Fixed Shiori playback navigation and playback-history restoration so the new
  virtualized Shiori table does not need to hydrate the full `ShioriStore`.
  Restore now loads the target Shiori by id from SQLite, and previous/next
  navigation loads the adjacent Shiori by the Date Added sort order.
- Updated the Shiori row action menu item text from `Remove` to
  `Remove Shiori`, while keeping the confirmation dialog action text as
  `Remove`.

## Verification

- `swift build` passed.
- `swift test` passed with 325 tests.
- Follow-up Shiori table hydration fix:
  - `swift build` passed.
  - `swift test` passed with 328 tests.
- Follow-up Search/Shiori hydration page-size fix:
  - `swift build` passed.
  - `swift test` passed with 329 tests.
- Follow-up Shiori navigation and row menu bug fixes:
  - `swift build` passed.
  - `swift test` passed with 330 tests.

## Outcome

The Search and Shiori surfaces now share the same table-based workflow while
preserving Shiori playback and Anki export behavior. Search no longer eagerly
loads all cues without an explicit search term or effective filter.

The Shiori table now applies virtualization before row-model materialization:
default Shiori opening requests only the first page from SQLite instead of
mapping every saved Shiori row and querying languages one row at a time. Search
or filter criteria on Shiori can still evaluate the full saved set locally, but
the default all-favorites view no longer performs that work on first screen.

Search and Shiori now share a 50-row table hydration page size. Very tall
viewports can request a second page after visible-row reporting, but normal
first-screen data hydration no longer loads up to 240 rows by default.

Shiori playback controls and playback-history restoration now use targeted
SQLite lookups instead of requiring a full in-memory Shiori list. This preserves
the virtualized table data path while keeping Shiori previous/next and restored
navigation available after a fresh launch.
