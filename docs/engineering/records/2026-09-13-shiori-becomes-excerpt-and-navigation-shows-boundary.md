# Shiori becomes Excerpt and navigation shows the boundary

Human-owned documents:

- `docs/human/requirements/20260913-Feature-Shiori Becomes Excerpt And Navigation Shows Boundary.md`
- `docs/human/design/Data.md`, `docs/human/design/UI Design System.md`, `docs/human/design/UI Application Rules.md`, `docs/human/design/Icon Registry.md`, `docs/human/design/Toast Usage Registry.md`, `docs/human/design/Command Panel.md` and `docs/human/design/Cue Parsing.md` (to be updated by the owner after acceptance)

## Why

The owner renamed Shiori to Excerpt (摘录) and Shiori List to Excerpt List (摘录集), so the concept has one name in the interface, the code and the database. The same requirement asks English counts to take the singular for exactly one, and previous/next to say that the list has ended instead of "No Result", "No Library Video" and "No Bookmark".

The work lands in steps that each stay reviewable: the database tables, then the copy and the feedback, then the naming in code.

Classified as product semantics for the table names, which live in `CueSeekerCore`, and platform UI for the copy and the feedback.

## Database: schema 47

- A fresh database creates `excerpt_lists` and `excerpts`, with the indexes `idx_excerpt_lists_normalized_name`, `idx_excerpts_list_order`, `idx_excerpts_cue` and `idx_excerpts_created_order`.
- `migrateSchema46To47` drops the two Cue reference triggers, renames both tables, replaces the four indexes and recreates the triggers against `excerpts`. Rows, ids and stored cover paths are untouched. The triggers go first because a table rename re-reads every trigger that names it.
- The triggers' SQL now takes the table name. The 41 to 42 migration still creates them against `shioris`: every migration before 47 runs on a database whose table has the old name, which is also why the older migrations keep the old names.
- `ShioriDatabase` and the one query in `IndexingDatabase` that joins the table read and write the new names. The Swift type and member names wait for the naming step.

Tests:

- `migratesSchema46ByRenamingShioriTablesToExcerptTables` turns a fresh database back into a 46 one with a list, an excerpt and the old triggers, migrates it, and checks that the old tables and indexes are gone, the new ones exist, `excerpts` refers to `excerpt_lists`, the list keeps its description and cover path, the excerpt keeps its list, cue and date, and both triggers now name `excerpts`.
- `preSchema47ExcerptTablesSQL` in `DatabaseTestSupport` performs that turning back. The 41 migration test and the 39 facet count test start from it, because both begin an older migration from the current schema; the facet count test failed with `no such table: shioris` until it did.
- The 36, 37 and 38 fixtures had a two-column `shioris`, and the 38 fixture had no list table. A real database at those versions has `list_id` and `created_at` (since 35) and the list table (since before 33); the fixtures now say so, since the 47 step indexes those columns.
- Assertions on a fresh or migrated schema use the new names. Fixtures that describe an old database keep the old ones.

Files:

- `apps/macos-native/Sources/CueSeekerCore/DatabaseBootstrap.swift`
- `apps/macos-native/Sources/CueSeekerCore/ShioriDatabase.swift`
- `apps/macos-native/Sources/CueSeekerCore/IndexingDatabase.swift`
- `apps/macos-native/Tests/CueSeekerCoreTests/DatabaseBootstrapTests.swift`
- `apps/macos-native/Tests/CueSeekerCoreTests/DatabaseTestSupport.swift`
- `apps/macos-native/Tests/CueSeekerCoreTests/CueFacetCountCacheTests.swift`
- `apps/macos-native/Tests/CueSeekerCoreTests/ShioriDatabaseTests.swift`
- `apps/macos-native/Tests/CueSeekerCoreTests/SubtitleIndexerTests.swift`

## Verification

- `swift build`: clean.
- `swift test` on the working tree, with the copy and feedback step below also applied: 1208 tests, 15 failing. Thirteen are the set earlier records list as failing on the baseline as well — the seven native playback timeline, audio and presentation cases, the two Debug E2E scene and window-width cases, `shioriTableStartsAtTopAfterPanelRemount` and `showCueGroupInvalidationIsScopedToMountedShiori`, and the two library-folder-removal cases, which both pass when run on their own. `showCueGroupInvalidationIsScopedToMountedShiori` was checked rather than assumed: with this change stashed it fails at the same line on `656ec7c9`. The other two were copy assertions, updated in the next step.
- The database step's own tests — migration, fresh schema, the Excerpt database, the indexer and the facet count cache — pass.
- Before the App first opened the owner's real database, it was copied next to the live file as `CueSeeker.sqlite.backup-20260913-before-schema-47-excerpt-rename`: schema 46, 8 lists, 700 excerpts.
