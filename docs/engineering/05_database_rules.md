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

## 3.2 SQLite Storage Maintenance

CueSeeker stores rebuildable subtitle index data in SQLite, so large delete and
rebuild cycles can leave inactive pages on SQLite's freelist. Freelist pages are
valid SQLite state, but they still occupy disk space until the database is
compacted.

Rules:

- The first accepted maintenance pass is observability plus manual compaction.
  Automatic compaction and `auto_vacuum=INCREMENTAL` are deferred until there is
  enough operational evidence to define safe trigger conditions.
- Storage stats must expose the main database file size, WAL size, SHM size,
  SQLite page size, page count, freelist page count, auto-vacuum mode,
  estimated used bytes, reclaimable freelist bytes, and freelist ratio.
- Settings should expose storage stats in a Maintenance category so users and
  developers can see whether disk usage is active data or reclaimable SQLite
  freelist space.
- A manual `Compact Database` action may reclaim freelist space by checkpointing
  WAL, running `VACUUM`, and checkpointing WAL again.
- Manual compaction must not run while CueSeeker is indexing, searching, or
  loading Library data through app-owned tasks.
- Manual compaction should check available disk space before `VACUUM` when the
  platform can report it, because SQLite may need temporary space while
  rebuilding the database file.
- Compaction errors must be surfaced to the Settings UI rather than silently
  ignored.
- The current compaction recommendation threshold is at least `100 MiB` of
  reclaimable freelist space and a freelist ratio of at least `25%`.

## 4. Schema Versioning

The native database must use an explicit schema versioning mechanism.

Rules:

- Every production database schema must have a schema version.
- Schema creation and migration order must be deterministic.
- A fresh install must create the complete current schema. Every supported
  future migration path must produce that same final schema.
- Schema version updates must be committed with migration notes.
- Schema changes must update `docs/product/05_data_model.md` before implementation depends on them.

Recommended mechanism:

- Use SQLite `PRAGMA user_version` or a dedicated metadata table.

Current mechanism:

- The native app uses SQLite `PRAGMA user_version`.
- The implemented schema version is `33`.
- Schema version `33` adds durable user-selected video and folder cover
  overrides.
- Schema `33` is the minimum supported native database and the baseline for the
  database architecture decomposition. Native schemas `1...32` are no longer
  opened or migrated by the active app.
- Version `0` creates the complete current schema. Version `33` opens without
  historical migration work. Any unsupported lower version or version greater
  than the current implementation must be rejected without changing its
  `user_version`.
- Schema version `3` is the ASS cue model schema.
- Schema version `6` rebuilds derived cue-group FTS rows using Han and
  Japanese kana segmentation so pure kana queries can match existing indexed
  subtitle content.
- Schema version `7` added ASS font-resource manifests for an external font
  cache path that is now deprecated. New indexing and playback code must not
  populate, rebuild, or consume those manifests for external font resources.
- Schema version `8` adds Library playback history for durable resume
  positions keyed by video path.
- Schema version `9` adds persisted Library presentation rows so startup can
  hydrate the left Library panel from a ready indexed snapshot instead of
  regrouping and resorting subtitle/video match rows.
- Schema version `10` adds Shiori subtitle-cue records keyed by
  `subtitle_path`, `start_ms`, and `end_ms`, including real-world `created_at`
  save timestamps.
- Schema version `11` adds a denormalized `line_count` column to
  `subtitle_cue_groups`. It lets Search skip the cue-lines lookup for groups
  with a single cue line (the common SRT case) and apply line-level validation
  directly to the group's `search_content`. The migration backfills existing
  rows from `subtitle_cue_lines` counts.
- Schema version `12` adds `subtitle_search_order_rows` as rebuildable derived
  Search ordering data. It stores subtitle display order so Search can report
  and reuse materialized order diagnostics instead of treating display-title
  derivation as hidden hot-path work.
- Schema version `23` adds video width, video height, and frame-rate metadata to
  `video_files` so Library episode rows can render indexed video metadata
  without opening media during view rendering.
- Schema version `25` backfills durable Library watch states from Library
  playback history so the Library can render watch state without deriving it
  from resume-position rows in view code.
- Schema version `26` adds durable Shiori tag tables: `shiori_tags` for the
  global tag pool and `shiori_tag_assignments` for many-to-many Shiori/tag
  associations. Tag deletion cascades assignments but must not delete Shiori
  records.
- Schema version `27` adds Library display-cover rendition fields while
  preserving the master-cover reference.
