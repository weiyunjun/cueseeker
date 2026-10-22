# 2026-10-22 Split Oversized Core Indexing Search And Bootstrap Database Files

## Requirement Reference
- `docs/human/requirements/20261022-Engineering-Split Oversized Core Indexing Search And Bootstrap Database Files.md`

## Summary of Changes
1. **Sub-step 4A — Split `IndexingDatabase.swift` (4,023 Lines) and Relocated Test-Only Queries**:
   - `SubtitlePlaybackFinishMetadata.swift` (107 lines): Extracted pure ASS playback finish metadata calculation (`PlaybackFinishCueGroup`, `playbackFinishMetadata(format:cueGroups:)`).
   - `IndexingDatabase+LibraryHierarchy.swift` (599 lines): Extracted Library root path binding and folder hierarchy operations (`addSearchPath`, `adoptNestedLibraries`, `separateNestedLibrary`, `moveLibraryContent`, `upsertLibraryFolder`, `deleteLibraryFolders`, `backfillMediaPathIdentities`).
   - `IndexingDatabase+TombstoneReconciliation.swift` (732 lines): Extracted video tombstone and Excerpt (Shiori) cue reference reconciliation (`snapshotVideoTombstoneIfNeeded`, `restoreVideoTombstoneIfNeeded`, `reconcileExcerptListRecentCues`, `adoptTombstones`, `snapshotReferencedCues`, `recomputeTombstoneUnavailableReasons`, `cue_change_notices`).
   - `Tests/CueSeekerCoreTests/IndexingDatabase+TestInspection.swift` (288 lines): Relocated read-only test inspection methods with zero production callers out of `Sources/CueSeekerCore/IndexingDatabase.swift`.
   - `IndexingDatabase.swift` (2,310 lines): Retained core index publication, subtitle cue group/line/FTS/ASS segment/font persistence, search-order-row materialization, and cascade deletion.
2. **Sub-step 4B — Split `DatabaseBootstrap.swift` (1,783 Lines) into Schema Definition and Historical Migrations**:
   - `DatabaseBootstrap.swift` (758 lines): Retained `DatabaseBootstrap`, current schema v58 DDL (`prepareSchema`), schema inspection helpers, and migration entry point.
   - `DatabaseBootstrap+Migrations.swift` (1,025 lines): Extracted historical step-by-step schema migrations (`migrateSchema33To34` through `migrateSchema57To58`).

## Verification
- Verified `swift build --package-path apps/macos-native` and `IndexingDatabaseTests` / `SubtitleIndexerTests` / `LibraryDatabaseTests` / `ExcerptDatabaseTests` / `SubtitleLanguageDatabaseTests` / `DatabaseBootstrapTests` pass with 0 errors.
