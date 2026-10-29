# 2026-10-29 File Detail Paired Files Switcher Menu

## Requirement Reference
- `docs/human/requirements/20261029-UI-File Detail Paired Files Switcher Menu.md`

## Summary of Changes
1. **Paired File Detail Snapshot Resolution (`LibraryDatabase+FileDetail.swift`, `AppCoordinator+FileDetail.swift`)**:
   - Added `FileDetailPairedItem` (`.video(FileDetailVideoInfo)` and `.subtitle(FileDetailSubtitleInfo)`) and `LibraryDatabase.fileDetailPairedItems(forVideoPath:)` / `fileDetailPairedItems(forSubtitlePath:)`, resolving all paired files in an episode group once when `File Info` opens (ordered with the video file first followed by paired subtitle files in their existing order).
   - Updated `AppCoordinator.requestVideoDetail(for:)` and `requestSubtitleDetail(for:)` to initialize `FileDetailDialogSession` with the complete frozen `[FileDetailPairedItem]` snapshot and set `initialSelectedIndex` to the clicked file, ensuring background database mutations while the dialog is open do not alter the displayed or switchable details.
2. **Pinned Top File Switcher Trigger & Full-Width Dropdown Menu (`WorkbenchFileDetailDialog.swift`, `WorkbenchScrollView.swift`, `ContentView.swift`)**:
   - Kept `Folder Info` and `Task Info` dialogs unchanged via `WorkbenchDetailDialogContainer`.
   - Updated `File Info` (`WorkbenchFileDetailDialog` for video and subtitle files) to pin both `WorkbenchDialogHeader` and `FileDetailPairedSwitcherTrigger` in the top non-scrolling region of `WorkbenchDialogColumn`, while the property groups scroll independently below and reset to the top (`scrollController.scrollToTop()`) whenever the selected paired file changes.
   - Implemented `FileDetailPairedSwitcherTrigger` with full dialog content width (`672px`), `--radius-settings-group` (`10px`), `--border-width-control` (`1px`), `--spacing-3` (`12px`) vertical / `--spacing-4` (`16px`) horizontal padding, `40×40px` (`--size-detail-file-icon-container`) file icon, 2-line tail-truncated file name, trailing `16px` (`--size-card-chevron`) `caret-down` icon, and Default / Hover / Open / Pressed state colors.
   - Implemented `FileDetailPairedSwitcherMenuPopover` and `FileDetailPairedMenuItemRow` directly below the trigger (`4px` gap, matching the trigger's full width, height capped to `min(naturalHeight, --max-height-menu 480px, availableSpaceBelowTrigger)`), rendering each paired file without a checkmark, with a leading `18px` (`--size-menu-item-symbol-font-size-macos`) `.video` or `.subtitles` icon aligned with the first line of the multi-line wrapping file name, and registered with `MenuGateClientView` (`owner: .dialog`) for full menu modality and keyboard navigation.

## Verification
- Added unit tests in `FileDetailDatabaseTests.swift` and `FileDetailDialogTests.swift` covering paired item snapshot ordering, frozen snapshot immutability across subsequent database updates, session switching, trigger state colors, and dialog/menu layout in `NSHostingView`.
- Ran `swift test --package-path apps/macos-native --filter "FileDetail"`.
- Outcome matched expectations.
