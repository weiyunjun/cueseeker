# 2026-10-18: Unify Subtitle Tombstone and Cue Recovery on Reindex

Human-owned documents:

- `docs/human/requirements/20261018-Bug-Unify Subtitle Tombstone And Cue Recovery On Reindex.md`
- `docs/human/design/foundation/Data.md`
- `docs/human/design/foundation/Cue Parsing.md`

## Why

- Previously, when a paired video file was deleted while its subtitle file remained on disk (e.g., `1.mp4` deleted, leaving only `1.srt`), `SubtitleIndexer` still inserted `1.srt` into `keptSubtitlePaths` and `IndexingDatabase.publishLibraryIndex` only deleted the matched video row (`removeMatchedVideos`), leaving `1.srt` and all its cues in active index tables (`subtitle_files`, `subtitle_cue_groups`, `subtitle_cue_lines`) without snapshotting Excerpt-referenced cues into `cue_tombstones`.
- Conversely, when a subtitle file was deleted and later restored at the same path and paired with a video, `upsertSubtitleFile` inserted a new `subtitle_files` row with a new `id`, and `storedCueStates(subtitleFileID:)` only queried `cue_tombstones` by the new `subtitle_file_id`, failing to reconcile and restore the tombstoned `CueID`s for that `subtitle_path`.

## What changed

- **`SubtitleIndexer.swift`**:
  - Stopped inserting subtitles without a matched video into `keptSubtitlePaths`, so any subtitle that loses its video pairing leaves the active index on reindex while still recording its path in `missingVideoSubtitleFiles`.
- **`IndexingDatabase.swift` & `IndexingDatabase+Rename.swift`**:
  - Updated `publishLibraryIndex` and `removeIndexedDataInCurrentTransaction` to pass `missingVideoSubtitlePaths`, snapshotting Excerpt-referenced cues into `cue_tombstones` with `.videoMissing` when the subtitle file remains on disk (or `.subtitleMissing` / `.libraryUnavailable` when the subtitle or library is absent) before removing the stale subtitle and video rows from active tables.
  - Added `reconcileDetachedTombstoneUnavailableReasons` so already-tombstoned cues whose subtitle file is not in `subtitle_files` transition between `.videoMissing` and `.subtitleMissing` / `.libraryUnavailable` when the on-disk subtitle file appears or disappears without a paired video (while preserving `.cueMissing` priority).
  - Added `adoptTombstones(forSubtitleFile:subtitleFileID:)` in `upsertSubtitleFile` so returning subtitles at the same `subtitle_path` adopt existing `cue_tombstones` rows before `storedCueStates` and `CueIdentityReconciler.reconcile` run, restoring matched cues with their original `CueID` and deleting their tombstones.
  - Included `cue_tombstones` when updating `subtitle_path` by `subtitle_file_id` in `applyRename`.
- **`SubtitleIndexerTests.swift` & `IndexPathIdentityTests.swift`**:
  - Updated `referencedCueTombstoneSurvivesMissingResourcesAndReturningFiles` and `referencedCueIsTombstonedWhenItsLibraryIsRemoved` to verify unified Tombstone creation on missing video, active table cleanup, detached tombstone reason transitions, and `CueID` recovery when paired files return at the same path.

## Verification

- Verified `SubtitleIndexerTests`, `IndexPathIdentityTests`, `IndexingDatabaseTests`, `ExcerptDatabaseTests`, and `LibraryRenamerTests` (78 tests) pass via `swift test --package-path apps/macos-native`.
