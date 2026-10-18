# Rename Folder Current Name Without Full Path

Human-owned documents:

- `docs/human/requirements/20261018-UI-Rename Folder Current Name Without Full Path.md`

## Why

1. Opening `Rename Folder` on the `File` page (both Level 1 root folder cards and Level 2 subfolder cards) previously displayed the full folder path in the `Current Name` row (`LibraryRenameSession.currentText`), even though the user already sees the full path on the card before opening the dialog.
2. `Current Name` in `Rename Folder` should display only the folder name itself (matching the initial `New Name` text field value).

## What changed

- **`LibraryRenameSession` & `LibraryRenameDialog` (`apps/macos-native/Sources/CueSeekerApp/Library/LibraryRenameDialog.swift`)**:
  - Removed the redundant `currentText` property that returned full paths (`folder.folderPath` / `url.path`) and exposed `currentName` (`lastPathComponent` for `.folder` and `.rootFolder`, `baseName` for `.files`).
  - Updated `LibraryRenameDialog` to bind its `Current Name` static text (`rename-current-name`) to `session.currentName`.

## Tests

- Added `renameSessionCurrentNameUsesFolderNameWithoutFullPath` in `FileCardMenuTests` (`apps/macos-native/Tests/CueSeekerAppTests/FileCardMenuTests.swift`) verifying that `.rootFolder` and `.folder` sessions expose only the folder name without parent path components in `currentName`, while `.files` continues to expose the shared base name.
