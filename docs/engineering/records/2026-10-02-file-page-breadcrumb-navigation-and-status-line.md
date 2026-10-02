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
- **IndexingStore & Database Operations**:
  - Added `DatabaseOperationNotice` enum (`indexed`, `indexedAll`, `removed`, `indexFailed`, `removalFailed`) and `operationNotice: DatabaseOperationNotice?` published property.
  - Added `lastUpdatedDate: Date?` (with `lastIndexedDate` compatibility alias) persisting to `"lastUpdatedTimestamp"` and `"lastIndexedTimestamp"`.
  - Added `isDatabaseOperationActive: Bool` (`indexingStatus.isIndexing || folderRemovalStatus.isRemoving`).
  - Added `clearTransientNotice()` to reset `operationNotice` and `removedFolderNotice` when navigating away from Level 1.
  - Integrated `didSet` hooks on `indexingStatus` and `removedFolderNotice` to automatically record the timestamp and set the appropriate operation notice upon task completion or failure.
- **WorkbenchFileView**:
  - Removed top `pageDescription` text block.
  - Implemented `breadcrumbRow` with `FileBreadcrumbResolver` at the top of `fileScrollSurface`:
    - Level 1: `Home` (active, 14px Semibold, `--color-text-primary`).
    - Level 2: `Home` (clickable link, 14px Medium `--color-text-secondary`, hover `--color-text-primary`) > `caretRight` (12px 1.15px muted) > `rootName` (active).
    - Level 3: `Home` (link) > `rootName` (link) > `folderName` (or `folderName (Direct Content)` if direct content) (active).
  - Implemented `FileStatusResolver` and `FileStatusInfo`:
    - In progress: `WorkbenchSpinner(18px)` + `Indexing [Folder]` / `Indexing All Folders` / `Removing [Folder]`.
    - Completed: `checkCircle` + `Indexed [Folder]` / `Indexed All Folders` / `Removed [Folder]`.
    - Failed: `warning` + `Index Failed: [Folder]` / `Removal Failed: [Folder]`.
    - Idle: `arrowClockwise` + `Last Updated: yy-MM-dd HH:mm` (using project-wide standard date format) or `Last Updated: --`.
  - Lifecycle management:
    - Added `.onAppear` and `.onDisappear` on `rootContent`, plus `.onChange(of: routeState.currentRoute)`: when leaving Level 1 or returning to Level 1 while idle, transient notices are cleared, cleanly restoring the Idle status.
  - Updated empty state and loading views:
    - In Level 2 and Level 3, loading states render `WorkbenchSpinner(size: 18)`.
    - Empty hints are only shown after loading completes and displayable item count is verified to be 0.

## Tests

- `FileRouteNavigationTests`:
  - `fileThreeLevelNavigationAndHistoryFlow`: verified 3-level forward/backward route navigation.
  - `fileSidebarSwitchingBehavior`: verified that navigating from File Level 2/3 to other sidebar tabs and clicking File returns to Level 1 (`.file`), and clicking File while already on File does not trigger navigation.
  - `fileBreadcrumbResolution`: verified breadcrumb resolution for Level 1, Level 2, Level 3 (standard and direct content), ensuring destinations and active states match requirements.
  - `indexingStoreLastUpdatedDatePersistence`: verified initial nil state, persistence and rehydration across `UserDefaults`, and automatic timestamp recording on `.completedAll`.
  - `databaseOperationNoticesAndLifecycle`: verified operation notice assignment on indexing/removal completion and failure, and transient clearing.
  - `fileStatusResolverAllDatabaseOperationsAndTransitions`: verified state mapping across all database operations (in progress, completed, failed, idle with `yy-MM-dd HH:mm`, and idle never).
