# Implementation Record: WebDAV Two-Step Folder Selection And Task Queueing

- **Date**: 2026-10-19
- **Requirement**: `docs/human/requirements/20261019-UI-WebDAV Two Step Folder Selection And Task Queueing.md`
- **Design References**:
  - `docs/human/design/ui/UI Index.md`
  - `docs/human/design/ui/UI Tokens.md`
  - `docs/human/design/ui/UI Components - Dialogs & Overlays.md`
  - `docs/human/design/ui/UI Components - Cards & Lists.md`
  - `docs/human/design/ui/UI Layouts - Workbench.md`
  - `docs/human/design/func/Library Management.md`

## Summary of Changes

1. **WebDAV Shallow Directory Listing & Scoped Subfolder Configuration (`WebDAVSupport.swift`)**:
   - Added `WebDAVBrowserItemKind` (`.folder`, `.videoFile`, `.subtitleFile`) and `WebDAVBrowserItem` to represent direct child folders and supported media/subtitle files (`mkv`, `mp4`, `webm`, `flv`, `avi`, `mov`, `srt`, `ass`).
   - Added `WebDAVClient.connectAndBrowseDirectory(address:username:password:)` and `WebDAVClient.browseDirectory(at:baseConfig:)` using `Depth: 1` `PROPFIND` to validate credentials, apply AList `/dav` fallback when needed, filter out unsupported files, and sort folders before files in natural alphabetical order.
   - Added `WebDAVRootConfig.scopedConfig(for:)` so adding either the Step 1 root directory or any nested subfolder produces a standalone `WebDAVRootConfig` with matching logical `rootPath` and effective `davRootPath`.

2. **Two-Step Add WebDAV Folder Dialog (`WebDAVFolderDialog.swift`, `Localizable.strings`, `ContentView.swift`)**:
   - **Step 1 (`.connection`, `480px` width)**: Removed the custom `Name` field and retained `Address`, `Username`, and `Password`. Changed the primary footer button to `Connect` (`webdav.connect`). While validating connection and loading the initial directory, all three inputs and `Connect` are disabled (`0.45` opacity), `Connect` shows a spinner, and any error before the initial directory loads stays on Step 1 as inline red validation text below `Password`.
   - **Step 2 (`.browser`, `720px` width × `500px` height)**: Added a breadcrumb bar (`22px` height, `13px` text, `12px` `caret-right` separator) rooted at the Step 1 folder name so parent directories above the entered address are never exposed.
   - Rendered single-line browser cards (`68px` min-height, `36 × 36px` icon container, `14px` Medium single-line title; trailing `16px` `caret-right` chevron on folders only) inside a 2-column grid with the scrollbar in the rightmost `24px` dialog inset channel.
   - Implemented single-click multi-selection for folder cards within the current level (`WorkbenchRedesignColors.libraryMediaCardHoverBg` background, `WorkbenchRedesignColors.borderActive` border, and **no hover effect while selected**; unselected folder cards use `WorkbenchRedesignColors.rowHover` on hover; file cards are non-clickable with no hover state).
   - Implemented double-click subfolder navigation, breadcrumb navigation, and `Back` (`common.back`), each clearing current selection; `Back` returns to Step 1 while preserving `Address`, `Username`, and `Password` (inputs are cleared only when closing the dialog).
   - Added centered `WorkbenchSpinner` (`18px`) during subfolder loading and centered `WorkbenchEmptyHint` on subfolder load failure or empty directory, keeping `Add` disabled until a valid directory listing is active.

3. **Sequential Multi-Folder Add Task Queueing (`TaskQueueStore.swift`, `AppCoordinator+Indexing.swift`)**:
   - Added `TaskQueueStore.enqueueAddFolders(_:)` and `onCancelQueuedAddFolder` so adding multiple selected WebDAV folders enqueues separate `Add Folder` tasks in top-to-bottom display order (first task `.running`, remaining tasks `.queued`) and advances sequentially as each folder finishes indexing.
   - Updated `AppCoordinator.confirmAddWebDAVFolders()` to add the current browsed directory when no subfolder is selected, or add all selected subfolders in display order when one or more subfolders are selected.

## Verification

- Verified `WebDAVSupportTests`, `WebDAVFolderDialogTests`, `AppLocalizationTests`, `TaskQueueStoreTests` (`enqueueAddFoldersStartsFirstAndQueuesRemainingInOrder`), and `LibraryFolderAdditionTests` via `swift test` (30 tests across 5 suites passed).
