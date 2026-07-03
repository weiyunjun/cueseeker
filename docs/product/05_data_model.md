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
- ASS font resource manifest.
- Shiori.

Shiori is not required for M1 but should be considered when designing identity stability.

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
  that folder while preserving the local files on disk and durable user state
  that may reference those files.

## 4. Derived Index Decoupling

CueSeeker should separate durable user state from rebuildable local indexes.

Rules:

- Derived index data may become stale when folders are removed, renamed,
  reindexed, or temporarily unavailable.
- Index staleness must not by itself delete durable user state such as Library
  playback history, Shiori records, future queues, or learning-session records.
- User-authored state should keep stable file or cue identity where practical,
  while the current binding to indexed rows remains a refreshable lookup.
- When an indexed resource referenced by durable user state is missing,
  CueSeeker should surface an unavailable, invalid, or unbound state rather than
  silently deleting the user state.
- Folder replacement or path repair should be treated as rebinding an index, not
  recreating unrelated user state.

## 5. Video File

A video file represents a local media file discovered under a selected search path.

The video file is the owner of native playback compatibility metadata. Native
compatibility must not be keyed by subtitle file path or subtitle cue group identity.

Expected fields:

- `id`
- `path`
- `file_size`
- `modified_at`
- `duration`
- `video_width`
- `video_height`
- `frame_rate`
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
- Library rows should use video file identity and duration from indexed video
  metadata. Reindexing is the expected refresh path when older indexed rows do
  not have duration metadata.
- The indexed video metadata needed to render the Library list is persistent
  local derived-index state. The app should hydrate the Library list from this
  metadata during startup before the first visible main-window render, rather
  than treating the list as transient async UI state.
- Library playback history should be keyed by video file identity and persist a
  resume position for Library-opened playback only. Search-result playback
  should not read or mutate this history.
- If native playback fails for a media file, the app may preserve the native
  failure reason for diagnostics and later compatibility work.
- Future audio-only playback should use the same media-file identity model.

## 6. Subtitle File

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

## 7. Subtitle-to-Video Match

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

## 8. Subtitle Cue Group

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
- `end_ms` is useful for future current-line highlighting and Shiori.
- `subtitle_path` and timing fields are part of stable identity.
- `search_content` is the aggregated searchable text from the group's cue lines.
- Playback should resolve the target media file through the active subtitle-to-video match, not through subtitle path naming assumptions.
- The current native schema uses first-class subtitle files, video files,
  subtitle-to-video matches, cue groups, and cue lines. The older M1
  `srt_path`-centered subtitle-entry index is treated as rebuildable derived
  data during migration.

## 9. Subtitle Cue Line

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
- The database cue projection is not the playback render timeline. It may omit
  raw override tags and non-searchable visual-effect details from FTS-oriented
  fields, while source ASS playback rendering must preserve timed source events
  through the source file or a dedicated render cache.

## 10. ASS Layout Projection

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

## 11. Index Metadata

Index metadata tracks whether a source subtitle file needs to be reindexed.

## 11.1 Search Result Thumbnail Cache

Search result thumbnails are local derived cache artifacts, not canonical
database rows.

Rules:

- Thumbnail files should be stored in the app's cache directory, not in SQLite.
- Thumbnail lookup should prefer memory cache, then persistent disk cache, then
  generation from the source video file.
- The first thumbnail test format is `160x90` AVIF generated by `ffmpeg`.
- The cache identity should include source video path, source video file size or
  modified time, cue-group identity, midpoint timestamp, thumbnail dimensions,
  image format, and cache version so changed source media does not silently
  reuse stale preview frames.
- Cached thumbnails may be deleted by cache cleanup or the operating system
  without changing indexed subtitle or video identity.

Fields:

- `subtitle_path`
- `file_size`
- `modified_at`
- `indexed_at`

The app may use file size and modified time for incremental indexing.

ASS font resource manifests are legacy derived index metadata from a deprecated
external font cache path. They may remain in older databases for migration
compatibility, but current playback must not consume them and current indexing
must not rebuild them.

Fields:

- `subtitle_file_id`
- `video_file_id`
- `status`
- `fonts_directory`
- `resource_signature`
- `error_message`
- `prepared_at`

