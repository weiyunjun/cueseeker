# 2026-10-18: WebDAV Anonymous Access and In-App Rename

Human-owned documents:

- `docs/human/requirements/20261018-Feature-WebDAV Anonymous Access And In-App Rename.md`
- `docs/human/design/ui/UI Index.md`
- `docs/human/design/workbench/Library and File.md`
- `docs/human/design/playback/Playback Edge Cases.md`

## Why

1. **WebDAV Anonymous Access**:
   - Previously, `confirmWebDAVFolderDialog` and `WebDAVClient.validateDirectory` unconditionally required non-empty `Username` and `Password` fields before sending a `PROPFIND` request, blocking users from adding anonymous WebDAV directories (such as LAN public shares or guest AList/NAS folders).
   - `Username` and `Password` in `WebDav Folder` dialog (`L-06.4`) should be optional (no placeholder), validating only `Address` client-side and relying on `PROPFIND` to verify server access and credentials.
2. **WebDAV In-App Rename (`Rename Folder` & `Rename Files`)**:
   - Previously, `WorkbenchFileView` hardcoded `!isWebDAVURL` and `!isWebDAVPath` disables on `Rename Folder` and `Rename Files` menu items, and `LibraryRenamer` / `IndexingDatabase+Rename` used local-only `FileManager`, `URL(fileURLWithPath:)`, and `NSString.deletingLastPathComponent` APIs.
   - WebDAV folders (Level 1 root folders and Level 2 subfolders) and paired media files (Level 2/3 video and subtitle cards) should support in-App `Rename Folder` and `Rename Files` via WebDAV `PROPFIND` conflict checks and `MOVE` requests, with automatic rollback on failure, local subtitle cache and root config synchronization, and in-place UI updates across all pages.

## What changed

- **Anonymous WebDAV Validation (`WebDAVSupport.swift`, `AppCoordinator+Indexing.swift`)**:
  - Removed non-empty `username` and `password` guards in `AppCoordinator.confirmWebDAVFolderDialog(_:)` and `WebDAVClient.validateDirectory(name:address:username:password:)`. When left blank, `PROPFIND` requests omit the `Authorization` header (`basicAuthorizationValue == nil`).
- **WebDAV Conflict Checks, `MOVE` Execution & Rollback (`WebDAVSupport.swift`, `LibraryRename.swift`, `IndexingDatabase+Rename.swift`)**:
  - Added `directoryExists(at:peerPathInSameDirectory:)`, `fileExists(at:peerPathInSameDirectory:)`, `resourceExists(at:peerPathInSameDirectory:addsTrailingSlash:)`, `listDirectoryItems(at:)`, `listDirectoryItemsInParent(of:)`, and `moveItem(fromPath:toPath:isDirectory:)` to `WebDAVClient`, preserving `"MOVE"` across same-origin HTTP redirects.
  - Added `WebDAVConfigurationStore.rewriteFolderPathPrefix(from:to:)` to update `rootPath`, `davRootPath`, `address`, and `name` when a WebDAV root folder (or ancestor) is renamed, and `WebDAVSubtitleCache.moveCachedSubtitle(from:to:)` to move cached local subtitle files to their new URL hash key.
  - Added WebDAV-safe path helpers (`lastPathComponent(of:)`, `parentPath(of:)`, `replacingLastPathComponent(of:with:)`) in `LibraryRenamer` and replaced local-only `URL(fileURLWithPath:)` / `NSString.deletingLastPathComponent` calls in `LibraryRename.swift` and `IndexingDatabase+Rename.swift`.
  - Updated `LibraryRenamer.perform(_:)` and `restore(_:isDirectory:)` to execute WebDAV `MOVE` requests, roll back completed WebDAV moves if a subsequent file move or database transaction fails, migrate `WebDAVSubtitleCache` files, update `WebDAVConfigurationStore`, and clear `WebDAVClient`'s playable URL cache.
- **UI & Session Support (`WorkbenchFileView.swift`, `LibraryRenameDialog.swift`, `IndexingStore.swift`, `TaskPanel.swift`)**:
  - Enabled `Rename Folder` and `Rename Files` menu items on WebDAV items in `WorkbenchFileView`.
  - Updated `LibraryRenameSession` to use `IndexingStore.displayName(for:)` for root folders and WebDAV-safe path helpers for `request`, `oldPaths`, and `newPaths`.
  - Updated `IndexingStore.replaceFolderPathPrefix(_:with:)` to rewrite renamed WebDAV root URLs in `selectedFolders`.

## Verification

- Updated and added unit tests in `WebDAVFolderDialogTests.swift`, `WebDAVSupportTests.swift`, and `FileCardMenuTests.swift`.
- Verified `WebDAVSupportTests`, `WebDAVFolderDialogTests`, `LibraryRenameTests`, `FileCardMenuTests`, and `LibraryFolderRemovalTests` pass via `swift test`.
