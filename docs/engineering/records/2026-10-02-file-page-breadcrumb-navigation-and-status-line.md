# File Page Breadcrumb Navigation and Status Line

Human-owned documents:

- `docs/human/requirements/20261002-UI-File Page Breadcrumb Navigation And Status Line.md`
- `docs/human/design/UI Design System.md`
- `docs/human/design/UI Application Rules.md`
- `docs/human/design/Icon Registry.md`

## Why

1. **Information Architecture Polish**:
   - The File page previously showed a large text block at the top, consuming vertical screen real estate without providing ongoing value once the user understands how the page works.
   - Users needed clear hierarchical breadcrumbs (`Home > [Indexed Path] > [Folder]`) to see where they are in the folder hierarchy and jump back to upper levels with a single click.
2. **Status and Actions Alignment**:
   - Detailed progress/task stream belongs in the dedicated Task panel. The File page's Level 1 header needed a concise, single-line status indicator (40px high) balanced against the action buttons (`Add Folder` and `Index Now`), and hidden entirely on subfolder/file levels.
   - Status represents 4 core states: Completed (`checkCircle`, success color), Indexing (`WorkbenchSpinner`, secondary color), Failed (`warning`, danger color), and Idle (`arrowClockwise`, secondary color with last indexed date or `--`).
3. **Display Robustness and Edge Cases**:
   - Breadcrumb navigation remains stable even if all files in a folder become missing or removed from the database.
   - Empty hints (`WorkbenchEmptyHint`) are only shown when there are truly no displayable items and the folder is not in a loading state (which displays `WorkbenchSpinner`).

## What changed

- **Icon Registry & Line Width**:
  - Registered `12: 1.15` in `AppIconLineWidth.bySize` in `AppIcon.swift` to support 12px `caretRight` outline icon as the breadcrumb separator.
- **Spinner Control Enhancement**:
  - In `WorkbenchSpinner.swift`: added optional `size: CGFloat = WorkbenchControlMetrics.redesignSpinnerSize` initializer parameter (default 16px) to allow rendering 18px spinners for the File status row and loading views.
- **Localization**:
  - Added strings to `en.lproj`, `zh-Hans.lproj`, and `zh-Hant.lproj`:
    - `file.breadcrumb.home`: "Home" / "首页" / "首頁"
    - `file.status.indexed`: "Indexed %@" / "已完成索引: %@" / "已完成索引: %@"
    - `file.status.indexed_all`: "Indexed All Folders" / "已完成全部索引" / "已完成全部索引"
    - `file.status.indexing`: "Indexing %@" / "正在索引: %@" / "正在索引: %@"
    - `file.status.indexing_all`: "Indexing All Folders" / "正在索引全部文件夹" / "正在索引全部資料夾"
    - `file.status.failed`: "Index Failed: %@" / "索引失败: %@" / "索引失敗: %@"
    - `file.status.last_indexed`: "Last Indexed: %@" / "上次索引: %@" / "上次索引: %@"
    - `file.status.last_indexed_never`: "Last Indexed: --" / "上次索引: --" / "上次索引: --"
- **IndexingStore Timestamp Tracking**:
  - Added `lastIndexedDate: Date?` to `IndexingStore` with persistence to `UserDefaults` (key: `"lastIndexedTimestamp"`).
  - Automatically records timestamp whenever indexing transitions to `.completed` or `.completedAll`.
- **WorkbenchFileView**:
  - Removed top `pageDescription` text block.
  - Implemented `breadcrumbRow` with `FileBreadcrumbResolver` at the top of `fileScrollSurface`:
    - Level 1: `Home` (active, 14px Semibold, `--color-text-primary`).
    - Level 2: `Home` (clickable link, 14px Medium `--color-text-secondary`, hover `--color-text-primary`) > `caretRight` (12px 1.15px muted) > `rootName` (active).
    - Level 3: `Home` (link) > `rootName` (link) > `folderName` (or `folderName (Direct Content)` if direct content) (active).
  - Replaced legacy multi-line status with `statusAndActionRow` (40px height):
    - Displayed only on Level 1 (Home).
    - Left side: 4-state indicator (Completed, Indexing with `WorkbenchSpinner`, Failed, Idle with last indexed timestamp or `--`).
    - Right side: `[Add Folder]` and `[Index Now]` action buttons.
  - Updated empty state and loading views:
    - In Level 2 and Level 3, loading states render `WorkbenchSpinner(size: 18)`.
    - Empty hints are only shown after loading completes and displayable item count is verified to be 0.

## Tests

- `FileRouteNavigationTests`:
  - `fileThreeLevelNavigationAndHistoryFlow`: verified 3-level forward/backward route navigation.
  - `fileSidebarSwitchingBehavior`: verified that navigating from File Level 2/3 to other sidebar tabs and clicking File returns to Level 1 (`.file`), and clicking File while already on File does not trigger navigation.
  - `fileBreadcrumbResolution`: verified breadcrumb resolution for Level 1, Level 2, Level 3 (standard and direct content), ensuring destinations and active states match requirements.
  - `indexingStoreLastIndexedDatePersistence`: verified initial nil state, persistence and rehydration across `UserDefaults`, and automatic timestamp recording on `.completedAll`.
