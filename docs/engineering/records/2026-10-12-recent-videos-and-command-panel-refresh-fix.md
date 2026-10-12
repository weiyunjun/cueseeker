# Recent Videos And Command Panel Refresh Fix

Human-owned documents:

- `docs/human/requirements/20261012-Bug-Recent Videos And Command Panel Refresh Failure.md`
- `docs/human/requirements/20261009-Feature-Workbench Invalidation.md`
- `docs/human/design/UI Design System.md`

## Why

1. **Bug 1 (Library playback start followed by Command Panel Recent Videos stale)**:
   - When entering playback from Library, playing episode 1 and switching to episode 2, invoking Command Panel and entering `Recent Videos` did not refresh the list and still displayed the old episode record.
   - Root cause: In `AppCoordinator+PlaybackCommandPanel.swift`, entering `.recentVideos` called `hydrateTestRecentWatchingAsync()`, which contains an early return `guard library.testRecentWatchingStatus != .completed else { return }`. Once initial library loading completed on startup, entering `Recent Videos` always returned early without fetching the latest SQLite playback history.

2. **Bug 2 (Recent page manual watch state update not reflecting in place)**:
   - Right-clicking a card on the `Workbench Recent` page to mark as watched or unwatched did not update the card in place without leaving and re-entering the tab.
   - Root cause: `markLibraryVideos` writes to SQLite and invokes `refreshLibraryPlaybackHistoryPresentations(affectedVideoPaths:)`. That method called `refreshRecentWatching()` and `refreshLoadedTestRecentWatching()` without `force: true`. Because the user was actively on the Recent tab (`panelMode == .recentWatching`), the invalidation hold logic intended for passive background folder mutations intercepted these user-initiated updates and marked `recentNeedsReloadAfterIndexedMutation = true` instead of refreshing immediately.

3. **Bug 3 (Playback from Recent page keeps Command Panel stale)**:
   - Starting playback from the Recent page and switching episodes did not update the Recent Videos list in Command Panel.
   - Root cause: Starting playback and episode navigation call `recordRecentLibraryWatching`, which flushes history presentations via `refreshLibraryPlaybackHistoryPresentations`. Because `panelMode` remained `.recentWatching`, the calls were intercepted by the hold, leaving `testRecentWatchingItems` un-updated.

## What changed

1. **Immediate Reload for Command Panel Recent Videos (`AppCoordinator+PlaybackCommandPanel.swift`)**:
   - In `presentPlaybackCommandPanelPage(_ page: PlaybackCommandPanelPage)`, changed `case .recentVideos` to call `refreshTestRecentWatching()` directly rather than `hydrateTestRecentWatchingAsync()`. This matches `case .recentExcerpts` calling `reloadExcerptListOverview()`, guaranteeing that navigating to the Recent Videos page queries the latest database history.

2. **User-Initiated Playback History Presentations Bypass Invalidation Hold (`AppCoordinator+Library.swift`)**:
   - In `refreshLibraryPlaybackHistoryPresentations(affectedVideoPaths:)`, updated calls to `refreshRecentWatching(force: true)` and `refreshLoadedTestRecentWatching(force: true)`. User-driven actions (playing videos, switching episodes, marking watch states) are explicit business operations that must refresh immediately without being held as passive background mutations.
   - In `hydrateRecentWatchingAsync()`, passed `force: true` to avoid initial hydration being held if opened while in `.recentWatching` panel mode (consistent with `hydrateCompleteLibraryAsync`).

3. **Regression Test Coverage (`RecentPlaybackSessionRegressionTests.swift`)**:
   - Added `markingWatchStateWhileInRecentPanelModeRefreshesImmediately()` verifying that marking watch state while active on `.recentWatching` updates loaded watching items in place for both `.finished` and `.unwatched` without deferral.
   - Added `startingPlaybackWhileInRecentPanelModeRefreshesWithoutDeferral()` verifying that starting playback while in `.recentWatching` updates loaded recent watching immediately.
   - Added `commandPanelRecentVideosRefreshesWhenStatusAlreadyCompleted()` verifying that entering `.recentVideos` in Command Panel reloads the latest history even when `testRecentWatchingStatus` is `.completed`.

## Verification

- `swift build --package-path apps/macos-native`: succeeded.
- `swift test --package-path apps/macos-native --filter RecentPlaybackSessionRegressionTests`: passed (9/9 tests passed).
- `swift test --package-path apps/macos-native --filter WorkbenchInvalidationTests`: passed (5/5 tests passed).
