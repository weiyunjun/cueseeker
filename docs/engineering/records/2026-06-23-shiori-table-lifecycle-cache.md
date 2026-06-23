# Shiori Table Lifecycle Cache

## Human-Owned Source

- `docs/human/requirements/20260623-Feature-Shiori Table Lifecycle Cache.md`

## Scope

Preserve Shiori table state for the current app session when switching between
Workbench tabs, while resetting the Shiori table to defaults on app restart.

## Classification

- Platform UI/UX: Shiori table search text, filter rules, visible columns, and
  loaded row models now share the `ShioriStore` lifetime instead of the transient
  SwiftUI view lifetime.
- Product semantics: Shiori data changes still invalidate cached table rows so
  removed or newly saved Shiori entries are not shown from stale table state.

## Changes

- Moved Shiori table controls and first-page load state into `ShioriStore`.
- Moved the Shiori table row model store into `ShioriStore` so tab remounts can
  reuse already hydrated rows without clearing the table and reloading SQLite.
- Changed the Shiori table view to load initial rows only when no cached Shiori
  table page exists.
- Invalidated cached Shiori table rows when the saved Shiori collection changes.
- Added tests that cover session-level Shiori table state retention and cache
  invalidation without resetting table controls.

## Verification

- `swift build` passed.
- `swift test` passed with 332 tests.

## Outcome

Switching away from Shiori and back within the same app session now restores the
loaded table rows, search draft, filter rules, and column visibility from
`ShioriStore` immediately. Real Shiori data mutations still clear the row cache
so the next table load reflects the database state.
