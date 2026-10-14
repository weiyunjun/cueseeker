# File Page Hierarchy And Grouping Redesign

Human-owned documents:

- `docs/human/requirements/20261014-UI-File Page Hierarchy And Grouping Redesign.md`
- `docs/human/design/UI Design System.md`
- `docs/human/design/UI Application Rules.md`

## Why

1. **Persistent Function Bar**:
   - Previously, the status indicator (`Last Updated...` / indexing progress) and the `Add Folder` / `Index Now` action buttons were only visible on Level 1 (`.file`), hiding global indexing status and folder actions once the user drilled down into Level 2 or Level 3.
2. **Folder Type Grouping & Breadcrumb Evolution**:
   - The generic `Home` (`首页`) root breadcrumb node did not distinguish between `Local Folder` and `WebDAV Folder` roots. Grouping Level 1 root folders under `Local Folder` and `WebDAV Folder` headers (`14px`, `600 Semibold`, `--color-text-primary`) and starting Level 2 / Level 3 breadcrumbs with `[Folder Type] > [Root Folder] (> [Subfolder])` provides immediate source context and a direct way to return to Level 1.
3. **Unwrapping Direct Content & Episode (`Display Title`) Grouping**:
   - Wrapping root-level direct video/subtitle files inside a synthetic `[Folder] (Direct Content)` card added an unnecessary navigation hop. Rendering direct content directly in Level 2 (below any subfolders) and grouping video and subtitle cards by episode (`IndexedContentObject.displayTitle`) inside a single-layer gray rounded container (`--color-settings-group-bg`) with the `Display Title` (`14px`, `500 Medium`, `--color-text-muted`) flush-left above the container clarifies which video and subtitle files belong to the same episode.
   - Adjusting `--color-settings-group-bg`, `--color-table-bg`, `--color-row-hover`, and `--color-row-selected` establishes a clear visual contrast progression in both Light (`#F2F4F7` container > `#F9FAFB` card hover > `#FFFFFF` card default) and Dark (`#1C1C1F` page < `#242429` container < `#2E2E34` card default < `#383840` card hover) modes.
4. **Card Trailing Actions & Chevron**:
   - Showing a persistent, non-clickable right chevron (`caret-right`, `16px`, `--color-text-muted`) on folder cards clearly distinguishes navigable folders from leaf file cards, while revealing the `...` (`dots-three`) menu button only on card hover (or when its menu is open) eliminates visual noise between `...` and `>`.

## What changed

1. **Design Tokens (`WorkbenchRedesignTokens.swift`, `WorkbenchControls.swift`)**:
   - Updated `WorkbenchRedesignColors.NS.settingsGroupBg` (`#F2F4F7` Light / `#242429` Dark), `tableBg` (`#FFFFFF` Light / `#2E2E34` Dark), `rowHover` (`#F9FAFB` Light / `#383840` Dark), and `rowSelected` (`#ECEEF2` Light / `#43434C` Dark).
   - Added `WorkbenchControlMetrics.redesignCardChevronSize` (`16px`).
2. **On-Demand Level 2 Data Loading (`AppCoordinator+Data.swift`)**:
   - Updated `loadFileSubfolders(rootPath:)` to also invoke `loadFileObjects(folderPath: standardized)` so direct content episode groups under a root folder are immediately available in Level 2.
3. **File Page View & Resolvers (`WorkbenchFileView.swift`)**:
   - Moved `statusAndActionRow` to the top of `fileScrollSurface` so it stays persistent across all three levels.
   - Added `FileFolderGroupingResolver` to group Level 1 roots into `Local Folder` and `WebDAV Folder` sections, unwrap direct-content folder entries in Level 2, and filter displayable episode groups.
   - Updated `FileBreadcrumbResolver` to return `[]` on Level 1 and `[Folder Type, Root Folder, (Subfolder)]` on Level 2 and Level 3.
   - Added `episodeGroupsList(objects:folderPath:)` rendering each episode's `Display Title` (`14px`, `500 Medium`, `--color-text-muted`) flush-left above its full-width gray rounded container (`settingsGroupBg`, `10px` radius, `1px` `borderDivider`, `16px` padding).
   - Updated `WorkbenchFileCard` to show the `...` button only when `isHovered || isMenuOpen` (preserving layout space) and render a trailing non-clickable `caret-right` chevron on folder cards (`showsChevron: true`).
4. **Tests (`FileRouteNavigationTests.swift`, `FileCardMenuTests.swift`, `TaskCardMenuTests.swift`)**:
   - Updated breadcrumb resolution tests for Local and WebDAV roots, added unit tests for `FileFolderGroupingResolver.rootGroups` and `level2Partition`, and updated color/chevron token assertions.

## Verification

- `swift test --filter "FileRouteNavigationTests|FileCardMenuTests|TaskCardMenuTests|WorkbenchRouteUnknownTests"`: passed.
- `swift test --filter SubtitleTableVirtualRowTests`: passed.
