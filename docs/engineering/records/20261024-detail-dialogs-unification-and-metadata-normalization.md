# 20261024 Detail Dialogs Unification and Metadata Normalization

## 1. Requirement Reference

- Requirement: `docs/human/requirements/20261024-UI-Detail Dialogs Unification And Metadata Normalization.md`
- Stabilized Design References:
  - `docs/human/design/ui/UI Index.md`
  - `docs/human/design/ui/UI Primitive And Layout.md`
  - `docs/human/design/ui/UI Composite.md`
  - `docs/human/design/ui/UI Component.md`
  - `docs/human/design/ui/UI Page.md`
  - `docs/human/design/ui/UI Scenario.md`

## 2. Implementation Summary

1. **Shared Detail Dialog Components (`WorkbenchDialogHeader.swift`, `WorkbenchDialogLayer.swift`, `WorkbenchControlMetrics.swift`)**:
   - Extended `WorkbenchDialogColumn` to support 2-subview dialogs (`Header + ScrollView`) by clamping the scroll view height when no footer is present.
   - Created `WorkbenchDetailDialogContainer` and `WorkbenchDetailHeaderRow` (using `--spacing-4` / `16px` horizontal gap between the `40×40px` icon and title), shared across `WorkbenchFileDetailDialog` (Folder, Video, Subtitle) and `TaskDetailDialog`.
   - Removed the redundant inner `.clipShape` and `.strokeBorder(WorkbenchRedesignColors.borderDivider)` from `TaskDetailDialog` so `WorkbenchDialogChrome` provides the canonical `C-10.1 Dialog` border (`--border-subtle`).
   - Created `WorkbenchDetailRow` (`FileDetailRow`), `WorkbenchDetailIndexedRows` (displaying `#1  None` / `无` / `無` when empty), and `WorkbenchProgressBar` (`C-09.3 Progress Indicator / Bar`), with `WorkbenchControlMetrics.redesignTaskDetailProgressBarWidth = 140` (`--width-task-detail-progress-bar`).
2. **Metadata Normalization (`LibraryDatabase+FileDetail.swift`, `AppCoordinator+FileDetail.swift`, `WorkbenchFileDetailDialog.swift`)**:
   - Centralized video codec display names, file format names, and number/date/duration formatting into `MediaDetailFormatter` in `CueSeekerCore`.
   - Unified video and subtitle detail `File Size` formatting to use `FileSizeFormatter.format(bytes:)` (`1024` binary base, 2 decimal places).
   - Updated Folder Detail `Path` row to directly read `RemoteAddressParser.decodedDisplayAddress(info.path)`.
   - Filtered `Audio #N` cards in Video Detail so they are only rendered when valid audio tracks with displayable properties exist.
   - Updated unindexed/unreadable subtitle fallback encoding to `"-"` instead of `"UTF-8"`.
   - Updated Subtitle Detail `Raw Lines` and `Valid Lines` to display pure Arabic numerals.
3. **Localization Unification (`Localizable.strings`)**:
   - Unified `file_detail.get_info` and `task_detail.get_info` to `"查看详情"` / `"查看詳情"` / `"Get Info"`.
   - Unified `file_detail.path`, `task_detail.path`, and `task_detail.location` in Chinese to `"位置"`.
   - Unified `file_detail.folder_count`, `file_detail.video_count`, and `file_detail.subtitle_count` in Chinese to `"文件夹数量"` / `"视频数量"` / `"字幕数量"` (Traditional Chinese: `"資料夾數量"` / `"影片數量"` / `"字幕數量"`).

## 3. Verification

- Executed `swift test --package-path apps/macos-native --filter "FileDetailDialogTests|FileDetailDatabaseTests|TaskCardMenuTests"` (21 tests passed).
- Executed `swift test --package-path apps/macos-native --filter "WorkbenchControlMetricsTests"` (17 tests passed).
- All unit and database tests matched expectations.
