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
   media paths, and the missing ID references. Added migration backfills where
   the existing database already has an unambiguous relationship.
2. Added library-root ownership and normalized relative-path persistence for
   indexed subtitle and video files. Existing media rows are backfilled when
   their library root is registered, and cue rows now directly record their
   SubtitleID.
3. Switched Library snapshot rows, playback history, watch state, and search
   watch-state joins to VideoID/SubtitleID. Reindexing now preserves the
   existing SubtitleID while rebuilding its derived cue data.
4. Switched normal Shiori persistence and cue presentation lookup to CueID.
   Incoming CueIDs are verified against the selected subtitle before the
   foreign key is stored. Legacy and unindexed Shiori snapshots retain their
   existing compatibility lookup, and tag assignments continue to reference
   ShioriID.
5. Pending: remove remaining path-identity reads and run regression coverage.

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

## Outcome

- Schema migration, media-relative paths, Library state ID cutover, and Shiori
  CueID cutover completed; final path-identity cleanup remains in progress.
