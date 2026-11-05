# File Detail Snapshot Persistence And Entrance Animation Smoothness

## Summary

- Requirement: `docs/human/requirements/20261105-Performance-File Detail Snapshot Persistence And Entrance Animation Smoothness.md`
- Upgraded the SQLite database schema from version `64` to `65`, adding `encoding TEXT` to `subtitle_files` and persisting the detected subtitle character encoding (`UTF-8`, `UTF-8 (BOM)`, `UTF-16 LE`, `UTF-16 BE`, `GB18030`, `Shift-JIS`, `Big5`, `EUC-KR`, `Windows-1252`, `ISO-8859-1`) during indexing (`SubtitleIndexer` + `IndexingDatabase`).
- Extended unchanged-file re-indexing (`PreparedSubtitleRawCueCountRefresh`) to backfill `encoding` alongside `raw_cue_count` for legacy rows without marking content changes or triggering automatic database compaction.
- Removed all real-time disk and remote cache I/O (`FileManager.default.attributesOfItem` and `WebDAVSubtitleCache.shared.readSubtitleData` / `SubtitleTextDecoder`) from `LibraryDatabase+FileDetail.swift` and `AppCoordinator+FileDetail.swift` so `Get Info` reads 100% from the SQLite index snapshot (`"-" ` when `encoding` is `NULL`).
- Eliminated the 270ms entrance animation frame drops by isolating `fileDetailSession` into `FileDetailDialogCenter`, handing off `.dialog` layer freeze and dialog accessibility focus synchronously when opening `File Detail`, suppressing redundant `WorkbenchAccessibilityCoordinator` invalidations when `focusedDialogTarget == nil`, caching `WorkbenchDialogColumn` subview measurements, deferring `WorkbenchFileDetailDialog` geometry `@State` writes while the paired-switcher menu is closed, and converting `WorkbenchCardRightClickMonitor` to a shared single-monitor event dispatcher without per-card `\.interfaceLayerContext` invalidation.

## Verification

- `swift test --filter "DatabaseBootstrapTests|FileDetailDatabaseTests|FileDetailDialogTests"`
