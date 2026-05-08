# Database Rules

Status: Draft

## 1. Purpose

This document defines database engineering rules for the native macOS rewrite of CueSeeker.

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

## 3.1 SQLite Connection And Locking

SQLite connection configuration is part of the native app's reliability model.

Rules:

- Every app-owned SQLite connection must configure a non-zero busy timeout so
  short-lived read/write contention does not immediately surface to the user as
  `database is locked`.
- The production app database should use WAL journal mode unless a future
  documented storage constraint requires a different mode.
- WAL should be paired with a synchronous setting appropriate for local app
  cache and durable app state. Any future change to this durability/performance
  tradeoff must be documented before implementation depends on it.
- Read-heavy operations such as Library hydration, Search queries, playback
  metadata reads, and ASS render-segment reads must be able to coexist with
  indexing writes without making ordinary user actions fail immediately.
- Write-heavy operations such as `Index Now` should cancel or avoid app-owned
  background read tasks when practical before starting indexing, so CueSeeker
  does not create avoidable lock contention with itself.
- Long indexing transactions should remain scoped to the smallest practical
  unit of indexed replacement work. They should not cover file scanning,
  subtitle parsing, media probing, or other slow non-SQL work.
- Large ASS render-segment rows are valid derived cache data and are not, by
  themselves, a reason to treat the database as corrupt or oversized. Locking
  fixes should address connection and transaction behavior rather than deleting
  valid derived cache rows.
- User-visible database lock errors should be treated as bugs in connection,
  timeout, or workflow coordination unless the database is held by an external
  process for longer than the configured timeout.

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
- The current schema version is `10`.
- Schema version `3` is the ASS cue model schema.
- Schema version `6` rebuilds derived cue-group FTS rows using Han and
  Japanese kana segmentation so pure kana queries can match existing indexed
  subtitle content.
- Schema version `7` adds ASS font-resource manifests so the index stage can
  record prepared external font cache status for `libass` playback.
- Schema version `8` adds Library playback history for durable resume
  positions keyed by video path.
- Schema version `9` adds persisted Library presentation rows so startup can
  hydrate the left Library panel from a ready indexed snapshot instead of
  regrouping and resorting subtitle/video match rows.
- Schema version `10` adds Shiori subtitle-cue records keyed by
  `subtitle_path`, `start_ms`, and `end_ms`, including real-world `created_at`
  save timestamps.

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
- Any migration that cannot preserve Shiori or other durable user state requires explicit review.

Derived index decoupling:

- Search paths, subtitle files, video files, cue groups, cue lines, FTS rows,
  ASS render segments, ASS font-resource manifests, and Library presentation
  metadata are rebuildable local index data.
- Library presentation metadata should be materialized during indexing or
  explicit Library refresh. App startup should read it as a snapshot and must
  not derive folder grouping, display titles, or row order from subtitle/video
  joins in the hot path.
- Library playback history is durable local user state and must survive folder
  removal, re-add, and reindex when the same video identity is available again.
- Shiori records and future queues and learning-session records are durable user state.
  Their current resource binding may be stale or unavailable, but the
  user-authored record must not be deleted merely because an indexed file row is
  missing.
- Rebinding a folder after a path rename should update index bindings where
  practical instead of requiring durable user state to be recreated.

## 6. Backup and Recovery

The M1 database should be recoverable from source subtitle files for indexed content.

Rules:

- The app should tolerate deleting and rebuilding derived subtitle index data.
- Clearing all derived subtitle index data is allowed when no selected folders
  remain, because source subtitle files can recreate that data after folders are
  added again.
- Durable user state, such as configured folders, Library playback history, and
  Shiori records, must not be casually discarded.
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
- Subtitle cue groups.
- Subtitle cue lines.
- Index metadata.
- ASS font resource manifests.
- FTS data.
- Library playback history.

Future entities:

- Shiori.

Rules:

- Row IDs may be used internally but must not be the only stable identity for Shiori.
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
- ASS font-resource manifests are derived index data keyed by subtitle file and
  matched video file. They may store a prepared font cache directory, a resource
  signature, a preparation status, an error message for diagnostics, and the
  preparation timestamp.
- ASS font-resource manifests must be rebuildable from source subtitle files,
  matched video files, adjacent conventional font folders, and supported
  container attachments. They must not become durable user-authored data.
- Library playback history is durable local user state. It should be keyed by
  stable video identity, persist resume position and update timestamp, and must
  not be rebuilt from subtitle index data.
- Search-result playback must not read or mutate Library playback history.
- Shiori records are durable local user state. The initial Shiori table should
  use `subtitle_path`, `start_ms`, and `end_ms` as the stable cue identity,
  persist `subtitle_format`, `video_path`, `video_name`, `content`, and
  `created_at`, and avoid duplicate rows for the same saved cue identity.

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

## 11. Path Rules

Local paths are important user data.

Rules:

- Store enough path information to locate subtitle files and matched videos.
- Do not store paths in a format that prevents migration between database versions.
- Selected folder configuration is the active search scope. Search paths stored
  in the database must be reconciled with that configuration rather than treated
  as an independent source of truth.
- Do not duplicate large path lists in logs or debug tables without reason.
- If security-scoped bookmarks are needed, they should be stored as file-access metadata rather than mixed into subtitle entry rows.
- Missing files must be handled as stale or unavailable data, not as database corruption.

## 12. FTS5 Rules

Full-text search must use SQLite FTS5.

Rules:

- FTS rows must be linked deterministically to subtitle cue groups.
- Searchable subtitle content must be indexed consistently with the stored cue
  group and cue lines.
- Updating or deleting cue groups or cue lines must keep FTS data consistent.
- FTS table rebuild behavior must be documented before relying on it for recovery.
- CJK search behavior must preserve at least the practical behavior of the archived Flutter implementation.
- Japanese hiragana, katakana, and halfwidth katakana must be segmented for FTS
  phrase matching so pure kana queries can match indexed subtitle text.

Search ranking and query syntax:

- Result ordering must be predictable.
- Empty queries must not return arbitrary rows.
- Search results must be scoped to the currently selected subtitle folders.
- If no folders are selected, search must return no results even if stale
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

Indexing must keep database state aligned with selected folders.

Rules:

- Reindexing a changed subtitle file must replace stale cue groups and cue lines
  for that file.
- Removing a selected folder must remove derived subtitle cue groups, cue lines,
  FTS rows, subtitle-file metadata, and stored search-path rows for that folder.
- App startup must reconcile indexed content against the currently selected
  folders so stale rows from previously removed folders cannot remain visible.
- If no folders are currently selected, derived subtitle index data should be
  cleared or excluded from search.
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
