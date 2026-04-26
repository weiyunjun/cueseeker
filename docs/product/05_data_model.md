# Data Model

Status: Draft

## 1. Data Model Principles

The data model should remain stable across the native rewrite.

Data should be local-first and easy to migrate. Schema changes must be explicit and documented before implementation.

## 2. Core Entities

Initial entities:

- Search path.
- Subtitle entry.
- Index metadata.
- Favorite.

Favorites are not required for M1 but should be considered when designing identity stability.

## 3. Search Path

A search path represents a local folder selected for subtitle indexing.

Fields:

- `id`
- `type`
- `path`
- `created_at`
- `updated_at`

Initial supported `type`:

- `local`

Remote path types are deferred.

## 4. Subtitle Entry

A subtitle entry represents one parsed subtitle block.

Fields:

- `id`
- `video_path`
- `video_name`
- `srt_path`
- `seq`
- `start_time`
- `end_time`
- `start_ms`
- `end_ms`
- `content`

Notes:

- `start_ms` is the primary timestamp used for playback seek.
- `end_ms` is useful for future current-line highlighting and favorites.
- `srt_path` and timing fields are part of stable identity.

## 5. Index Metadata

Index metadata tracks whether a source subtitle file needs to be reindexed.

Fields:

- `srt_path`
- `file_size`
- `modified_at`
- `indexed_at`

The app may use file size and modified time for incremental indexing.

## 6. Full-Text Search

The app should use SQLite FTS5 for subtitle text search.

Expected FTS data:

- Subtitle content.
- Link from FTS row to subtitle entry.

CJK handling should preserve at least the practical behavior of the existing Flutter implementation.

## 7. Favorite

Favorites are deferred until M3.

Expected fields:

- `id`
- `srt_path`
- `start_ms`
- `end_ms`
- `video_path`
- `video_name`
- `content`
- `is_valid`
- `created_at`

Favorite identity should be based on source subtitle path and time range, not on volatile row IDs.

## 8. Schema Versioning

The native implementation must define an explicit schema versioning mechanism before writing production user data.

Schema versioning rules belong in:

```text
docs/engineering/05_database_rules.md
```

## 9. Flutter Data Compatibility

The archived Flutter implementation may contain useful existing SQLite data.

The native app should not assume compatibility until the migration strategy is documented.

Migration choices:

- Reuse existing database directly.
- Import from existing database.
- Rebuild the native database from source subtitle files.

The preferred initial strategy is to rebuild from local subtitle files unless direct compatibility is explicitly approved.

