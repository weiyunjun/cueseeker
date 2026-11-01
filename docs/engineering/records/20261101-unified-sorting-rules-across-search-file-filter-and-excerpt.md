# Unified Sorting Rules Across Search, File, Filter, and Excerpt

- **Date**: 2026-11-01
- **Requirement**: `docs/human/requirements/20261101-Bug-Unified Sorting Rules Across Search File Filter And Excerpt.md`
- **Scope**: `Search` default & character-count tie-break sorting, `File` Level 2 subfolder & Level 2/3 episode group subtitle sorting, `Filter` dialog `Folder` facet fallback sorting, `File Detail` paired subtitle ordering, and `Excerpt` `Earliest Date Added` / `Latest Date Added` batch-save ordering

## Summary

1. **Unified Subtitle Priority Comparator (`LibraryDatabaseModels`, `LibraryDatabase+FileDetail`)**:
   - Extracted `VideoSubtitles.compareSubtitles(lhsSubtitlePath:lhsFormat:rhsSubtitlePath:rhsFormat:forVideoPath:)` to centralize the standard subtitle ordering rule: exact basename match with the paired video first → format priority (`ass > ssa > srt > vtt`) → subtitle filename natural sort (`localizedStandardCompare`) → full subtitle path fallback (`localizedStandardCompare`).
   - Reused `VideoSubtitles.compareSubtitles` in `VideoSubtitles.init` and `FileDetailVideoInfo.init` so the player subtitle menu and the File Info paired switcher dropdown remain strictly aligned.
2. **Search Default Sort & Character-Count Tie-Breaker Alignment (`SearchDatabase`, `IndexingDatabase`)**:
   - Updated `SearchDatabase.searchFileRanks` and `SearchDatabase.allCuesVisiblePage` (`compareSearchFiles`) to sort matched subtitle files by Level 2 folder title natural sort (`localizedStandardCompare`, tie-breaking by folder path natural sort, matching Library Default Sort) → paired video filename natural sort (`videoName.localizedStandardCompare`, tie-breaking by `videoPath.localizedStandardCompare`) → `VideoSubtitles.compareSubtitles` within the same video.
   - Updated `IndexingDatabase.insertSearchOrderRows` (`SearchOrderFile`) so newly built `subtitle_search_order_rows` also sort files within each folder by `(videoName, videoPath, VideoSubtitles.compareSubtitles)` before cue timestamp ordering (`start_ms ASC, end_ms ASC, id ASC, display_order ASC, event_index ASC, line_id ASC`).
3. **File Level 2 Subfolders, Episode Group Subtitles, and Filter Folder Options (`IndexedContentDatabase`, `CueFacetFilterPanel`)**:
   - Updated `IndexedContentDatabase.subfolders(under:)` to sort Level 2 subfolders by folder title natural sort (`localizedStandardCompare`) with folder path natural sort tie-breaking, while keeping Level 1 root folders in addition order (`added_order ASC`).
   - Updated `IndexedContentDatabase.loadSubtitles` (both root-folder and subfolder queries) to sort each video card's paired subtitles using `VideoSubtitles.compareSubtitles`.
   - Updated `CueFacetFolderOption.listed` in `CueFacetFilterPanel` so zero-count fallback folder options sort by `localizedStandardCompare` on folder title and path instead of lexicographical `<`.
4. **Excerpt `Earliest Date Added` / `Latest Date Added` Batch-Save Symmetry (`ExcerptStore+Execution`)**:
   - Updated `.latestDateAdded` in `ExcerptStore.residentExcerptTableProjection` to tie-break equal `createdAt` timestamps using `lhs.offset > rhs.offset` (the exact reverse of `.earliestDateAdded`'s `lhs.offset < rhs.offset`), ensuring batch-saved cues with identical `created_at` timestamps preserve their pre-save display order in `Earliest Date Added` and strictly reverse in `Latest Date Added`.
5. **Verification**:
   - Added and updated unit tests in `SearchDatabaseTests`, `IndexedContentDatabaseTests`, `SettingsStoreSearchTests`, `ExcerptPresentationTests`, and `FileDetailDatabaseTests`.