- Schema version `28` changes Shiori uniqueness from Cue Group timing to
  individual Cue identity using subtitle path, source event index, and Cue
  timing. The migration preserves Shiori IDs, creation timestamps, and tag
  assignments; resolvable legacy rows prefer a Japanese Cue and use the
  physically bottommost eligible Cue as the deterministic tie-break and
  fallback. Unindexed rows remain durable with unresolved Cue identity.
- Schema version `29` adds permanent indexed-resource identity columns and the
  Shiori-to-Cue binding used by CueID routing.
- Schema version `30` makes the current single-list Shiori-to-Cue binding
  globally unique.
- Schema version `31` removes obsolete persisted playback navigation tables.
- Schema version `32` creates a default Shiori list, reduces `shioris` to
  relation-owned fields, requires a valid CueID, and enforces uniqueness on
  `(list_id, cue_id)`. It is governed by ADR-0014.

## 5. Migration Rules

Migrations must be explicit and reviewable.

Rules:

- Historical native schema migrations from versions `1...32` are retired. The
  active implementation must not retain their migration SQL, backfills, or
  runtime compatibility branches.
- An unsupported database must produce a clear incompatibility error. The app
  must not silently delete it; backup and rebuild are explicit recovery steps.
- Future migrations, when required, start from the schema-33 baseline and run
  in ascending version order.
- Migrations must run in ascending version order.
- Migrations must be idempotent at the migration-runner level.
- Migrations should run inside transactions when SQLite supports the required operations safely.
- Failed migrations must not leave the database pretending to be at the target schema version.
- Migration errors must be surfaced clearly enough for debugging.
- Production migrations must not rely on test-only data.
- Code must not add private runtime fallbacks for old or malformed data under
  the assumption that compatibility might be useful later. If old data needs to
  be handled, the need must be stated explicitly, the affected data class must
  be identified as durable user state or rebuildable derived data, and the
  chosen handling must be documented before implementation.
- Rebuildable derived data should normally be repaired by an explicit migration,
  maintenance action, or one-off development script, not by keeping hidden
  compatibility branches in Search, playback, indexing, or UI hot paths.
- Any compatibility fallback that remains in code must have a documented reason,
  a test that exercises the accepted old-data case, and a removal condition
  unless it is permanent product behavior.

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
- Legacy ASS font resource manifests.
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
- ASS font-resource manifests are legacy derived index data from the deprecated
  external font cache path. They may remain in older databases for migration
  compatibility, but new code must not write, rebuild, or read them as playback
  inputs.
- Database schema must not be used to justify scanning, copying, caching, or
  indexing non-supported local file types. Current indexing is limited to
  supported video files and `.srt`/`.ass` subtitle files.
- Library playback history is durable local user state. It should be keyed by
  stable video identity, persist resume position and update timestamp, and must
  not be rebuilt from subtitle index data.
- Search-result playback must not read or mutate Library playback history.
- Shiori persistence is relation state, not a Cue-content snapshot. A Shiori
  relation stores ShioriID, CueID, list identity, and creation time. Tags remain
  separate relation-owned assignments keyed by ShioriID.
- The initial relation schema contains one default list. It permits the same
  CueID in different lists while preventing duplicate relations for one CueID
  inside the same list.
- Shiori database reads must join or batch-resolve canonical indexed Cue data;
  they must not reconstruct content from historical Shiori path, timing, or
  text columns.

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
- Search returns individual Cue lines as product results.
- A Cue must not match only because query terms are split across different cue
  lines. Group-level FTS recall may remain an indexing optimization, but
  line-level filtering must independently validate every returned Cue.
- Optional Cue Group presentation loads the other lines for the same group only
  after the primary Cue identity is known. It must not change result counts,
  ordering, selection, playback, Context, Shiori, copy-Cue, or export identity.
- Matched cue lines must map deterministically to their source group and stable
  source order. Multiple matching Cues in the same time window remain distinct
  results.
- Search ordering should prefer materialized product-order keys over
  per-query reconstruction when practical. The intended stable order is Library
  block rank, subtitle-file rank within that block, then cue time.
- Search-summary counts and file/group summaries should not block first visible
  results if the query engine can return ordered results before the whole corpus
  is searched.
- English prefix search is a required scenario. If FTS prefix indexes are added,
  the chosen prefix lengths must be documented with benchmark data and storage
  impact.
- Query/result cache should be implemented only after the accepted search
  semantics and ordering are stable. Cache keys must include the normalized
  query, search scope, index generation, and search algorithm version.

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
