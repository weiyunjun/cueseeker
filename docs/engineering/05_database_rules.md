# Database Rules

Status: Draft

## 1. Purpose

This document defines database engineering rules for the native macOS rewrite of SubFinderX.

Product data facts belong in `docs/product/05_data_model.md`. This document defines how the database is managed, migrated, tested, and changed.

## 2. Database Role

The native app should use SQLite with FTS5 for local subtitle indexing and search.

Rules:

- The database is local-only for the early native rewrite.
- Source subtitle files remain the source of truth for subtitle content.
- The database stores indexed subtitle entries, search metadata, and local app state needed for the product workflow.
- The database must not be treated as a remote sync store during M1.
- The database must support rebuilding indexed subtitle content from selected local subtitle folders.

## 3. Database File Location

The final database file location must be documented before production user data is written.

Rules:

- The database must live in an app-owned local storage location.
- The database must not be stored inside the source repository.
- The database must not be stored inside user-selected subtitle folders.
- The app must have a clear distinction between production database files and test fixture database files.
- If sandboxing is enabled, the location must be compatible with macOS sandbox container rules.

The exact path may be finalized with the native app project setup.

## 4. Schema Versioning

The native database must use an explicit schema versioning mechanism.

Rules:

- Every production database schema must have a schema version.
- Schema creation and migration order must be deterministic.
- A fresh install must create the same final schema as applying all migrations in order.
- Schema version updates must be committed with migration notes.
- Schema changes must update `docs/product/05_data_model.md` before implementation depends on them.

Recommended mechanism:

- Use SQLite `PRAGMA user_version` or a dedicated metadata table.

The final mechanism must be documented in the native database implementation notes when implementation begins.

## 5. Migration Rules

Migrations must be explicit and reviewable.

Rules:

- Migrations must run in ascending version order.
- Migrations must be idempotent at the migration-runner level.
- Migrations should run inside transactions when SQLite supports the required operations safely.
- Failed migrations must not leave the database pretending to be at the target schema version.
- Migration errors must be surfaced clearly enough for debugging.
- Production migrations must not rely on test-only data.

Destructive migrations:

- Dropping user-owned data requires an ADR.
- Rebuilding derived index data is allowed when source subtitle files can recreate it.
- Deleting stale index rows for missing source files is part of normal indexing behavior.
- Any migration that cannot preserve favorites or other durable user state requires explicit review.

## 6. Backup and Recovery

The M1 database should be recoverable from source subtitle files for indexed content.

Rules:

- The app should tolerate deleting and rebuilding derived subtitle index data.
- Durable user state, such as configured folders and future favorites, must not be casually discarded.
- Before destructive schema changes to durable user state, the project must define backup or recovery expectations.
- Corrupt database handling should prefer clear error reporting and rebuild options over silent data loss.

## 7. Flutter Database Compatibility

The archived Flutter implementation may contain useful schema and behavior references.

Rules:

- The native app must not assume direct compatibility with the archived Flutter database.
- The preferred initial strategy is to rebuild the native database from source subtitle files.
- Importing or reusing the Flutter database requires a documented migration strategy.
- Direct Flutter database compatibility requires an ADR if production implementation depends on it.

## 8. Core Tables and Data Ownership

The database should support the product entities described in `docs/product/05_data_model.md`.

Expected early entities:

- Search paths.
- Video files.
- Subtitle files.
- Subtitle-to-video matches.
- Subtitle entries.
- Index metadata.
- FTS data.

Future entities:

- Favorites.

Rules:

- Row IDs may be used internally but must not be the only stable identity for future favorites.
- Playback backend preference is owned by the media file, not by subtitle entries or subtitle file paths.
- Subtitle-to-video matching must be represented separately enough that exact basename matching can later be replaced or supplemented by fuzzy or manual matching.
- Subtitle identity should preserve source subtitle path and timing information.
- Indexed subtitle rows must keep enough metadata to open the matched video at `start_ms`.
- Index metadata must allow incremental indexing based on source file metadata.

## 9. Media Backend Profile Rules

The database should cache fast playback backend preselection per media file.

Rules:

- Backend preselection must be keyed by media file identity, such as media path plus file size and modified time.
- Backend preselection must not be keyed only by `srt_path`, subtitle entry ID, or exact subtitle-to-video filename matching.
- Folder scanning should update backend preselection when the media file is new or its size or modified time changes.
- Fast preselection should store the selected backend, the codec-based reason, and the time it was evaluated.
- If a native playback attempt later fails and falls back to `libmpv`, the fallback result may be persisted for that media file so later selections do not repeat the same failed native attempt.
- Future audio-only media should use the same media-file backend profile model.

## 10. Timestamp Rules

Subtitle timestamps must be stored in a form suitable for search result display and playback.

Rules:

- `start_ms` and `end_ms` are the canonical numeric timing fields.
- Playback seek must use `start_ms`.
- Original or formatted time strings may be stored only when useful for display or debugging.
- Timestamp parsing behavior belongs in parser tests and product requirements, not only in database code.

## 11. Path Rules

Local paths are important user data.

Rules:

- Store enough path information to locate subtitle files and matched videos.
- Do not store paths in a format that prevents migration between database versions.
- Do not duplicate large path lists in logs or debug tables without reason.
- If security-scoped bookmarks are needed, they should be stored as file-access metadata rather than mixed into subtitle entry rows.
- Missing files must be handled as stale or unavailable data, not as database corruption.

## 12. FTS5 Rules

Full-text search must use SQLite FTS5.

Rules:

- FTS rows must be linked deterministically to subtitle entries.
- Searchable subtitle content must be indexed consistently with the stored subtitle entry.
- Updating or deleting subtitle entries must keep FTS data consistent.
- FTS table rebuild behavior must be documented before relying on it for recovery.
- CJK search behavior must preserve at least the practical behavior of the archived Flutter implementation.

Search ranking and query syntax:

- Result ordering must be predictable.
- Empty queries must not return arbitrary rows.
- Invalid query syntax must not crash the app.
- Query limits must prevent excessive result rendering.

## 13. Indexing Consistency

Indexing must keep database state aligned with selected folders.

Rules:

- Reindexing a changed subtitle file must replace stale entries for that file.
- Removing or losing access to a selected folder must not corrupt unrelated indexed data.
- Source files that cannot be read should be skipped with diagnostics.
- Stale entries for subtitle files that no longer exist should be removed during refresh.
- Indexing progress should be trackable without requiring UI-specific database state.

## 14. Test Data and Fixtures

Database tests must use controlled test data.

Rules:

- Test databases must not reuse the user's production database.
- Fixtures should live under a dedicated test fixture location once the native project exists.
- Fixtures should include valid SRT files, malformed SRT blocks, missing video matches, and CJK subtitle content.
- Migration tests should verify both fresh schema creation and migration from previous schema versions.
- Tests may create temporary database files, but they must clean up or isolate them.

## 15. Change Process

Any database schema change must follow this order:

```text
Update product data model if behavior or entity shape changes
Update database rules or migration notes if process changes
Add or update migration
Add or update tests
Verify fresh database creation
Verify migration from previous version
Commit as a reviewable change
```

Rules:

- Schema changes must not be hidden only inside implementation code.
- Migrations and tests should be reviewed together.
- Destructive or hard-to-reverse schema changes require an ADR.
