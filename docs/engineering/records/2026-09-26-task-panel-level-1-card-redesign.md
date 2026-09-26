# Task panel level 1 card redesign

Human-owned documents:

- `docs/human/requirements/20260926-UI-Task Panel Level 1 Card Redesign.md`
- `docs/human/design/UI Design System.md`
- `docs/human/design/UI Application Rules.md`
- `docs/human/design/Icon Registry.md`

## Why

The task panel's level 1 card layout previously included state badges, delete/remove icon buttons on individual cards, and verbose multi-line file paths. Following the unified design specification, the level 1 interface is simplified into a clean, read-only layout where cards display categorized vector icons, unified 14px 500 Medium titles, concise single-line subtitles, and a 16px fixed-height dynamic row (hosting the progress bar for running tasks or the error message for incomplete tasks), while deferring task cancellation and deletion actions to a future level 2 view.

## What changed

- **Card metrics & container**: Updated `TaskCardContainer` to use `--spacing-4` (16px) uniform padding, 8px border radius, 1px border (`--color-border-control`), dialog background (`--color-bg-dialog`), and `--spacing-4` (16px) gap between the icon and text column. Card gap in the list is 12px (`--spacing-3`).
- **Icons & Y-anchor rule**: Added `--size-task-card-icon` (31px) token in `WorkbenchControlMetrics` matching `Icon Registry.md`. Icons are top-anchored at 16px (`alignment: .top`) and styled as naked vectors using `--color-text-secondary`:
  - Anki export: `ankiStar` (`anki-star`)
  - Folder & file rename: `pencilSimple` (`pencil-simple`)
  - Index: `arrowClockwise` (`arrow-clockwise`)
  - Add Folder: `folderPlus` (`folder-plus`)
  - Remove Folder: `minusCircle` (`minus-circle`)
- **Title line (Line 1)**: Unified entire title as a single string styled with 14px (`--font-size-body`), weight 500 Medium (`--font-weight-control`), and `--color-text-primary`:
  - Export to Anki: `Export to Anki: xx` / `导出到 Anki：xx` / `匯出至 Anki：xx`
  - Rename Folder: `Renaming Folder: xx` / `重命名文件夹：xx` / `重新命名資料夾：xx`
  - Rename Files: `Renaming Files: xx` / `重命名文件：xx` / `重新命名檔案：xx`
  - Index: `Index` / `索引`
  - Add Folder: `Add Folder: xx` / `添加文件夹：xx` / `加入資料夾：xx`
  - Remove: `Remove: xx` / `移除：xx` / `移除：xx`
  - Action prefixes localized across `en`, `zh-Hans`, and `zh-Hant` (Chinese uses full-width colon `：` without spaces).
- **Subtitle line (Line 2)**: Formatted as 12px caption with weight 400 and `--color-text-muted`:
  - Current (Running): Progress stage text (or `xx/yy cards exported` for Anki).
  - Current (Queued): `Queued  xx cards` for Anki (2 spaces); `Queued` for others.
  - Completed: `xx cards  time` for Anki (2 spaces); `xx files  time` for file rename (2 spaces); `time` for others.
  - Incomplete: Formatted identically to Completed with failure timestamp.
- **Dynamic row (Line 3, 16px fixed height)**:
  - In Progress: Displays 4px Capsule progress bar (`--height-task-progress-bar: 4px`, track `--color-library-progress-track`, fill `--color-library-progress-fill`) vertically centered inside 16px frame for Anki, Rename, Index, and Add Folder.
  - Incomplete: Displays single-line tail-truncated error message (`--font-size-caption: 12px`, `--color-danger-text`) inside 16px frame.
- **Buttons and badges removed**: Removed card-level `WorkbenchBadge` (In Progress / Queued) and `WorkbenchIconButton` (close/delete buttons) from level 1 cards.
- **Task enqueueing metadata**: Updated `enqueueRename`, `enqueueAddFolder`, and `enqueueRemoveFolder` in `TaskQueueStore` to populate `record.fileName` with target name for clean title presentation.
- **Unit test coverage**: Unit tests in `TaskQueueStoreTests.swift` covering icons, title action prefixes, target names, enqueued task filenames, and full `displayTitle` strings.

Files:

- `apps/macos-native/Sources/CueSeekerApp/Shared/WorkbenchControls/WorkbenchControls.swift`
- `apps/macos-native/Sources/CueSeekerApp/Tasks/TaskPanel.swift`
- `apps/macos-native/Sources/CueSeekerApp/Tasks/TaskQueueStore.swift`
- `apps/macos-native/Sources/CueSeekerApp/Resources/en.lproj/Localizable.strings`
- `apps/macos-native/Sources/CueSeekerApp/Resources/zh-Hans.lproj/Localizable.strings`
- `apps/macos-native/Sources/CueSeekerApp/Resources/zh-Hant.lproj/Localizable.strings`
- Tests: `apps/macos-native/Tests/CueSeekerAppTests/TaskQueueStoreTests.swift`

## Verification

- `swift build`: passed with 0 errors.
- `swift test --filter TaskQueueStoreTests`: 29 tests passed.
