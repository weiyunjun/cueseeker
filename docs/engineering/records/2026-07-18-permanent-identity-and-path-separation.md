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
2. Pending: switch media path persistence and resolution.
3. Pending: switch video, subtitle, and playback state persistence to IDs.
4. Pending: switch normal Shiori persistence and lookup to CueID.
5. Pending: remove remaining path-identity reads and run regression coverage.

## Verification

- Step 1: `swift test --filter permanentIdentitySchemaIncludesLibraryRelativePathsAndIDReferences`
  passed 1 test.
- Step 1: `swift test --filter migration` passed 11 migration tests.

## Outcome

- Schema migration completed; runtime cutover remains in progress.
