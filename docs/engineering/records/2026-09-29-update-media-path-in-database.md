# Update media path in database

Human-owned documents:

- `docs/human/requirements/20260929-Engineering-Update Media Path In Database.md`

## Why

Migrate media storage path references in `CueSeeker.sqlite` from `/Volumes/Samsung/影视` to `/Volumes/Seagate/影视`.

## What changed

- Checkpointed WAL and created a timestamped database backup at `~/Library/Application Support/CueSeeker/CueSeeker.sqlite.backup-20260929-204703-before-media-path-update`.
- Executed an atomic transaction updating the path prefix across all 12 tables and fields:
  - `search_paths.path`: 1 row
  - `subtitle_files.subtitle_path`: 640 rows
  - `video_files.path`: 657 rows
  - `subtitle_cue_groups.subtitle_path`: 338,762 rows
  - `library_video_rows.video_path`, `subtitle_path`, `folder_path`: 624 rows
  - `subtitle_search_order_rows.subtitle_path`, `folder_path`: 640 rows
  - `cue_tombstones.subtitle_path`, `video_path`: 59 rows
  - `subtitle_playback_finish_metadata.subtitle_path`: 640 rows
  - `folder_covers.folder_path`: 39 rows
  - `user_folder_covers.folder_path`: 10 rows
  - `task_records.old_paths`: 13 rows
  - `cue_facet_counts.value` (`facet = 'folder'`): 40 rows

## Verification

- Scanned all columns across all SQLite tables: 0 occurrences of `/Volumes/Samsung/影视` remaining.
- `PRAGMA quick_check` and `PRAGMA integrity_check` verified healthy (`ok`).
- FTS matching on `subtitle_cue_groups_fts` verified working.
- Confirmed sample target video paths exist on `/Volumes/Seagate/影视`.
