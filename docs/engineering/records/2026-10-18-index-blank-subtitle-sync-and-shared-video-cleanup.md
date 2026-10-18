# Implementation Record: Index Blank Subtitle Sync And Shared Video Cleanup

- **Requirement**: `docs/human/requirements/20261018-Bug-Index Blank Subtitle Sync And Shared Video Cleanup.md`
- **Date**: 2026-10-18

## Summary of Changes

1. **Blank and Zero-Cue Subtitle Handling (`SubtitleTextDecoder`, `SubtitleIndexer`)**:
   - Updated `SubtitleTextDecoder.validated` (`apps/macos-native/Sources/CueSeekerCore/SubtitleTextDecoder.swift`) so blank subtitle text (empty or whitespace-only after stripping BOM) decodes cleanly as empty text instead of throwing `SubtitleTextDecodingError.invalidStructure`, while still rejecting non-empty text lacking valid `.srt`/`.ass` structure.
   - Updated `SubtitleIndexer.index` (`apps/macos-native/Sources/CueSeekerCore/SubtitleIndexer.swift`) to skip any subtitle file whose parsed `cueGroups` is empty (`guard !cueGroups.isEmpty else { continue }`) without recording a file failure or keeping its path in `keptSubtitlePaths`. Brand-new blank/zero-cue subtitles do not enter the database, and previously indexed subtitles that are cleared or left with zero valid cues are automatically removed during index publication.
   - Updated `SubtitleIndexer.isSubtitleContentUnchanged` to verify `database.firstCueGroupID(forSubtitleFile:) != nil` so any zero-cue subtitle row remaining from an older database is re-evaluated and cleaned up.

2. **Safe Shared Video Cleanup for Multi-Subtitle Episodes (`IndexingDatabase`)**:
   - Updated `IndexingDatabase.removeIndexedDataInCurrentTransaction` and `IndexingDatabase.removeMatchedVideos` (`apps/macos-native/Sources/CueSeekerCore/IndexingDatabase.swift`) to check `hasActiveSubtitleMatch(videoFileID:)` after removing stale subtitle files or matches, deleting a `video_files` record (and its playback history, watch state, and presentation rows) only when no remaining active subtitle matches that video.
   - Updated `IndexingDatabase.deleteSubtitleFile` to clear `video_files.default_subtitle_file_id` if the deleted subtitle was previously set as the video's default subtitle.

3. **Empty-Text SRT Cue Block Compatibility (`SRTParser`)**:
   - Updated `SRTParser.isStructurallyValid` and `SRTParser.splitBlocks` (`apps/macos-native/Sources/CueSeekerCore/SRTParser.swift`) so an `.srt` cue block with a valid timestamp header (`start --> end`) and empty text below it is treated as structurally valid and skipped during cue extraction (matching `.ass` behavior), whether or not a blank line separates it from the next cue block.

## Verification

- Automated unit & integration tests (`swift test --package-path apps/macos-native`):
  - `SRTParserTests`: `indexingSkipsEmptyTextSRTBlocksAndKeepsRemainingValidBlocks`, `indexingSkipsOneReversedTimeRangeAndKeepsValidBlocks`
  - `SubtitleTextDecoderTests`: `decodesEmptyOrByteOrderMarkOnlySubtitlesWithoutStructureError`, `rejectsDecodedTextWithoutSubtitleStructure`
  - `SubtitleIndexerTests`: `reindexingClearedSRTOrHeaderOnlyASSRemovesSubtitleWithoutFailure`, `clearingOneSubtitleOfMultiSubtitleEpisodePreservesSharedVideoAndWatchState`, `malformedSubtitleKeepsItsLastIndexWhileOtherFilesPublish`, `reversedSRTBlockIsSkippedWhileValidBlocksPublish`
  - Outcome matched all requirement expectations.
