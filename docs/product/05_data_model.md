# Data Model

Status: Draft

## 1. Data Model Principles

The data model should remain stable across the native rewrite.

Data should be local-first and easy to migrate. Schema changes must be explicit and documented before implementation.

## 2. Core Entities

Initial entities:

- Search path.
- Video file.
- Subtitle file.
- Subtitle-to-video match.
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

## 4. Video File

A video file represents a local media file discovered under a selected search path.

The video file is the owner of native playback compatibility metadata. Native
compatibility must not be keyed by subtitle file path or subtitle entry identity.

Expected fields:

- `id`
- `path`
- `file_size`
- `modified_at`
- `duration`
- `video_codec`
- `audio_codec`
- `native_video_candidate`
- `native_audio_candidate`
- `native_compatibility_reason`
- `native_failure_reason`
- `compatibility_evaluated_at`

Notes:

- The initial fast native compatibility inspection should use stream presence,
  codec names, and current-device hardware decode capability.
- Fast native compatibility inspection should not decode frames or start a
  playback engine during folder scanning.
- If native playback fails for a media file, the app may preserve the native
  failure reason for diagnostics and later compatibility work.
- Future audio-only playback should use the same media-file identity model.

## 5. Subtitle File

A subtitle file represents a source subtitle document discovered under a selected search path.

Expected fields:

- `id`
- `path`
- `file_size`
- `modified_at`
- `indexed_at`

Notes:

- Subtitle files are the source of truth for parsed subtitle text.
- Subtitle files must not own native playback compatibility metadata.

## 6. Subtitle-to-Video Match

A subtitle-to-video match links a subtitle file to a media file.

Expected fields:

- `subtitle_file_id`
- `video_file_id`
- `match_method`
- `confidence`
- `is_active`

Notes:

- The initial matching method may remain exact same-directory basename matching.
- Future matching may add fuzzy or manual matching without changing video-file
  native compatibility metadata.
- Search results should resolve playback through the active subtitle-to-video match.

## 7. Subtitle Entry

A subtitle entry represents one parsed subtitle block.

Fields:

- `id`
- `subtitle_file_id`
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
- Playback should resolve the target media file through the active subtitle-to-video match, not through subtitle path naming assumptions.
- The current M1 schema may still denormalize `video_path` and `video_name` on subtitle entries until a documented migration introduces first-class video files and match rows.

## 8. Index Metadata

Index metadata tracks whether a source subtitle file needs to be reindexed.

Fields:

- `srt_path`
- `file_size`
- `modified_at`
- `indexed_at`

The app may use file size and modified time for incremental indexing.

## 9. Full-Text Search

The app should use SQLite FTS5 for subtitle text search.

Expected FTS data:

- Subtitle content.
- Link from FTS row to subtitle entry.

CJK handling should preserve at least the practical behavior of the existing Flutter implementation.

## 10. Favorite

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

## 11. Schema Versioning

The native implementation must define an explicit schema versioning mechanism before writing production user data.

Schema versioning rules belong in:

```text
docs/engineering/05_database_rules.md
```

## 12. Flutter Data Compatibility

The archived Flutter implementation may contain useful existing SQLite data.

The native app should not assume compatibility until the migration strategy is documented.

Migration choices:

- Reuse existing database directly.
- Import from existing database.
- Rebuild the native database from source subtitle files.

The preferred initial strategy is to rebuild from local subtitle files unless direct compatibility is explicitly approved.
