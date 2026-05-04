# Database Rules

Status: Draft

## 1. Purpose

This document defines database engineering rules for the native macOS rewrite of CueSeeker.

Product data facts belong in `docs/product/05_data_model.md`. This document defines how the database is managed, migrated, tested, and changed.

## 2. Database Role

The native app should use SQLite with FTS5 for subtitle indexing and search
across selected local and remote media sources.

Rules:

- The database is local-first for the native rewrite.
- Remote media-source support may store non-secret remote source identity and
  derived remote index data locally, but the database must not become a remote
  sync store.
- Source subtitle files remain the source of truth for subtitle content.
- The database stores indexed subtitle entries, search metadata, and local app state needed for the product workflow.
- The database must not be treated as a remote sync store during M1.
- The database must support rebuilding indexed subtitle content from selected
  local subtitle folders and selected remote subtitle sources.
- The database must not store passwords, access tokens, Basic auth headers,
  provider playback headers, or provider-signed playback URLs in plain text.

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

Current mechanism:

- The native app uses SQLite `PRAGMA user_version`.
- The current schema version is `6`.
- Schema version `3` is the ASS cue model schema.
- Schema version `6` adds read-only WebDAV media-source identity and
  source-relative subtitle/video paths. It does not store passwords, tokens,
  Basic auth headers, provider playback headers, or signed playback URLs.

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
- Migrating from the M1 subtitle-entry model to the ASS cue model preserves
  durable user configuration while rebuilding derived subtitle index rows and
  FTS rows from source subtitle files.
- Deleting stale index rows for missing source files is part of normal indexing behavior.
- Any migration that cannot preserve favorites or other durable user state requires explicit review.

## 6. Backup and Recovery

The M1 database should be recoverable from source subtitle files for indexed content.

Rules:

- The app should tolerate deleting and rebuilding derived subtitle index data.
- Clearing all derived subtitle index data is allowed when no selected sources
  remain, because source subtitle files can recreate that data after sources are
  added again.
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

- Search paths and media source provider metadata.
- Video files.
- Subtitle files.
- Subtitle-to-video matches.
- Subtitle cue groups.
- Subtitle cue lines.
- Index metadata.
- FTS data.

Future entities:

- Favorites.

Rules:

- Row IDs may be used internally but must not be the only stable identity for future favorites.
- Remote media identity must include the selected source and provider-relative
  path. A raw HTTP playback URL is not stable identity.
- AList `raw_url` values returned by `/api/fs/get` are transient playback
  outputs and must not be stored as durable media-file identity.
- Native playback compatibility metadata is owned by the media file, not by
  subtitle cue groups, cue lines, or subtitle file paths.
- Subtitle-to-video matching must be represented separately enough that exact basename matching can later be replaced or supplemented by fuzzy or manual matching.
- Subtitle identity should preserve source subtitle path and timing information.
- SRT blocks should map to cue groups with one cue line.
- ASS `Dialogue` events should map to cue lines inside cue groups.
- ASS cue groups must use exact subtitle file, `start_ms`, and `end_ms`
  equality. The first ASS implementation must not use timestamp tolerance
  grouping.
- Cue lines must preserve source order and enough layout projection metadata to
  derive stable display order when possible.
- Indexed cue group rows must keep enough metadata to open the matched video at
  `start_ms`.
- Index metadata must allow incremental indexing based on source file metadata.

## 9. Media Native Compatibility Profile Rules

The database may cache fast native playback compatibility inspection per media file.

Rules:

- Native compatibility inspection must be keyed by media file identity, such as
  media path plus file size and modified time.
- Native compatibility inspection must not be keyed only by `srt_path`, subtitle
  entry ID, or exact subtitle-to-video filename matching.
- Folder scanning should update native compatibility metadata when the media file
  is new or its size or modified time changes.
- Fast inspection should store the native candidate result, the codec-based
  reason, and the time it was evaluated.
- If a native playback attempt later fails, the native failure reason may be
  persisted for that media file for diagnostics and compatibility work.
- Future audio-only media should use the same media-file native compatibility
  profile model.

## 10. Timestamp Rules

Subtitle timestamps must be stored in a form suitable for search result display and playback.

Rules:

- `start_ms` and `end_ms` are the canonical numeric timing fields.
- Playback seek must use `start_ms`.
- Original or formatted time strings may be stored only when useful for display or debugging.
- Timestamp parsing behavior belongs in parser tests and product requirements, not only in database code.

## 11. Path and Remote Identity Rules

Local paths and remote source identities are important user data.

Rules:

- Store enough path information to locate subtitle files and matched videos.
- Do not store paths in a format that prevents migration between database versions.
- Selected source configuration is the active search scope. Search paths stored
  in the database must be reconciled with that configuration rather than treated
  as an independent source of truth.
- Local sources may store absolute local filesystem paths.
- Remote sources must store enough non-secret source configuration to rebuild
  provider-relative file identity, such as provider type, display name, root
  URL, and source-relative path.
- Remote source rows may store Keychain references, but must not store
  passwords, access tokens, Basic auth headers, provider playback headers, or
  signed playback URLs.
- A remote media file should be identified by selected source plus
  source-relative path, size, and modified time. A transient AList `raw_url`
  must not be used as a durable identity or search-scope key.
- Do not duplicate large path lists in logs or debug tables without reason.
- If security-scoped bookmarks are needed, they should be stored as file-access metadata rather than mixed into subtitle entry rows.
- Missing local files and unavailable remote files must be handled as stale or
  unavailable data, not as database corruption.

## 12. FTS5 Rules

Full-text search must use SQLite FTS5.

Rules:

- FTS rows must be linked deterministically to subtitle cue groups.
- Searchable subtitle content must be indexed consistently with the stored cue
  group and cue lines.
- Updating or deleting cue groups or cue lines must keep FTS data consistent.
- FTS table rebuild behavior must be documented before relying on it for recovery.
- CJK search behavior must preserve at least the practical behavior of the archived Flutter implementation.

Search ranking and query syntax:

- Result ordering must be predictable.
- Empty queries must not return arbitrary rows.
- Search results must be scoped to the currently selected media sources.
- If no sources are selected, search must return no results even if stale
  database rows still exist.
- Invalid query syntax must not crash the app.
- Query limits must prevent excessive result rendering.
- Search must return cue groups, not individual ASS cue lines.
- A cue group must not match only because query terms are split across different
  cue lines. If group-level FTS recall is used, line-level filtering must enforce
  the final match semantics before results are returned.
- When any cue line in a group matches, result loading should include all cue
  lines for that group.

## 13. Indexing Consistency

Indexing must keep database state aligned with selected media sources.

Rules:

- Reindexing a changed subtitle file must replace stale cue groups and cue lines
  for that file.
- Removing a selected source must remove derived subtitle cue groups, cue lines,
  FTS rows, subtitle-file metadata, and stored search-path rows for that source.
- App startup must reconcile indexed content against the currently selected
  sources so stale rows from previously removed sources cannot remain visible.
- If no sources are currently selected, derived subtitle index data should be
  cleared or excluded from search.
- Removing or losing access to a selected source must not corrupt unrelated indexed data.
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
