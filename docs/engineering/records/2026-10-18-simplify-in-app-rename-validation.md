# 2026-10-18: Simplify In-App Rename Validation

Human-owned documents:

- `docs/human/requirements/20261018-Feature-Simplify In-App Rename Validation.md`
- `docs/human/design/data/Data.md`
- `docs/human/design/workbench/Library and File.md`

## Why

1. **Redundant and overly strict conflict checks blocked valid renames and degraded folder rename performance**:
   - `LibraryRenamer` previously scanned the entire directory or subtree on disk, compared live filename-based subtitle/video pairings against indexed database pairings, simulated post-rename pairings, and checked `fileSize` and `modifiedAt` on every file under the target folder.
   - Any unindexed file or blank subtitle file (such as a `.blank.srt` skipped during `Index` because it contains no cues) caused live disk filename pairing to differ from indexed pairings, permanently blocking both `Rename Files` and `Rename Folder` even immediately after re-indexing.
   - On folders with many episodes (especially on external drives), `stat`-ing every video/subtitle file and traversing the folder tree twice added seconds of unnecessary disk I/O before renaming the folder.
   - `AppCoordinator.runRename` and `TaskQueueStore` also added unnecessary guards blocking renames of currently playing videos or files referenced by queued exports.

## What changed

- **Simplified `LibraryRenamer` conflict checks (`LibraryRename.swift`, `IndexingDatabase+Rename.swift`)**:
  - **`Rename Folder`**: Checks only that the target folder itself exists on disk, has indexed subtitle folder paths in the database (`indexedSubtitleFolderPaths(underFolderPath:)`), and that the destination name does not already exist in the same parent directory (`requireDestinationFree` and `hasRenameRows(atOrUnderPath:)`). Removed per-file attribute checks and subtree scanning/matching.
  - **`Rename Files`**: Checks only that the known paired files (`video` + matched `subtitles` in the database) all exist on disk as regular files (`requireExistingFiles`) and that none of the target file names already exist in the same directory (`requireDestinationFree` and `hasRenameRows(atOrUnderPath:)`). Removed `fileSize`/`modifiedAt` checks, directory listing scans, and `pairingWouldChange` simulation.
  - Removed `LibraryRenameConflict.pairingWouldChange`, `RenamePair`, `activeRenamePairs`, and `renameFileRecords` from `LibraryRename.swift` and `IndexingDatabase+Rename.swift`.
- **Removed playback and export rename refusals (`AppCoordinator+LibraryRename.swift`, `TaskQueueStore.swift`)**:
  - Removed `playingVideoPath` refusal check in `AppCoordinator.runRename`.
  - Removed `LibraryRenameRefusal` and `exportUses(_:)` in `TaskQueueStore`.

## Verification

- Updated and added unit tests in `apps/macos-native/Tests/CueSeekerCoreTests/LibraryRenameTests.swift` and `apps/macos-native/Tests/CueSeekerAppTests/TaskQueueStoreTests.swift`:
  - `blankSubtitlesUnindexedFilesAndEditedFilesDoNotBlockRename`
  - `fileGroupRenameRequiresEveryKnownPairedFileToExist`
  - `folderRenameOnlyRequiresTheFolderItselfToExist`
  - `anExistingNameInTheSameDirectoryIsAConflictWhileOtherDirectoriesAreAllowed`
  - `aRenameProceedsWithoutBeingBlockedByExports`
