# 2026-10-23 Remote Folder Browser Checkbox Selection And Single Click Navigation

## Requirement Reference
- `docs/human/requirements/20261023-UI-Remote Folder Browser Checkbox Selection And Single Click Navigation.md`

## Summary of Changes
1. **Checkbox Disabled Style Refinement (`WorkbenchCheckboxStyle.swift`)**:
   - Kept `WorkbenchRedesignColors.NS.textDisabled` for disabled checkboxes while preserving the white inner backing circle (`state != .unchecked`) so disabled checked and indeterminate checkboxes render as a solid gray circle with a crisp white checkmark/dash.
2. **Remote Folder Browser Checkbox, Added Badge & Single-Click Navigation (`RemoteFolderDialogSharedViews.swift`, `WebDAVFolderDialog.swift`, `SMBFolderDialog.swift`, `FTPFolderDialog.swift`, `NFSFolderDialog.swift`, `AppCoordinator+RemoteFolderDialogs.swift`, `Localizable.strings`)**:
   - Split folder cards in `WebDAVBrowserCard` into a full-height left rectangular checkbox button (`onToggleSelection`) and a full-height right folder body button (`onOpenFolder` on single click, clearing previous selections), while keeping file cards without checkboxes and non-interactive.
   - Kept enabled folder card background (`tableBg` default, `rowHover` on hover) and border (`borderControl`) unchanged when checked.
   - Added `existingRootFolders` tracking and `isFolderAlreadyAdded` / `isFolderItemDisabled` checks via `LibraryRootGroups.coveringRoot` so already-added folders and their subfolders render with a disabled gray checked checkbox on the left, replace the trailing `caret-right` chevron with a green `Added` / `已添加` / `已加入` `WorkbenchBadge` (matching `WatchStatusBadge` finished colors) on the right, cannot be toggled or entered, and have no hover highlight.
   - Updated `canAddInBrowser` and `targetFoldersToAdd()` so `Add` is disabled when no folder is checked and either the current directory is already added or all subfolders in the current directory are disabled.

## Verification
- Added and updated unit tests in `WorkbenchCheckboxStyleTests.swift` and `WebDAVFolderDialogTests.swift`.
- Verified with `swift test --package-path apps/macos-native --filter "WorkbenchCheckboxStyleTests|WebDAVFolderDialogTests|SMBFolderDialogTests|FTPNFSFolderDialogTests"` (all 18 tests passed).
- Outcome matched expectations.
