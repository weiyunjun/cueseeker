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

## Verification
- Verified `swift build --package-path apps/macos-native` and `WebDAV` / `SMB` / `FTP` / `NFS` / `RemoteFolder` / `CueGroupRefreshScopeIntegrationTests` / `PlaybackExcerptOverlayTests` / `ExcerptDatabaseTests` / `ExcerptList` unit test suites pass with 0 errors.
