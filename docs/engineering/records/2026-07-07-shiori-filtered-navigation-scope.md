# Shiori Filtered Navigation Scope

## Human-Owned Source

- `docs/human/requirements/20260707-Bug-Shiori Filtered Navigation Scope.md`

## Scope

Align Shiori playback previous and next commands with the Shiori table result
scope used to open playback.

## Classification

- Product semantics: Shiori table playback navigation now follows the active
  table row order, including search and filter results.
- Platform UI/UX: unchanged; existing transport controls and feedback remain in
  place.
- Platform integration: Context entry points were checked and continue to route
  through Cue Context Search rather than Shiori adjacent navigation.
- Playback execution: Shiori playback still uses the existing cue playback path;
  only adjacent target resolution changes.

## Changes

- Added a Shiori playback navigation scope made of table row Shiori IDs.
- Passed the current Shiori table row order when opening playback from a Shiori
  table row.
- Changed Shiori previous and next resolution to prefer the stored table scope,
  loading scoped targets by ID from cache or SQLite as needed.
- Preserved the existing database-wide Shiori adjacent lookup when playback is
  opened without a table scope, including playback-history restoration.
- Updated product requirements to document scoped Shiori navigation behavior.
- Checked Shiori Context: `openShioriContext` opens a Cue Context Search request
  and does not call Shiori previous or next resolution.

## Verification

- `git diff --check`
- `swift test --filter shioriPlaybackNavigationUsesProvidedTableScope`
- `swift test --filter shiori`
- `swift test`

## Outcome

Shiori playback opened from a Shiori table row now keeps previous and next
navigation inside that table row scope. A filtered Shiori result no longer jumps
to an unrelated saved Shiori outside the visible result set, while unscoped
Shiori playback still uses the existing database-wide adjacent lookup.

## 2026-07-07 Playback UI Availability Follow-up

## Human-Owned Source

- `docs/human/requirements/20260707-Bug-Shiori Filtered Navigation Scope.md`

## Scope

Fix the Shiori playback-navigation implementation so player UI availability
checks do not resolve adjacent Shiori records.

## Changes

- Added a lightweight Shiori playback navigation snapshot with current,
  previous, and next Shiori IDs.
- Changed `canOpenPreviousShiori` and `canOpenNextShiori` to read the cached
  snapshot only.
- Kept full Shiori record resolution on the explicit previous/next command
  path, where a target is actually opened.
- Added regression coverage proving scoped and database-derived Shiori
  navigation availability remains available after the database is removed from
  the AppCoordinator, so hover-driven player UI rebuilds cannot depend on
  resolving adjacent targets.

## Verification

- `git diff --check`
- `swift test --filter shioriPlaybackNavigation`
- `swift test --filter Shiori`
- `swift test` (XCTest 7 tests, Swift Testing 399 tests)

## Outcome

Shiori playback UI availability now reads cached navigation IDs instead of
resolving adjacent Shiori records. Hover-driven player chrome rebuilds no longer
hit the adjacent Shiori lookup path, while explicit previous and next commands
still resolve and open the selected target.
