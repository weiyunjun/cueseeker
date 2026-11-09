# 2026-11-10: Anki Export Edge Cases and Task Result Counts

## Requirement Source
- `docs/human/requirements/20261110-Feature-Anki Export Edge Cases And Task Result Counts.md`

## Summary of Changes
1. **Single-Card Failure Isolation & Boundary Validation (`AnkiPackageExporter`, `AppCoordinator+AnkiExport`, `SFXHDRColorPipeline`)**:
   - Checked live library membership (`isInLibrary`) when resolving Anki export items against `LibraryDatabase` and `CueContentDatabase`.
   - Validated required database fields (`Cue Text`, `Display Title`, `Time Range`, `Deep Link`) when included on `Front` or `Back`.
   - Implemented the `Cue Group Text` boundary rule: an empty `Cue Group Text` is omitted when other items exist on that side, and only fails the card when `Front` or `Back` has solely `Cue Group Text` configured and its content is empty.
   - Isolated per-card audio and screenshot extraction into temporary files, verified non-empty output (`fileSize > 0`) and valid media timestamp bounds, cleaned up temporary files on card failure, and continued exporting the remaining cards.
   - Transitioned the task to `Completed` when at least 1 card succeeds, or threw `AnkiPackageExportError.allCardsFailed` (`All cards failed to export` / `全部卡片导出失败` / `全部卡片匯出失敗`) without generating an empty `.apkg` when all cards fail (`succeededCount == 0`).
2. **Task Record Persistence (`DatabaseBootstrap`, `DatabaseBootstrap+Migrations`, `TaskRecordDatabase`)**:
   - Bumped SQLite schema version from `65` to `66` (`migrateSchema65To66`), adding `failed_count INTEGER NOT NULL DEFAULT 0` to `task_records` and backfilling `failed_count = item_count` for existing `incomplete` Anki export records.
   - Added `failedCount`, `ankiSucceededCount`, and `ankiFailedCount` to `TaskRecord` and `updateFailedCount(id:to:)` to `TaskRecordDatabase`.
3. **Task Panel & Task Detail Dialog (`TaskQueueStore`, `TaskPanel`, `Localizable.strings`)**:
   - Updated running Anki export stage text to `%1$d / %2$d cards exported, %3$d unsuccessful` (`已导出 %1$d / %2$d 张卡片，%3$d 张失败` / `已匯出 %1$d / %2$d 張卡片，%3$d 張失敗`) and advanced the progress bar by `(succeeded + failed) / total`.
   - Updated `Completed` Anki export task cards to display the final succeeded card count while keeping `Incomplete` task cards displaying the total card count.
   - Added `Succeeded` and `Failed` rows below `Card Count` in the `Export Info` group of `TaskDetailDialog` for `In Progress`, `Completed`, and `Incomplete` states (`Queued` remains unchanged).

## Verification
- Verified schema migration, task record persistence, Anki export edge-case isolation, and task queue state/count transitions via `DatabaseBootstrapTests`, `TaskRecordDatabaseTests`, `AnkiPackageExporterTests`, `TaskQueueStoreTests`, and `TaskCardMenuTests`.
