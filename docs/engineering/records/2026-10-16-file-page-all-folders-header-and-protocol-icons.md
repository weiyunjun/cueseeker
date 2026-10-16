# Implementation Record: File Page All Folders Header And Protocol Icons

- **Requirement**: `docs/human/requirements/20261016-UI-File Page All Folders Header And Protocol Icons.md`
- **Date**: 2026-10-16

## Summary of Changes

1. **Remove Breadcrumb Pressed Effect (`C-05.6 Breadcrumb`)**:
   - Updated `BreadcrumbLink` in `apps/macos-native/Sources/CueSeekerApp/Library/WorkbenchFileView.swift` to use `StaticButtonStyle()`, `.focusable(false)`, and `.onPointerHover`, eliminating the default `.plain` button pressed dimming effect so hovered breadcrumb links retain their `Hover` styling while pressed and trigger navigation on release.

2. **Unified `All Folder` / `All Folders` Header & Breadcrumb Root Node (`L-04.5 File Page Layout`)**:
   - Added `file.all_folders.one` (`All Folder` / `全部文件夹` / `全部資料夾`) and `file.all_folders.other` (`All Folders` / `全部文件夹` / `全部資料夾`) localization entries across `en`, `zh-Hans`, and `zh-Hant`.
   - Removed the `Local Folder` / `WebDav Folder` grouping on File Level 1 in `WorkbenchFileView.swift` (`FileFolderGroupingResolver.rootFolders`) and unified all root folders under a single `All Folder` / `All Folders` header.
   - Updated `FileBreadcrumbResolver` so the leftmost breadcrumb node on Level 2 and Level 3 is also `All Folder` (when root folder count is 1) or `All Folders` (when root folder count > 1), keeping the leftmost label and position invariant across level transitions.

3. **Protocol Folder Icons (`L-04.6 File Card Layout` & `Icon Registry`)**:
   - Added `folder-webdav.svg`, `folder-smb.svg`, `folder-ftp.svg`, and `folder-nfs.svg` master assets under `apps/macos-native/Sources/CueSeekerApp/Resources/Icons/` and registered `.folderWebdav`, `.folderSmb`, `.folderFtp`, and `.folderNfs` in `AppIcon.swift` using Option B (compact folder outline slightly shifted upward + bold protocol badge centered underneath).
   - Wired `.folderWebdav` for File Level 1 WebDAV root folder cards, File Level 2 WebDAV subfolder cards, and the `WebDav Folder` option in the `Add Folder` dropdown menu.

4. **WebDAV Address Instant Paste Decoding & Human-Readable Display**:
   - Added `WebDAVAddress.decodedDisplayAddress(_:)` in `CueSeekerCore/WebDAVSupport.swift` to decode percent-encoded URLs into human-readable Chinese/symbols with NFC canonical normalization.
   - Wired `normalizeDraft: WebDAVAddress.decodedDisplayAddress` to the `Address` field in `WebDAVFolderDialog.swift` and `WorkbenchFormControls.swift` so pasting a percent-encoded URL immediately updates the active field editor to human-readable text.
   - Applied `WebDAVAddress.decodedDisplayAddress` across `WebDAVRootConfig`, `WebDAVConfigurationStore` (including existing persisted configurations), and File Level 1/2 WebDAV folder card subtitles.

## Verification

- Automated unit & component tests:
  - `FileRouteNavigationTests`
  - `WebDAVFolderDialogTests`
  - `AppIconAssetTests`
