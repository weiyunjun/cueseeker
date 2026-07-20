# Remove Legacy Playback Back Forward Navigation

## Human-Owned Requirement

- `docs/human/requirements/20260719-Feature-Remove Legacy Playback Back Forward Navigation.md`

## Classification

- Product semantics and persistence cleanup for the retired cross-source
  playback history.
- Native playback execution, current playback navigation, and presentation are
  outside this change.

## Implementation

1. Removed the App coordinator extension that recorded, traversed, and restored
   the retired Library, Search, and Shiori playback history.
2. Removed the history-recording switch from the three playback entry APIs and
   their callers. URL Scheme playback keeps the same routing and Playlist
   source while no longer passing an obsolete history-only argument.
3. Removed the history payload models, database CRUD APIs, search-index revision
   counter, and indexing-time revision writes from `CueSeekerCore`.
4. Advanced the database schema from version 30 to 31. Fresh databases no
   longer create the legacy history tables; upgraded databases drop the state
   table first and then the entries table, deleting the stored history.
5. Removed tests for the retired behavior, renamed the mixed App test file, and
   retained the playback Chrome, workbench-focus, and Shiori adjacent-navigation
   coverage that belongs to current functionality.
6. Added fresh-schema and version-30 upgrade tests that verify both legacy
   tables are absent after migration.

## Verification

- Passed eight focused tests covering fresh and upgraded database schemas,
  playback entry behavior, playback Chrome state, and current Shiori adjacent
  navigation.
- Ran `swift test --no-parallel`: all seven XCTest tests passed; the Swift
  Testing run executed 781 tests and reported one unrelated shared
  `UserDefaults` isolation failure in
  `sharedPersistenceMigrationCopiesLegacyValuesWithoutOverwritingSharedValues`.
- Reran the unrelated failing test alone; it passed.
- Confirmed the removed history types, commands, recording switch, and revision
  APIs have no remaining Swift source or test references.
- Confirmed `git diff --check` passes.

## Outcome

- The retired `/back` and `/forward` backend, persisted history, and existing
  stored data are removed.
- URL Scheme, playback Seek, Playlist, previous/next Library and Search items,
  Shiori adjacent navigation, and Subtitle Focus navigation remain available.
