# File page three level card redesign

Human-owned documents:

- `docs/human/requirements/20260926-UI-File Page Three Level Card Redesign.md`
- `docs/human/design/UI Design System.md`
- `docs/human/design/UI Application Rules.md`
- `docs/human/design/Icon Registry.md`

## Why

The File page was previously divided into separate Index and Edit tabs with tree-disclosure rows and dividing lines. Following the unified card-based UI redesign, Index and Edit are integrated into a single three-level database-driven card flow:
1. Level 1: Root directory cards with indexing controls and status.
2. Level 2: Subfolder cards representing indexed subfolders and root direct content under the selected root.
3. Level 3: Sequential video and subtitle file cards displaying file sizes and in-place rename actions.
All cards use unified card metrics, vertical-centered alignment, and integrate with the workbench history navigation stack (`<` and `>` buttons) while maintaining a persistent "File" topbar title.

## What changed

- **Card layout & tokens**: Created `WorkbenchFileCard` with 16px (`--spacing-4`) uniform padding, 8px corner radius (`--radius-control`), 1px border (`--color-border-control`), and `--color-settings-group-bg` background. Cards are spaced 12px (`--spacing-3`) apart without dividing lines. Left icon (31×31px), text stack, and trailing buttons are vertically centered (`HStack(alignment: .center)`). Text lines use `fixedSize` to force full multi-line wrap without truncation.
- **Three-level navigation & route state**:
  - Extended `WorkbenchRoute` with `.fileFolder(rootPath: String)` and `.fileFiles(rootPath: String, folderPath: String)`.
  - Updated `WorkbenchRouteState` and `WorkbenchLayoutState` to manage `selectedFileRootPath` and `selectedFileFolderPath` and navigate history steps.
  - Bound topbar `<` and `>` buttons to push and pop across the three levels, with page title persistently showing localized `sidebar.file` ("File").
- **Database file size querying**:
  - Added `fileSize: Int64` to `IndexedContentObject` and `IndexedContentSubtitle`.
  - Updated `IndexedContentDatabase` to load `vf.file_size` and `sf.file_size` from SQLite and map them into the builder snapshots.
  - Implemented `FileSizeFormatter` with binary 1024 base and 2 decimal places (`B`, `KB`, `MB`, `GB`, `TB`).
- **Renaming support**:
  - Extended `LibraryRenameSession` with `.rootFolder(URL)` target to support in-place renaming of level 1 roots alongside subfolders and file groups.
  - Added `requestRootFolderRename(_:)` in `AppCoordinator+LibraryRename.swift`.
  - Maintained group-level file renaming in level 3.
- **Localization & empty state**:
  - Added localized strings for `file.empty_folder_items` and `file.direct_content_suffix` across `en`, `zh-Hans`, and `zh-Hant`.
  - Added empty state feedback when level 2 or level 3 folders contain no items in the library.
- **Unit testing**:
  - Added `FileSizeFormatterTests` covering byte thresholds, rounding, and negative values.
  - Added `FileRouteNavigationTests` verifying three-level forward/backward route transitions and history state.

Files:

- `apps/macos-native/Sources/CueSeekerCore/IndexedContentDatabaseModels.swift`
- `apps/macos-native/Sources/CueSeekerCore/IndexedContentDatabase.swift`
- `apps/macos-native/Sources/CueSeekerCore/FileSizeFormatter.swift`
- `apps/macos-native/Sources/CueSeekerApp/App/WorkbenchLayoutState.swift`
- `apps/macos-native/Sources/CueSeekerApp/App/AppCoordinator.swift`
- `apps/macos-native/Sources/CueSeekerApp/App/AppCoordinator+LibraryRename.swift`
- `apps/macos-native/Sources/CueSeekerApp/Library/LibraryRenameDialog.swift`
- `apps/macos-native/Sources/CueSeekerApp/Library/WorkbenchFileView.swift`
- `apps/macos-native/Sources/CueSeekerApp/Workbench/ContentView.swift`
- `apps/macos-native/Sources/CueSeekerApp/Resources/en.lproj/Localizable.strings`
- `apps/macos-native/Sources/CueSeekerApp/Resources/zh-Hans.lproj/Localizable.strings`
- `apps/macos-native/Sources/CueSeekerApp/Resources/zh-Hant.lproj/Localizable.strings`
- `apps/macos-native/Tests/CueSeekerCoreTests/FileSizeFormatterTests.swift`
- `apps/macos-native/Tests/CueSeekerAppTests/FileRouteNavigationTests.swift`

## Verification

- `swift build --package-path apps/macos-native`: passed with 0 errors.
- `swift test --package-path apps/macos-native --filter FileSizeFormatterTests`: 5 tests passed.
- `swift test --package-path apps/macos-native --filter FileRouteNavigationTests`: 1 test passed.