Notes:

- The manifest was keyed by subtitle file and matched video file.
- `fonts_directory` must not be used as a playback input.
- New code must not scan, copy, cache, index, or materialize external font
  resources to populate this metadata.
- Playback uses the source subtitle file and system-installed fonts instead of
  this manifest.

## 12. Full-Text Search

The app should use SQLite FTS5 for subtitle text search.

Expected FTS data:

- Cue group search content.
- Link from FTS row to subtitle cue group.

Han and Japanese kana handling should preserve the practical CJK behavior of
the existing Flutter implementation while also allowing pure hiragana,
katakana, and halfwidth katakana queries to match indexed subtitle text.

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

## 13. Shiori

Shiori stores saved subtitle cues for later review.

Expected fields:

- `id`
- `subtitle_path`
- `subtitle_format`
- `start_ms`
- `end_ms`
- `video_path`
- `video_name`
- `content`
- `is_valid`
- `created_at`

The initial native table should be named `shioris`.

`created_at` stores the real-world timestamp when the user saved the Shiori
record. The initial Shiori panel does not need to display this timestamp, but the
field must be persisted when the record is created.

Shiori identity should be based on source subtitle path and time range, not on
volatile row IDs. When cue groups are available, Shiori should target cue groups
rather than individual ASS lines unless the product explicitly adds line-level
Shiori records.

Creating Shiori for a subtitle cue that already has a matching
`subtitle_path`, `start_ms`, and `end_ms` should be treated as an existing
record rather than creating a duplicate row.

A Shiori record is durable user state. Its current resolved link to
an indexed subtitle cue, video file, or Library row is derived index state. If
the indexed resource disappears, the Shiori record should remain and show an invalid
or unavailable resource state until the index is rebuilt or repaired.

## 14. Schema Versioning

The native implementation must define an explicit schema versioning mechanism before writing production user data.

Schema versioning rules belong in:

```text
docs/engineering/05_database_rules.md
```

Current native schema:

- Schema version: `23`.
- Uses SQLite `PRAGMA user_version`.
- Version 3 introduces the ASS cue model with `subtitle_files`,
  `video_files`, `subtitle_video_matches`, `subtitle_cue_groups`,
  `subtitle_cue_lines`, and cue-group FTS data.
- The version 3 migration preserves durable configuration such as selected
  folders and playback settings while rebuilding derived subtitle index data
  from source subtitle files.
- Version 6 rebuilds derived cue-group FTS rows from stored cue-group
  `search_content` using Han and Japanese kana segmentation. It does not drop
  durable user configuration.
- Version 7 added ASS font-resource manifests for index-stage `libass` external
  font preparation. That external font cache path is now deprecated; the schema
  remains only for migration compatibility and does not authorize current code
  to scan or materialize external font resources.
- Version 8 adds Library playback history for Library-opened resume behavior.
  It does not drop derived index rows or durable user configuration.
- Version 9 adds persisted Library presentation rows so startup can hydrate the
  Library panel from an indexed snapshot.
- Version 10 adds persisted Shiori subtitle-cue records keyed by subtitle path
  and cue time range. It preserves Shiori rows when indexed folder content is
  removed or rebuilt.
- Version 11 adds a denormalized `line_count` column to `subtitle_cue_groups`
  so Search can skip the per-candidate `subtitle_cue_lines` lookup for
  groups with a single cue line (the common SRT case) and apply line-level
  validation directly to the group's `search_content`. The column is derived
  index data: it is backfilled from `subtitle_cue_lines` counts during
  migration and written by indexing.
- Version 23 adds video width, video height, and frame-rate metadata to
  `video_files` so Library episode rows can render indexed video metadata
  without opening media during view rendering.

## 15. Flutter Data Compatibility

The archived Flutter implementation may contain useful existing SQLite data.

The native app should not assume compatibility until the migration strategy is documented.

Migration choices:

- Reuse existing database directly.
- Import from existing database.
- Rebuild the native database from source subtitle files.

The preferred initial strategy is to rebuild from local subtitle files unless direct compatibility is explicitly approved.
