# Data Model

Status: Draft

## 1. Data Model Principles

The data model should remain stable across the native rewrite.

Data should be local-first and easy to migrate. Schema changes must be explicit and documented before implementation.

## 2. Core Entities

Initial entities:

- Search path.
- Library folder.
- Video file.
- Subtitle file.
- Subtitle-to-video match.
- Subtitle cue group.
- Subtitle cue line.
- Index metadata.
- ASS font resource manifest.
- Shiori.
- Cue tombstone and change notice.
- Resource binding conflict.

Shiori is not required for M1 but should be considered when designing identity stability.

## 3. Search Path

A search path represents a local folder selected for subtitle indexing.

Fields:

- `id`
- `type`
- `path`
- `last_known_path`
- `resource_identity`
- `binding_state`
- `is_configured`
- `last_seen_at`
- `last_successful_index_at`
- `latest_index_token`
- `published_index_token`
- `created_at`
- `updated_at`

Initial supported `type`:

- `local`

Remote path types are deferred.

Notes:

- A search-path row is the permanent Library identity. `path` is its current
  binding and `last_known_path` is diagnostic state, not identity.
- Selected Library configuration is the source of truth for active local search
  scope. Removing a Library marks it unconfigured instead of reusing its ID.
- Removing a selected folder must remove or exclude derived index data under
  that folder while preserving the local files on disk and durable user state
  that may reference those files.
- Index publication tokens ensure that only the newest run for one Library may
  publish.

## 3.1 Library Folder

A Library folder represents a discovered directory under one Library.

Fields:

- `id`
- `library_id`
- `relative_path`
- `last_known_path`
- `resource_identity`
- `binding_state`
- `last_seen_at`

Folder identity is independent from its relative path. Folder-cover and future
folder-owned durable state must use this ID rather than a path.

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
- `library_id`
- `folder_id`
- `relative_path`
- `path`
- `last_known_path`
- `resource_identity`
- `content_fingerprint`
- `binding_state`
- `last_seen_at`
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
- `library_id`
- `folder_id`
- `relative_path`
- `subtitle_path`
- `last_known_path`
- `resource_identity`
- `content_fingerprint`
- `binding_state`
- `last_seen_at`
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

A subtitle cue group is a derived indexing container for cue lines that share
one exact subtitle-file time window. It is not the product result or action
identity.

For SRT, a cue group usually maps to one SRT block and contains one cue line.

For ASS, a cue group maps to all searchable `Dialogue` events in the same source
subtitle file with the exact same `start_ms` and `end_ms`. This preserves the
relationship needed for optional bilingual or multi-line context without
combining the contained cues into one result. Near-equal ASS timestamps are not
grouped by tolerance in the first implementation.

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

- Group timing supports indexed recall and group-context lookup. Cue actions use
  the selected cue line's own `start_ms` and `end_ms`.
- `end_ms` is useful for future current-line highlighting and Shiori.
- `subtitle_path` and timing fields are derived lookup data, not permanent
  identity.
- `search_content` is aggregate recall data. Final Search matching and result
  identity are resolved per cue line.
- Cue Group context may be loaded for presentation and `Copy Cue Group Text`,
  but it must not replace the primary Cue identity used by selection, playback,
  Context, Shiori, copy-Cue, or export actions.
- Playback should resolve the target media file through the active subtitle-to-video match, not through subtitle path naming assumptions.
- The current native schema uses first-class subtitle files, video files,
  subtitle-to-video matches, cue groups, and cue lines. The older M1
  `srt_path`-centered subtitle-entry index is treated as rebuildable derived
  data during migration.

## 9. Subtitle Cue Line

A subtitle cue line represents one displayable/searchable line inside a cue
group.

The cue line is the product-level Cue and the base unit for Search, Shiori,
Context, Playback Multi-Module Overlay Cue results, copy actions, and exports.

One source SRT block remains one Cue even when its text contains explicit line
breaks. One searchable ASS `Dialogue` event is one Cue. Visual wrapping and
source line breaks do not create additional Cue identities.

Fields:

- `id`
- `cue_group_id`
- `event_index`
- `source_format`
- `source_style`
- `source_layer`
- `source_identity_remainder`
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
- `event_index` preserves source order inside the subtitle file, but never
  participates in durable Cue identity or ambiguity resolution.
- An ASS Cue compares timestamp (`T`), text (`X`), Style (`S`), and the
  canonical remaining Dialogue fields (`R`). Exact matches are locked first.
  Style is a hard boundary. With Style unchanged, a unique candidate may retain
  CueID only when at most one of `T`, `X`, and `R` changed.
- SRT sequence numbers never participate in identity. SRT uses exact
  timestamp/text matching first and permits only a unique remaining one-to-one
  edit. Ambiguous remaining candidates receive new CueIDs.
- `source_style` stores ASS style names such as `Dial_JP`, `Dial_CH`,
  `Screen`, `Title`, `Staff`, `ED_JP`, or `ED_CH` when available.
- `source_layer` stores the ASS `Layer` field when available. Layer is render
  stacking information, not vertical position.
