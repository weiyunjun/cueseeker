# Remove Shiori Tags — Step 1

## Requirement

- `docs/human/requirements/20260729-Feature-Workbench Playback And Command Panel Shared UI.md`
- Step 1: remove Shiori Tags from the UI, interactions, state, Core API,
  database structure, and tests, and clear existing Tag data through migration.

## Scope

- Removed the Shiori Tags table column, popover, commands, clipboard path, and
  row projection.
- Removed Shiori Tag state and public persistence models and operations.
- Advanced the database to schema version 41, removed Tag tables from fresh
  schema creation, and dropped the legacy tables during migration.
- Updated engineering rules, migration coverage, UI interaction coverage, and
  the changelog. Human-owned documents, including `docs/human/design/UI.md`,
  were not modified.

## Steps

1. Removed the Shiori-specific Tag presentation and interaction path while
   retaining the shared language Badge representation.
2. Removed Shiori Tag ownership from application and Core state, including
   move and duplicate propagation.
3. Added the schema-40-to-41 destructive Tag-data migration and fresh-schema
   exclusions.
4. Removed obsolete Tag tests and changed database tests to verify migration
   cleanup and fresh-schema absence.

## Verification

- `swift build`: passed.
- `swift test`: all targets compiled. The full 890-test parallel run reported
  15 issues in media-timeline timing and temporary-database operations; the two
  affected Shiori-save tests passed when rerun in isolation.
- `swift test --filter DatabaseBootstrapTests`: 16 tests passed.
- `swift test --filter ShioriDatabaseTests`: 13 tests passed.
- `swift test --filter SubtitleTableVirtualRowTests`: 86 tests passed.
- The isolated row-model, clipboard, height-cache, and schema-workbench group:
  57 tests passed.
- The two Shiori-save tests affected by the full-suite temporary-database
  failures: 2 tests passed in isolation.
- `git diff --check`: passed.
- Source audit found no remaining Shiori Tag API, state, popover, column, or
  interaction references outside historical migration and migration-test SQL.

## Outcome

- Step 1 matched the requirement. Shiori Tags no longer exist in active UI,
  state, or Core behavior, and schema version 41 removes their persisted data.
