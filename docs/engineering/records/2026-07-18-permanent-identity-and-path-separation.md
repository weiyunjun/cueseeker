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
3. Pending: switch video, subtitle, and playback state persistence to IDs.
4. Pending: switch normal Shiori persistence and lookup to CueID.
5. Pending: remove remaining path-identity reads and run regression coverage.

## Verification

- Step 1: `swift test --filter permanentIdentitySchemaIncludesLibraryRelativePathsAndIDReferences`
  passed 1 test.
- Step 1: `swift test --filter migration` passed 11 migration tests.
- Step 2: `swift test --filter indexedMediaStoresLibraryIDAndRelativePaths`
  passed 1 test.
- Step 2: `swift test --filter SubtitleIndexer` passed 16 tests.

## Outcome

- Schema migration and media-relative path persistence completed; runtime
  state cutover remains in progress.
