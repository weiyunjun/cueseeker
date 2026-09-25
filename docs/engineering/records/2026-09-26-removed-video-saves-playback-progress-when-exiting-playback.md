# Removed video saves playback progress when exiting playback

Human-owned documents:

- `docs/human/requirements/20260926-Bug-Removed Video Saves Playback Progress When Exiting Playback.md`
- `docs/human/requirements/20260925-Feature-Playback Continues When Content Leaves The Database.md` (3. 播放页 第 1 条)
- `docs/human/design/Data.md` (永久身份与路径分离 补充说明 7)

## Why

When a video was playing and its folder left the library via Remove Folder:
1. `AppCoordinator.stopPlayback()` cleared `currentPlaybackItemLeftLibrary = false` at the very beginning of the method, before calling `saveCurrentLibraryPlaybackHistoryForPlaybackClose()`.
2. As a consequence, `saveCurrentLibraryPlaybackHistory` saw `!currentPlaybackItemLeftLibrary` as `true` instead of `false`, bypassing the check intended to prevent saving history for videos that left the library.
3. `LibraryPlaybackHistoryWriter` then invoked `LibraryDatabase.upsertLibraryPlaybackHistory()`, which called `upsertVideoFile()`.
4. `upsertVideoFile()` inserted a new orphan record in `video_files` with `library_id = NULL` because the video was no longer under any path in `search_paths`. It then attached playback history and a `.watching` watch state to this orphan video file record.
5. When the user later re-added the folder, the indexer backfilled the existing orphan record with the new library ID, preserving the dirty progress and leaving the video in `Watching` state rather than resetting to `Unwatched` with 0 progress.

## What changed

- **Preserve `currentPlaybackItemLeftLibrary` until playback teardown**: In `AppCoordinator.stopPlayback()`, moved `currentPlaybackItemLeftLibrary = false` from the top of the function to the end alongside `activePlaybackSource = .none`, ensuring `saveCurrentLibraryPlaybackHistoryForPlaybackClose()` properly detects that the video has left the library and skips saving.
- **Guard recent library watching start**: In `AppCoordinator.recordRecentLibraryWatching()`, added an early return `guard !currentPlaybackItemLeftLibrary else { return }` to prevent saving recent watching state for videos that have left the library.
- **Refuse inserting orphan video files in `LibraryDatabase`**: In `LibraryDatabase.upsertVideoFile()`, if the video file does not already exist in `video_files`, is not under any registered search path in `search_paths`, and `search_paths` is not empty, it returns `nil`. `upsertLibraryPlaybackHistory()` and `upsertLibraryWatchState()` guard on this ID and refuse to insert records into `library_playback_history` or `library_watch_states`.

Files:

- `apps/macos-native/Sources/CueSeekerApp/App/AppCoordinator+Playback.swift`
- `apps/macos-native/Sources/CueSeekerApp/App/AppCoordinator+Library.swift`
- `apps/macos-native/Sources/CueSeekerCore/LibraryDatabase.swift`
- Tests: `apps/macos-native/Tests/CueSeekerAppTests/PlaybackLibraryChangeTests.swift`
- Tests: `apps/macos-native/Tests/CueSeekerCoreTests/LibraryDatabaseTests.swift`

## Verification

- `swift test --filter exitingPlaybackOfVideoThatLeftLibraryDoesNotSaveHistoryOrPolluteDatabase`: passed (verified that exiting playback of a video whose folder was removed does not save history, does not write orphan records, and re-adding folder shows 0 progress and unwatched).
- `swift test --filter upsertLibraryPlaybackHistoryRefusesToInsertOrphanRecordForVideoOutsideSearchPaths`: passed (verified that `LibraryDatabase` refuses to insert orphan records for videos outside search paths).
- `swift test --filter PlaybackLibraryChangeTests`: 13 tests passed.
- `swift test --filter LibraryFolderRemovalTests`: 10 tests passed.
- `swift test --filter LibraryDatabaseTests`: 22 tests passed.
- `swift test --filter PlaybackSegmentCompletionTests`: 28 tests passed.
- `swift test --filter RecentPlaybackSessionRegressionTests`: 6 tests passed.
- Manual verification: acceptance item 1 is the owner's.
