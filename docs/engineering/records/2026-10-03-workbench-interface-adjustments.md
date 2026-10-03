# Workbench Interface Adjustments

Human-owned documents:

- `docs/human/requirements/20261003-UI-Workbench-Interface-Adjustments.md`
- `docs/human/design/UI Design System.md`
- `docs/human/design/UI Application Rules.md`

## Why

1. **Workbench Visual & Structural Polish**:
   - The Library level 1 interface previously displayed an extra summary row ("xx Folders · yy Videos · zz Subtitles" with an "Add Folder" button) and "Video / Metadata" tabs, when adding folders and inspecting raw metadata is already fully handled by the dedicated File page.
   - The Library level 2 interface previously included a "Video / Metadata" tab switcher and a file tree, adding unnecessary complexity.
   - In Recent, the category switcher tabs ("Recent Videos" / "Recent Excerpt Lists") were aligned to the left edge rather than centered, inconsistent with the centered tabs in Playback Overlay and Task Panel.
   - Secondary page titles in the App topbar were hidden or fell back to "Unknown Page" when target folders or lists were missing/deleted.

## What changed

1. **TopBar & Secondary Page Titles**:
   - In `ContentView.swift`, updated `AppTopBar.pageTitle(for:)` so that `.library` and `.libraryFolder` consistently return `Library`, and `.excerpt` and `.excerptList` consistently return `Excerpt`.
   - Exposed `AppTopBar.pageTitle(for:)` as an internal static method for direct unit test verification.
2. **Missing/Unknown Route Feedback**:
   - Added `library.folder.not_found` and `excerpt.list.not_found` across English, Simplified Chinese, and Traditional Chinese localization files.
   - In `WorkbenchTestLibraryView.swift`, when a library folder route is unknown, displays `WorkbenchEmptyHint(message: L("library.folder.not_found"))`.
   - In `SearchView.swift`, when an excerpt list route is unknown, displays `WorkbenchEmptyHint(message: L("excerpt.list.not_found"))`.
   - Removed unused `WorkbenchUnknownPage`.
3. **Recent Tabs Centering**:
   - In `WorkbenchRecentView`, wrapped `sectionTabs` with `HStack { Spacer(); sectionTabs; Spacer() }` and removed `isLeadingEdgeAligned: true` so the two category tabs are centered horizontally across the page content.
4. **Library Level 1 Streamlining**:
   - Removed summary text, `Add Folder` button, `segmentTabs`, and metadata view.
   - Directly renders `completeLibraryContent` (folder cards grid) inside `WorkbenchScrollView` with standard page padding.
5. **Library Level 2 Streamlining**:
   - Removed `segmentTabs` and metadata file tree content.
   - Positioned `CompleteLibraryEpisodeGrid` directly under `folderCoverSummary` with standard 24px gap (`redesignCoverSummaryToolbarGap`).
6. **Legacy Metadata File Tree Cleanup**:
   - Deleted obsolete `LibraryFileTree.swift`.
   - Removed `fileTreeContent`, `fileTreeFolder`, `LibraryContentSegment`, and related state from `WorkbenchTestLibraryView.swift`.
   - Retained `fileTreeRoots` and `hydrateLibraryFileTreeAsync` on `LibraryStore` and `AppCoordinator` for the File page (`WorkbenchFileView`).

## Verification

- Automated tests:
  - `swift build --package-path apps/macos-native`: Succeeded with 0 errors.
  - `swift test --package-path apps/macos-native --filter WorkbenchRouteUnknownTests`: 3/3 passed (including new tests for titles across levels and missing item localization strings).
  - `swift test --package-path apps/macos-native --filter WorkbenchPageScrollbarTests`: 4/4 passed.
  - `swift test --package-path apps/macos-native --filter WorkbenchEmptyHintTests`: 1/1 passed.
