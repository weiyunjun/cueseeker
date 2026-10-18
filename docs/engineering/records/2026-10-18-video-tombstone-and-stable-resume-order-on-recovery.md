# 2026-10-18: Video Tombstone and Stable Resume Order on Recovery

Human-owned documents:

- `docs/human/requirements/20261018-Feature-Video Tombstone And Stable Resume Order On Recovery.md`
- `docs/human/design/data/Data.md`

## Why

- Previously, when a video or folder left active matching during `Index` or `Remove Folder`, `deleteVideoFile`, `deleteLibraryFolders`, and `deleteEmptyLibraryFolders` permanently deleted the video's playback progress, watch state, manual video cover, default audio track, and manual folder cover.
- When a video was replaced directly at the same path with a shorter file whose duration was smaller than the saved playback progress, `updateVideoDuration` / `updateVideoMetadata` did not reset the stale playback progress and watch state to `0` and `Unwatched`.
- When an Excerpt List's `recent_cue_id` entered `cue_tombstones`, `excerpt_lists.recent_cue_id` stayed pointing to the tombstoned `CueID` in SQLite; while `recentExcerptListSummaries()` temporarily fell back to the first playable cue in memory, resurrecting the tombstoned cue caused `Resume` to jump back to the resurrected cue and alter the existing order.

## What changed

- **`DatabaseBootstrap.swift`**:
  - Bumped `currentSchemaVersion` from `56` to `57` and added `video_tombstones` (`video_path`, `position_ms`, `duration`, `watch_state`, `user_cover_path`, `default_audio_track_index`, `tombstoned_at`, `updated_at`) for fresh databases and `migrateSchema56To57`.
- **`IndexingDatabase.swift`**:
  - Added `snapshotVideoTombstoneIfNeeded` in `deleteVideoFile` so videos with user-accumulated state (`position_ms > 0`, watch state `'watching'` / `'finished'`, manual video cover, or `default_audio_track_index > 0`) are snapshotted into `video_tombstones` keyed by `video_path` when leaving active matching, while videos with no user state are deleted directly.
  - Added `restoreVideoTombstoneIfNeeded` in `upsertVideoFile` so a video returning at the exact same `video_path` (path + filename + extension) restores its playback progress, watch state, manual video cover, and default audio track from `video_tombstones` with `library_playback_history.updated_at = ''` (never restoring Recent watching or altering Folder `Resume` order), and deletes the tombstone row.
  - Updated `deleteLibraryFolders` and `deleteEmptyLibraryFolders` to detach `user_folder_covers` (`SET folder_id = NULL`) instead of deleting manual folder covers, allowing `adoptFolderOwnedPaths` to re-bind them when the folder returns at the same `folder_path`.
  - Added `reconcileExcerptListRecentCues` after cue/subtitle/folder tombstone mutations so any Excerpt List whose `recent_cue_id` is no longer a valid playable cue immediately updates `excerpt_lists.recent_cue_id` in SQLite to the list's first playable cue (or clears `recent_cue_id / recent_sort_order / recent_played_at` if none remain).
- **`LibraryDatabase.swift` & `LibraryDatabase+Presentation.swift` & `ExcerptDatabase.swift`**:
  - Added `reconcilePlaybackStateForUpdatedDuration` in `updateVideoDuration` and `updateVideoMetadata` so that whenever a video's duration is shorter than its saved `position_ms` (both for direct same-path replacement and tombstone recovery), `library_playback_history` and `library_watch_states` are cleared (`0` / `.unwatched`) and watch state facet counts are rebuilt.
  - Filtered `h.updated_at != ''` in `recentLibraryWatching` primary query and normalized empty `h.updated_at` to `nil` in `completeLibraryPresentation` and `completeLibraryFolderDetail` so restored videos keep their episode progress without re-entering Recent watching or hijacking Folder `Resume`.
  - Persisted fallback `recent_cue_id` in `ExcerptDatabase.recentExcerptListSummaries()` when `access == .readWrite` and `anchoredID == nil`.
- **`DatabaseBootstrapTests.swift` & `IndexPathIdentityTests.swift`**:
  - Added `migratesSchema56ByCreatingVideoTombstonesTable`, `returningFolderRestoresCoverWatchStateAndProgressWithoutRestoringRecent`, `replacingVideoFormatIsolatesByExtensionAndRestoresExactPathTombstone`, `shorterNewVideoDurationResetsProgressAndWatchStateForBothDirectReplacementAndTombstoneRecovery`, and `resurrectingVideoAndCueDoesNotAlterExistingFolderOrExcerptListResumeOrder`.

## Verification

- Verified all 349 tests in `CueSeekerCoreTests` and related `CueSeekerAppTests` suites pass via `swift test --package-path apps/macos-native`.
