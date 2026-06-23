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

## Verification

- `swift build` passed.
- `swift test` passed with 325 tests.

## Outcome

The Search and Shiori surfaces now share the same table-based workflow while
preserving Shiori playback and Anki export behavior. Search no longer eagerly
loads all cues without an explicit search term or effective filter.
