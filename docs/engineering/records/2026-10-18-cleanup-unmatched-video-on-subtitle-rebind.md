# 2026-10-18: Cleanup Unmatched Video on Subtitle Rebind

Human-owned documents:

- `docs/human/requirements/20261018-Bug-Cleanup Unmatched Video On Subtitle Rebind.md`
- `docs/human/design/foundation/Index and Incremental Update.md`

## Why

- When a matched video file was deleted and replaced by a video with a different extension or filename in the same folder (for example, `1.mov` replaced by `1.mkv`), re-indexing rebound the subtitle to `1.mkv`, but `upsertSubtitleVideoMatch` only marked the old match row in `subtitle_video_matches` as `is_active = 0` and `deleteOrphanedVideoFiles` skipped any video with `library_id != NULL` or existing `library_playback_history` / `library_watch_states` rows.
- As a result, the unmatched `1.mov` row and its `VideoID`, playback history, and watch state remained in SQLite, so if a new `1.mov` was later placed back at the same path and indexed, it reused the old `VideoID` and inherited the stale watch state and playback progress instead of initializing as a new `Unwatched` video with `0` progress.

## What changed

- **`IndexingDatabase.swift`**:
  - Updated `upsertSubtitleVideoMatch(subtitleFileID:videoFileID:)` to delete prior `subtitle_video_matches` rows for the subtitle (`WHERE subtitle_file_id = ? AND video_file_id != ?`) before upserting the active match.
  - Updated `deleteOrphanedVideoFiles()` to purge any `subtitle_video_matches` rows with `is_active = 0` or missing `subtitle_files`, find all `video_files` rows that no longer have an active match in `subtitle_video_matches`, and delete them via `deleteVideoFile(id:)` (which removes their `library_playback_history`, `library_watch_states`, `library_video_rows`, and `video_files` records).
  - Updated `publishLibraryIndex(_:)` to record `affectedFolderPaths` when `bindingRefreshes` rebinds a subtitle to a new video so presentation rows are refreshed.
  - Called `deleteOrphanedVideoFiles()` at the end of `replaceCueGroupsPersistingLanguageAnalysis` and `publishLibraryIndex` after all subtitle-video bindings in the transaction have settled.
- **`IndexPathIdentityTests.swift`**:
  - Added regression test `replacingVideoFormatCleansUpOldVideoAndDoesNotRestoreWatchStateWhenNameReturns()` covering both unchanged-subtitle and changed-subtitle video format swaps (`Episode.mov` -> `Episode.mkv` -> `Episode.mov`).

## Verification

- Verified `CueSeekerCoreTests` (346 tests, including `IndexPathIdentityTests`, `SubtitleIndexerTests`, and `IndexingDatabaseTests`) pass via `swift test --filter "CueSeekerCoreTests"`.
