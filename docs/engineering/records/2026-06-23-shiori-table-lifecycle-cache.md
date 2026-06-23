# Shiori Table Lifecycle Cache

## Human-Owned Source

- `docs/human/requirements/20260623-Feature-Shiori Table Lifecycle Cache.md`
- `docs/human/requirements/20260623-Feature-Search Shiori Table Actions And Navigation.md`

## Scope

Preserve Shiori table state for the current app session when switching between
Workbench tabs, while resetting the Shiori table to defaults on app restart.

## Classification

- Platform UI/UX: Shiori table search text, filter rules, visible columns, and
  loaded row models now share the `ShioriStore` lifetime instead of the transient
  SwiftUI view lifetime.
- Product semantics: Shiori data changes still invalidate cached table rows so
  removed or newly saved Shiori entries are not shown from stale table state.
- Performance: the Shiori table uses the same visible-page loading model as
  Search for its default view, including database-side ordering and a fixed
  first-page size.

## Changes

- Moved Shiori table controls and first-page load state into `ShioriStore`.
- Moved the Shiori table row model store into `ShioriStore` so tab remounts can
  reuse already hydrated rows without clearing the table and reloading SQLite.
- Changed the Shiori table view to load initial rows only when no cached Shiori
  table page exists.
- Invalidated cached Shiori table rows when the saved Shiori collection changes.
- Added a Shiori table page query that returns only the requested visible range
  for the default view, with display title and language metadata included in the
  same database read.
- Moved Shiori table row mapping off the main actor by doing display title,
  language, and date formatting inside the detached table load task.
- Matched Search's draft/submit behavior for Shiori table search so typing into
  the search box no longer reloads the table until the search is submitted.
- Replaced direct table reloads from the full `shioriStore.shioris` collection
  with an explicit Shiori table data revision signal.
- Added SQLite indexes for Shiori created-time ordering and cue-group language
  lookup by subtitle file/time range.
- Added tests that cover session-level Shiori table state retention and cache
  invalidation without resetting table controls.
- Added database tests that cover Shiori table search/filter paging and the
  performance indexes required by the table query.

## Verification

- `swift build` passed from `apps/macos-native`.
- `swift test` passed from `apps/macos-native` with 334 tests.

## Outcome

Switching away from Shiori and back within the same app session now restores the
loaded table rows, search draft, filter rules, and column visibility from
`ShioriStore` immediately. Real Shiori data mutations still clear the row cache
so the next table load reflects the database state. Opening Shiori without an
active search or filter now loads only the visible page instead of hydrating every
saved Shiori row on the main actor.
