# 2026-10-24 Automatic Database Compaction After Subtitle Content Mutation And Migration

## Requirement Reference
- `docs/human/requirements/20261024-Engineering-Automatic Database Compaction After Subtitle Content Mutation And Migration.md`

## Summary of Changes
1. **Schema 62 → 63 Migration Compaction**:
   - Bumped `DatabaseBootstrap.currentSchemaVersion` from `62` to `63` in `DatabaseBootstrap.swift`.
   - Added `migrateSchema62To63(on:)` in `DatabaseBootstrap+Migrations.swift` to run `PRAGMA wal_checkpoint(TRUNCATE); VACUUM; PRAGMA user_version = 63; PRAGMA wal_checkpoint(TRUNCATE);` outside explicit transactions so existing databases automatically eliminate historical search covering index page fragmentation and reclaim freelist pages on launch.
2. **Task-End Conditional Database Compaction**:
   - Added `compactStorage()` on `IndexingDatabase` and updated `removeIndexedDataInCurrentTransaction` / `publishLibraryIndex` so `SubtitleIndexingResult.changedSubtitlePaths` includes added, modified, tombstone-revived, and deleted subtitle files while excluding non-cue-mutating updates (such as `raw_cue_count` backfills, video binding refreshes, video metadata updates, cover updates, and detached tombstone reason updates).
   - Updated `AppCoordinator.runIndex` to compact the database at the end of `Index All`, `Index`, and `Add Folder` tasks if and only if `!aggregateResult.changedSubtitlePaths.isEmpty`.
   - Updated `IndexingDatabase.removeIndexedFolder` and `LibraryFolderRemovalExecutor.removeFolder` to compact the database at the end of `Remove Folder` (and unfinished `Add Folder` rollbacks) if and only if `!removal.removedSubtitlePaths.isEmpty`.
3. **Tests**:
   - Added `schema62UpgradesTo63AndCompactsDatabase()` in `DatabaseBootstrapTests.swift`.
   - Added `tasksCompactDatabaseOnlyWhenSubtitleCuesMutate()` in `LibraryFolderAdditionTests.swift`.
