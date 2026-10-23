# 2026-10-23 Task Detail Dialog

## Requirement Reference
- `docs/human/requirements/20261023-Feature-Task Detail Dialog.md`

## Summary of Changes
1. **Task Start Timestamp Persistence (`DatabaseBootstrap.swift`, `DatabaseBootstrap+Migrations.swift`, `TaskRecordDatabase.swift`)**:
   - Upgraded SQLite schema version from `60` to `61`, adding `started_at TEXT` to `task_records` and migrating existing schema 60 databases via `migrateSchema60To61`.
   - Added `startedAt: Date?` to `TaskRecord` and updated `TaskRecordDatabase.updateState` and `TaskRecord.withState` so transitioning to `.running` records `startedAt` (`COALESCE(started_at, ?)`), while transitioning to `.completed` or `.incomplete` preserves `startedAt` (leaving `startedAt` as `nil` for tasks cancelled or interrupted while still `.queued`).
2. **Task Detail State & Dialog Stacking (`TaskQueueStore.swift`, `ContentView.swift`, `TaskPanel.swift`)**:
   - Added `detailTaskID`, `openTaskDetail(id:)`, `closeTaskDetail()`, and `taskDetailSnapshot(for:)` on `TaskQueueStore`, looking up the live task across `current`, `completed`, and `incomplete`, and clearing `detailTaskID` when closing the task panel or deleting the viewed record.
   - Prepended `Get Info` (`查看详情` / `查看詳情`, icon `.info`, Neutral) to all task card `...` menus in `TaskPanel`; if a `Current` task finishes while its menu remains open, clicking `Get Info` opens the Task Detail Dialog showing its latest state.
   - Stacked `TaskDetailDialog` at `.workbenchDialog(level: 2)` above `TaskPanel` (`isCovered: confirmation.session != nil || tasks.detailTaskID != nil`) and yielded `TaskPanel`'s `Esc` shortcut while covered.
3. **Task Detail Dialog Layout, Scoped Live Progress & Localization (`TaskPanel.swift`, `WorkbenchFileDetailDialog.swift`, `Localizable.strings`)**:
   - Implemented `TaskDetailDialog` aligned with `WorkbenchFileDetailDialog` (`--width-dialog-x-large`, `40×40` task icon + `24px` spacing + pure task type title, business groups on top, and `Task Status` group at the bottom).
   - Isolated `@ObservedObject var progress: TaskProgressModel` inside `TaskDetailRunningRows` so progress ticks only refresh the `Current Stage` and `Progress` rows without rebuilding the rest of the dialog.
   - Added `task_detail.*` localization strings across English, Simplified Chinese, and Traditional Chinese.

## Verification
- Added and updated unit tests in `DatabaseBootstrapTests.swift`, `TaskRecordDatabaseTests.swift`, `TaskCardMenuTests.swift`, and `TaskQueueStoreTests.swift`.
- Verified with `swift test --filter "TaskRecordDatabaseTests|DatabaseBootstrapTests|TaskCardMenuTests|TaskQueueStoreTests"` (82/82 tests passed).
- Outcome matched expectations.
