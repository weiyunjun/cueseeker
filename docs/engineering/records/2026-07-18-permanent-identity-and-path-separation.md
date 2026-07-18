# Permanent Identity And Path Separation Implementation

## Requirement

- `docs/human/requirements/20260718-Feature-Permanent Identity And Path Separation.md`
- `docs/human/design/Data.md`

## Scope

- Reuse the existing database primary keys as LibraryID, VideoID, SubtitleID,
  CueID, and ShioriID.
- Store library ownership and media-relative paths separately from resolved
  absolute paths.
- Move playback state, subtitle-video relationships, and Shiori relationships
  toward ID-based references.
- Keep Shiori tags assigned through ShioriID.
- Do not add missing-file behavior, file-move detection, cue remapping after
  subtitle edits, or Shiori error presentation.

## Implementation Steps

1. Added schema version 29 columns and indexes for library ownership, relative
   media paths, and the missing ID references. Added migration backfills for
   the existing media and Library-state relationships.
2. Added library-root ownership and normalized relative-path persistence for
   indexed subtitle and video files. Existing media rows are backfilled when
   their library root is registered, and cue rows now directly record their
   SubtitleID.
3. Switched Library snapshot rows, playback history, watch state, and search
   watch-state joins to VideoID/SubtitleID. Reindexing now preserves the
   existing SubtitleID while rebuilding its derived cue data.
4. Switched Shiori persistence, deduplication, and cue presentation lookup to
   CueID. Schema version 30 makes the Shiori-to-Cue relationship unique. New
   Shioris require a native CueID; no path, timestamp, EventIndex, or content
   fallback participates in identity resolution. Tag assignments continue to
   reference ShioriID.
5. Switched Search ordering, Shiori metadata, and derived-index joins from
   duplicated paths to SubtitleID/CueID. Folder removal and reconciliation now
   delete dependent rows by SubtitleID before deleting media identities, and
   detach retained playback-history VideoIDs before deleting their LibraryID.

## Verification

- Step 1: `swift test --filter permanentIdentitySchemaIncludesLibraryRelativePathsAndIDReferences`
  passed 1 test.
- Step 1: `swift test --filter migration` passed 11 migration tests.
- Step 2: `swift test --filter indexedMediaStoresLibraryIDAndRelativePaths`
  passed 1 test.
- Step 2: `swift test --filter SubtitleIndexer` passed 16 tests.
- Step 3: `swift test --filter reindexPreservesSubtitleIDAndLibraryStateReferencesVideoID`
  passed 1 test.
- Step 3: `swift test --filter libraryPlaybackHistory` passed 4 tests.
- Step 3: `swift test --filter Library` passed 48 tests after two legacy
  compatibility failures were corrected and rerun.
- Step 4:
  `swift test --filter shioriPersistsAndResolvesCueIDWhileTagsReferenceShioriID`
  passed 1 test.
- Step 4: `swift test --filter PlaybackSubtitleFocusKeyboardActionTests`
  passed 13 tests.
- Step 4: `swift test --filter Shiori` passed 33 tests.
- Step 5: `swift test --filter removingIndexedFolder` passed 3 tests.
- Step 5: `swift test --filter reconcileIndexedContent` passed 2 tests.
- Step 5: `swift test --filter Search` passed 82 tests.
- Step 5: `swift test --filter Library` passed 48 tests.
- Step 5: full `swift test` runs exercised 750 Swift Testing tests plus 7
  CASS rendering tests. The database-related foreign-key failure found by the
  first run was fixed. Subsequent full runs only reported intermittent,
  unrelated shared-state, timeout, or native-frame failures; the named
  failures passed when rerun in isolation.
- Cleanup: `swift test --filter shiori` passed 18 tests and
  `swift test --filter Shiori` passed 33 tests after removing the Shiori
  compatibility paths and updating fixtures to create indexed CueIDs.
- Cleanup: full `swift test` passed all 7 CASS tests and ran 750 Swift Testing
  tests. Its only failure was the unrelated native-frame timing test
  `nativePlaybackUsesCommonTimelineWhenVideoTrackStartsAfterAudio`, which
  passed immediately when rerun in isolation.

## Outcome

- Schema migration, media-relative paths, Library state ID cutover, Shiori
  CueID cutover, and ID-based derived-table joins completed. Shiori runtime
  identity is now CueID-only.