- `source_identity_remainder` stores the canonical ASS Dialogue fields outside
  timestamp, text, and Style, including Layer, Name, margins, and Effect.
- `display_x`, `display_y`, and `display_order` are derived layout fields for
  optional Cue Group presentation. They help order additional context to
  approximate the subtitle's on-video placement without replacing the primary
  Cue result identity. `display_order` never participates in identity.
- Raw duplicate ASS events and SRT blocks remain in the rendering timeline.
  The database, Search, Shiori, and Playback Overlay collapse completely
  identical events into one logical CueID.
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
FTS may use the group aggregate for recall, but final filtering must emit one
result for each matching cue line. The result's primary content is that Cue.
Other cue lines in the group are loaded only when optional Cue Group context is
requested and are displayed in `display_order` above the primary Cue.

A Cue must not match only because query terms are split across different cue
lines. The search implementation may use cue-group content for recall, but each
returned Cue must independently satisfy the query semantics.

## 13. Shiori

Shiori stores a relation from a Shiori list to an indexed Cue for later review.

Expected fields:

- `id`
- `list_id`
- `cue_id`
- `created_at`

The initial native table should be named `shioris`.

`created_at` stores the real-world timestamp when the relation was created.
ShioriID identifies the relation; CueID identifies the referenced content.
Current subtitle text and media information are resolved from the active Cue
when available. A Shiori relation remains durable when that Cue becomes
unavailable.

Only Cues referenced by Shiori or other durable user data retain a long-lived
Tombstone. The Tombstone stores the minimum last-known Cue, Cue Group, time,
title, subtitle, video, and identity snapshot required for display, copy, and
later identity recovery. Unreferenced deleted Cues do not receive an indefinite
identity guarantee.

A Cue whose identity was retained while text changed receives a one-generation
change notice containing the previous and current text. A later successful
unchanged index removes the notice.

The first implementation creates one default Shiori list and does not add
multi-list controls. The schema nevertheless permits a CueID to be referenced
by different lists. A CueID may occur only once inside one list, so relation
uniqueness is `(list_id, cue_id)` rather than CueID alone.

Search and Shiori resolve the same CueID through the same current Cue content
source. If indexed Cue content changes while retaining its CueID, Shiori shows
the updated content.

## 13.1 Shiori Tags

Shiori tags are durable user state for organizing saved Shiori records.

Expected tag fields:

- `id`
- `name`
- `normalized_name`
- `created_at`

Expected assignment fields:

- `shiori_id`
- `tag_id`
- `created_at`

The tag pool is global to Shiori. A tag can be assigned to many Shiori records,
and a Shiori record can have many tags. Tag assignments should be keyed by the
durable `shioris.id` record rather than rebuildable subtitle cue-group rows.

`normalized_name` stores the trimmed tag text used for uniqueness. Tag names
are case-sensitive: `Tag` and `tag` are distinct tags. Tag text validation
follows the human-owned Shiori tag requirement, including the 20-character
limit, trim behavior, and forbidden control/format characters.

Deleting a tag deletes its tag-assignment rows but must not delete the
associated Shiori records.

## 14. Schema Versioning

The native implementation must define an explicit schema versioning mechanism before writing production user data.

Schema versioning rules belong in:

```text
docs/engineering/05_database_rules.md
```

Current native schema:

- Implemented schema version: `35`.
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
- Version 25 backfills durable Library watch states from Library playback
  history.
- Version 26 adds `shiori_tags` and `shiori_tag_assignments` for the global
  Shiori tag pool and Shiori/tag associations.
- Version 27 adds Library display-cover rendition fields without replacing the
  durable master-cover reference.
- Version 28 changes durable Shiori identity from Cue Group timing to individual
  Cue identity, preserves tag assignments, and migrates resolvable legacy rows
  to a Japanese Cue when one is identifiable, choosing the physically
  bottommost eligible Cue as the deterministic tie-break and fallback.
- Version 29 adds permanent indexed-resource identity columns and explicit
  Shiori CueID bindings.
- Version 30 makes the current single-list CueID binding unique.
- Version 31 removes obsolete persisted playback navigation tables.
- Version 32 creates the default list and replaces the stored Shiori content
  snapshot with `(id, list_id, cue_id, created_at)`.
- Version 33 adds durable user-selected video and folder cover overrides and is
  the minimum supported native schema.
- Version 34 adds multi-list Shiori metadata.
- Version 35 adds stable resource-binding metadata, Library folder identities,
  per-Library index publication tokens, ASS identity remainder storage,
  Cue Tombstones and change notices, binding-conflict records, and removes the
  destructive Cue foreign-key cascade from Shiori relations.

## 15. Flutter Data Compatibility

The archived Flutter implementation may contain useful existing SQLite data.

The native app should not assume compatibility until the migration strategy is documented.

Migration choices:

- Reuse existing database directly.
- Import from existing database.
- Rebuild the native database from source subtitle files.

The preferred initial strategy is to rebuild from local subtitle files unless direct compatibility is explicitly approved.
