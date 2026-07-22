# Database Architecture Decomposition

Status: Accepted

## Human-Owned Source

- `docs/human/requirements/20260722-Engineering-Subtitle Database Refactor And Schema 33 Baseline.md`

## Background

`SubtitleDatabase.swift` currently combines SQLite schema creation, historical
migrations, connection ownership, subtitle indexing writes, Search query
planning and execution, Library projections, playback history, Shiori, tags,
subtitle focus, language metadata, ASS render metadata, AI chunk caching, and
storage maintenance. Its public models and operations are consumed directly by
the app, indexing, playback, benchmarks, and import tools.

The project has one active owner and no released database compatibility
obligation. Schema 33 is therefore the new minimum supported database and the
baseline for this decomposition. Supporting schema 1 through 32 would retain a
large historical migration surface without serving an active user.

## Goals

- Remove `SubtitleDatabase` as a cross-domain God Object.
- Keep database product semantics inside `CueSeekerCore` while separating
  migration, indexing, Search, Library, Shiori, playback-subtitle data, AI
  cache, and maintenance responsibilities.
- Make SQLite connection and transaction ownership explicit.
- Ensure ordinary readers cannot create or migrate the production database.
- Keep current schema-33 data and product behavior unchanged.
- Delete obsolete schema 1-through-32 migration and compatibility code.
- Reduce production code where obsolete wrappers, duplicate setup, and dead
  cache interfaces can be removed without adding replacement abstractions.

## Non-goals

- Do not change the schema-33 table or column layout during this refactor.
- Do not add a Rust implementation, FFI, ORM, generic query builder, or remote
  storage layer.
- Do not redesign Search, Library, Shiori, playback, indexing, or AI behavior.
- Do not silently delete an incompatible database.
- Do not keep a permanent forwarding facade after callers move to the new
  domain boundaries.

## Schema Compatibility Decision

- `PRAGMA user_version = 33` is the minimum and current supported schema at the
  start of this refactor.
- Version `0` means an empty database and creates the complete schema-33
  baseline.
- Version `33` opens without running historical migrations.
- Versions `1...32` are unsupported and fail with a clear incompatibility
  error. Recovery is an explicit backup-and-rebuild operation, not silent
  deletion.
- Versions greater than the current implementation are rejected so an older
  application cannot downgrade schema metadata.
- Future schema changes may add explicit migrations beginning at `33 -> 34`.
  They do not restore support for schema 1 through 32.

## Target Boundaries

The first implementation remains in the Swift `CueSeekerCore` target and keeps
one SQLite database file.

```text
Persistence
  Database bootstrap and schema validation
  Current schema creation
  SQLite connection and transaction execution
  Storage maintenance

Indexing
  Subtitle, video, Cue, language, speaker, FTS, and derived-projection writes

Search
  Search models, pure query planning, paging, navigation, and diagnostics

Library
  Library projections, playback history, watch state, and covers

Shiori
  Shiori relations, lists, tags, paging, and navigation

Playback Subtitle Data
  Cue timing, Subtitle Focus, ASS render segments, and ASS font references

AI Cache
  AI chunk cache keys, values, reads, writes, and invalidation
```

The app shell depends on the smallest relevant domain interface. Playback
rendering receives a playback-subtitle data provider or already-resolved data;
it does not receive a database path and does not open or migrate SQLite.

## Connection And Transaction Ownership

- Schema creation and version validation run only through database bootstrap.
- One serialized writer owns write transactions.
- A transaction boundary covers the complete logical write and cannot be
  interleaved with another operation on the same connection.
- Read-heavy feature work uses read-only connections or feature-owned reader
  sessions that never call migration code.
- Low-level SQLite connections are not exposed as cross-feature public state.
- `BEGIN`, `COMMIT`, and `ROLLBACK` are centralized in the persistence layer.
- WAL, busy timeout, synchronous mode, cache size, and mmap configuration remain
  consistent with the accepted database rules.

## Derived Projection Ownership

- Indexing owns transactional replacement of subtitle-derived content.
- Search owns `subtitle_search_order_rows` and FTS query behavior.
- Library owns `library_video_rows` and Library presentation projections.
- AppCoordinator must not call public rebuild methods for these tables after
  ownership has moved into the responsible persistence workflow.
- Existing schema-33 derived tables remain in place during this refactor. A
  later schema simplification requires a separate human-owned requirement.

## Implementation Sequence

1. Record this accepted plan and schema-33 minimum-support rule.
2. Replace the historical migration runner with fresh-schema creation and
   strict schema-33 validation; delete obsolete migration tests and helpers.
3. Establish bootstrap, connection, and transaction ownership.
4. Extract Search models, pure query planning, and SQLite Search operations.
5. Extract Library and Shiori models and SQLite operations.
6. Extract indexing persistence and internalize derived-projection rebuilds.
7. Remove direct database construction and migration from playback code.
8. Extract AI cache and maintenance operations.
9. Remove the old `SubtitleDatabase` type and split tests by domain.

Each implementation step must remove the superseded code in the same change.
Temporary duplicate implementations and permanent compatibility forwarding are
not accepted.

## Verification

- Fresh database creation produces schema 33.
- An existing schema-33 fixture opens without schema or data mutation.
- Schema 1 through 32 fixtures are rejected.
- A schema version greater than the current version is rejected without
  changing `user_version`.
- Search, Library, Shiori, indexing, playback-subtitle, AI cache, and
  maintenance tests pass through their new boundaries.
- Concurrent readers and indexing writes use separate, documented connection
  ownership without ordinary lock failures.
- `CueSeekerPlayback` contains no database path, SQLite open, or migration call.
- The final source tree contains no `SubtitleDatabase` type or permanent
  forwarding facade.
- Full Swift tests and the existing Search benchmark build pass.

## Risks

- Moving SQL and row decoding can change column ordering or binding order even
  when schema and behavior are intended to remain stable.
- Index replacement crosses Cue, Shiori, Search, and Library derived state and
  must preserve its current transaction semantics.
- Changing connection ownership can expose hidden assumptions about synchronous
  AppCoordinator calls or concurrent detached tasks.

These risks are controlled by moving one domain at a time, preserving existing
fixtures, and committing only complete, independently testable stages.

## Decision

Proceed with the staged decomposition above. Schema 33 is the compatibility
floor, current schema, and behavioral data baseline. The architecture refactor
must simplify ownership and delete obsolete code; file splitting without domain
ownership changes is insufficient.
