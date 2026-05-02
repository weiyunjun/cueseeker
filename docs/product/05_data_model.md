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
- Subtitle cue group.
- Subtitle cue line.
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

Notes:

- Selected folder configuration is the source of truth for active local search
  scope.
- Database search-path rows and indexed subtitle rows are derived local index
  state and must be reconciled with the selected folder configuration.
- Removing a selected folder must remove or exclude derived index data under
  that folder while preserving the local files on disk.

## 4. Video File

A video file represents a local media file discovered under a selected search path.

The video file is the owner of native playback compatibility metadata. Native
compatibility must not be keyed by subtitle file path or subtitle cue group identity.

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
- `format`
- `file_size`
- `modified_at`
- `indexed_at`

Notes:

- Subtitle files are the source of truth for parsed subtitle text.
- Subtitle files must not own native playback compatibility metadata.
- Initial supported formats are `srt` and `ass`.
- Playback should load the source subtitle file associated with the selected
  search result. The database stores a searchable projection, not a replacement
  subtitle renderer.

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

## 7. Subtitle Cue Group

A subtitle cue group represents one searchable subtitle moment in one source
subtitle file.

For SRT, a cue group usually maps to one SRT block and contains one cue line.

For ASS, a cue group maps to all searchable `Dialogue` events in the same source
subtitle file with the exact same `start_ms` and `end_ms`. This keeps bilingual
or multi-line ASS moments as one search result. Near-equal ASS timestamps are
not grouped by tolerance in the first implementation.

Fields:

- `id`
- `subtitle_file_id`
- `subtitle_path`
- `seq`
- `start_time`
- `end_time`
- `start_ms`
- `end_ms`
- `search_content`

Notes:

- `start_ms` is the primary timestamp used for playback seek.
- `end_ms` is useful for future current-line highlighting and favorites.
- `subtitle_path` and timing fields are part of stable identity.
- `search_content` is the aggregated searchable text from the group's cue lines.
- Playback should resolve the target media file through the active subtitle-to-video match, not through subtitle path naming assumptions.
- The current M1 schema may still use `srt_path`, `video_path`, and `video_name`
  on subtitle rows until a documented migration introduces first-class video
  files, match rows, cue groups, and cue lines.

## 8. Subtitle Cue Line

A subtitle cue line represents one displayable/searchable line inside a cue
group.

Fields:

- `id`
- `cue_group_id`
- `event_index`
- `source_format`
- `source_style`
- `source_layer`
- `start_time`
- `end_time`
- `start_ms`
- `end_ms`
- `content`
- `display_x`
- `display_y`
- `display_order`

Notes:

- `content` stores clean searchable/display text, not raw ASS override tags.
- `event_index` preserves source order inside the subtitle file.
- `source_style` stores ASS style names such as `Dial_JP`, `Dial_CH`,
  `Screen`, `Title`, `Staff`, `ED_JP`, or `ED_CH` when available.
- `source_layer` stores the ASS `Layer` field when available. Layer is render
  stacking information, not vertical position.
- `display_x`, `display_y`, and `display_order` are derived layout fields for
  search result presentation. They help order grouped results to approximate
  the subtitle's on-video placement.
- Cue lines must not be deduplicated during indexing. If an ASS file contains
  several `Dialogue` events with the same text and timing, all of them should be
  retained until a future explicit product rule defines a safe display-only
  folding behavior.

## 9. ASS Layout Projection

ASS layout projection is intentionally approximate and exists for search result
ordering, not for subtitle rendering.

Expected derivation inputs:

- Script resolution, such as `PlayResX` and `PlayResY`.
- Style alignment and margins.
- Event margins.
- Inline alignment override, such as `\an7`.
- Inline position or movement overrides, such as `\pos(...)` and `\move(...)`.
- Source event order.

Rules:

- Sort grouped cue lines from top to bottom when `display_y` can be derived.
- Use `display_x` as a secondary order when useful.
- Use `event_index` as the stable fallback.
- Do not use ASS `Layer` as a substitute for vertical position.
- Do not attempt to infer visual duplicates during indexing.

## 10. Index Metadata

Index metadata tracks whether a source subtitle file needs to be reindexed.

Fields:

- `subtitle_path`
- `file_size`
- `modified_at`
- `indexed_at`

The app may use file size and modified time for incremental indexing.

## 11. Full-Text Search

The app should use SQLite FTS5 for subtitle text search.

Expected FTS data:

- Cue group search content.
- Link from FTS row to subtitle cue group.

CJK handling should preserve at least the practical behavior of the existing Flutter implementation.

Search results must be scoped to the currently selected local subtitle folders.
FTS rows outside that active folder scope are stale derived index data and must
not appear in user-facing search results.

If an ASS cue group contains multiple languages or styles with the same timing,
FTS should return the cue group once when any contained cue line matches. The
search result should then load all cue lines for that group and display them in
`display_order`.

A cue group must not match only because query terms are split across different
cue lines. The search implementation may use cue group content for recall, but
it must ensure that at least one cue line satisfies the query semantics before a
group is returned.

## 12. Favorite

Favorites are deferred until M3.

Expected fields:

- `id`
- `subtitle_path`
- `start_ms`
- `end_ms`
- `video_path`
- `video_name`
- `content`
- `is_valid`
- `created_at`

Favorite identity should be based on source subtitle path and time range, not on
volatile row IDs. When cue groups are available, favorites should target cue
groups rather than individual ASS lines unless the product explicitly adds
line-level favorites.

## 13. Schema Versioning

The native implementation must define an explicit schema versioning mechanism before writing production user data.

Schema versioning rules belong in:

```text
docs/engineering/05_database_rules.md
```

The ASS cue model migration may preserve durable user configuration such as
selected folders and playback settings while rebuilding derived subtitle index
data from source subtitle files.

## 14. Flutter Data Compatibility

The archived Flutter implementation may contain useful existing SQLite data.

The native app should not assume compatibility until the migration strategy is documented.

Migration choices:

- Reuse existing database directly.
- Import from existing database.
- Rebuild the native database from source subtitle files.

The preferred initial strategy is to rebuild from local subtitle files unless direct compatibility is explicitly approved.
