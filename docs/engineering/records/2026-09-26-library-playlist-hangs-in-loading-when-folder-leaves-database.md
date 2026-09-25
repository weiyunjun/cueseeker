# Library playlist hangs in loading when folder leaves database

Human-owned documents:

- `docs/human/requirements/20260926-Bug-Library Playlist Hangs In Loading When Folder Leaves Database.md`
- `docs/human/requirements/20260925-Feature-Playback Continues When Content Leaves The Database.md` (3. 播放页 第 4 条)
- `docs/human/design/UI Design System.md` (Playback Overlay, Empty State)

## Why

When a video was playing and its folder left the library via Remove Folder or Index:
1. `PlaybackLibrarySessionStore` observed only `$completeLibraryFolderDetailsByPath` from `libraryStore`, and not `$completeLibraryFolderDetailStatusesByPath`.
2. When the folder detail asynchronous load completed with `nil` (since the folder no longer existed in the database), the status was set to `.failed(L("status.folder_detail_unavailable"))`.
3. Because the store did not observe status changes and the child view `PlaybackLibraryEpisodeList` only observed the store, `PlaybackLibraryEpisodeList` was never notified of the finished load and remained indefinitely on its initial `.loading` branch showing `ProgressView`.
4. Furthermore, `PlaybackLibraryOverlay.contentBody` handled `.failed` by displaying an error hint rather than the requirement-specified empty playlist message (`playback.playlist.left_library`).
5. Switching between modules in an open Playback Overlay passed `refreshesExistingSnapshot: true`, causing redundant re-requests that violated the requirement to keep content stable when switching tabs inside an open overlay.

## What changed

- **Observe detail statuses**: `PlaybackLibrarySessionStore` now subscribes to `libraryStore.$completeLibraryFolderDetailStatusesByPath` and notifies its observers on change. `PlaybackLibraryEpisodeList` also directly observes `libraryStore`.
- **Show empty playlist hint when folder detail is missing**: In `PlaybackLibraryOverlay.contentBody`, when loading finishes and `detail` is missing or has no videos, it shows `PlaybackEmptyHint(L("playback.playlist.left_library"))` instead of an error message.
- **Prevent redundant requests on module transitions**: Switching between modules in `PlaybackSubtitleFocusSessionStore.selectModule` activates stores without `refreshesExistingSnapshot: true`, keeping content stable while the overlay stays open.
- **Preserve selection on transient updates**: `applyCurrentDetail` notifies observers when `detailsByPath[folderPath]` is missing without unnecessarily clearing selection when details are temporarily unpopulated.

Files:

- `apps/macos-native/Sources/CueSeekerApp/Playback/SubtitleFocus/PlaybackLibrarySessionStore.swift`
- `apps/macos-native/Sources/CueSeekerApp/Playback/SubtitleFocus/PlaybackLibraryOverlay.swift`
- `apps/macos-native/Sources/CueSeekerApp/Playback/SubtitleFocus/PlaybackSubtitleFocusSessionStore.swift`
- Tests: `apps/macos-native/Tests/CueSeekerAppTests/PlaybackLibraryChangeTests.swift`

## Verification

- `swift test --filter PlaybackLibraryChangeTests`: 12 tests passed, including new test `libraryOverlayOpenedAfterFolderLeavesDatabaseShowsPlaylistEmptyHintAndDoesNotHang`.
- `swift test --filter PlaybackLibraryOverlayTests`: 9 tests passed.
- Manual verification: acceptance item 1 is the owner's.
