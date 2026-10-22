# 2026-10-22 Migrate Domain Store Ownership And Deduplicate Remote Dialogs

## Requirement Reference
- `docs/human/requirements/20261022-Engineering-Migrate Domain Store Ownership And Deduplicate Remote Dialogs.md`

## Summary of Changes
1. **Sub-step 5A — Deduplicated WebDAV, SMB, FTP, and NFS Remote Folder Dialogs and State Controllers**:
   - Extracted and unified the 4 remote folder dialog state controllers out of `AppCoordinator+Indexing.swift` (reduced from 1,901 to 1,081 lines) into `AppCoordinator+RemoteFolderDialogs.swift` (549 lines) over a shared `RemoteFolderDialogSessionProtocol`.
   - Extracted the shared 2-step dialog shell, browser step, `RemoteFolderBreadcrumbBar`, `WebDAVBrowserCard`, and session helpers into `RemoteFolderDialogSharedViews.swift` (502 lines), reducing `WebDAVFolderDialog.swift` (474 → 99 lines), `SMBFolderDialog.swift` (366 → 115 lines), `FTPFolderDialog.swift` (355 → 110 lines), and `NFSFolderDialog.swift` (334 → 83 lines).
2. **Sub-step 5B — Migrated Excerpt (Shiori) Database, Tasks, Cover Storage, and Table Projection into `ExcerptStore`**:
   - Moved `excerptDatabase`, `excerptListCoverStorage`, `excerptListOverviewTask`, `excerptTableRowsTask`, `excerptMutationTask`, `excerptListSaveTask`, `excerptListCoverImportTask`, and Excerpt reload/navigation state from `AppCoordinator.swift` into `ExcerptStore.swift` (with forwarding properties on `AppCoordinator`).
   - Created `ExcerptStore+Execution.swift` (1,442 lines) owning Excerpt list overview loading, table row hydration, `residentExcerptTableProjection`, list editor validation/cover import/save, and CRUD operations, reducing `AppCoordinator+Excerpt.swift` from 1,704 to 760 lines.
3. **Sub-step 5C — Migrated Library Database, Hydration Tasks, Cover Editing, and History Writer into `LibraryStore`**:
   - Extracted `LibraryPlaybackHistorySnapshot`, `LibraryWatchStateSnapshot`, and `LibraryPlaybackHistoryWriter` into `LibraryPlaybackHistoryWriter.swift` (100 lines).
   - Moved Library databases, cover service, playback history writer, and 11 hydration/cover/history `Task` handles from `AppCoordinator.swift` into `LibraryStore.swift` (198 lines).
   - Created `LibraryStore+Execution.swift` (859 lines) owning Library/Recent/CompleteLibrary hydration, folder detail loading, cover editing, and watch-state batch updates, reducing `AppCoordinator+Library.swift` from 1,455 to 747 lines.
4. **Sub-step 5D — Extracted Playback Input Router, Cue Auto-Stop State Machine, and HUD Feedback Module**:
   - Extracted and structured the playback keyboard router into `AppCoordinator+PlaybackInputRouter.swift` (641 lines) with explicit per-layer handlers (`handlePlaybackMenuKeyDown`, `handlePlaybackCollageKeyDown`, `handlePlaybackCommandPanelKeyDown`, `handlePlaybackSubtitleFocusKeyDown`, `handlePlaybackStageKeyDown`) and aligned `AppCoordinator+ControllerInput.swift` (288 lines).
   - Extracted the cue auto-stop, auto-switch, and repeat state machine into `AppCoordinator+PlaybackAutoStop.swift` (351 lines), reducing `AppCoordinator+Playback.swift` from 1,566 to 685 lines.
   - Extracted the HUD feedback presentation methods out of `PlaybackViewModel.swift` (reduced from 1,132 to 812 lines) into `PlaybackViewModel+Feedback.swift` (327 lines).

## Verification
- Verified `swift build --package-path apps/macos-native` and `WebDAV` / `SMB` / `FTP` / `NFS` / `RemoteFolder` / `CueGroupRefreshScopeIntegrationTests` / `PlaybackExcerptOverlayTests` / `ExcerptDatabaseTests` / `ExcerptList` / `LibraryDatabaseTests` / `RecentPlaybackSessionRegressionTests` / `PlaybackLibraryOverlayTests` / `PlaybackLibraryChangeTests` / `PlaybackNormalShortcutTests` / `PlaybackSegmentCompletionTests` / `PlaybackController` / `PlaybackSubtitleFocusKeyboardActionTests` unit test suites pass with 0 errors.
