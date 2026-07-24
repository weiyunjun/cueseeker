# Database Identity, Indexing, And Persistent Data Safety

## Human-Owned Source

- `docs/human/requirements/20260724-Engineering-Database Identity Indexing And Persistent Data Safety.md`

## Scope

Implement permanent resource identity, safe Library index publication, Cue
identity reconciliation, SRT-to-ASS rendering, referenced-Cue Tombstones, and
the Shiori lifecycle UI without using paths or display order as durable
identity.

## Steps

### 1. Schema 35 Foundation

- Added stable binding metadata for Libraries, folders, videos, and subtitles.
- Added Library folder IDs and per-Library index publication tokens.
- Added ASS identity-remainder storage, Cue Tombstones, one-generation change
  notices, and binding-conflict records.
- Removed the destructive Cue foreign-key cascade from Shiori while preserving
  Shiori IDs and tag assignments during migration.
- Updated the product data model and database schema rules.

### 2. Stable File Identity And Path Binding

- Added opaque platform resource identities for Libraries, folders, videos, and
  subtitles, plus complete SHA-256 fingerprints for subtitle copy/delete
  recovery.
- Preserved IDs across same-volume moves and renames while treating a new
  resource at an old path as a new object.
- Added unique-content subtitle rebinding, explicit multi-candidate conflicts,
  and a user-confirmed conflict resolution operation.
- Kept playback history and watch state attached to VideoID when paths move,
  and released the old path before a replacement video can acquire new state.
- Advanced the schema to 36 so generated and user-selected folder covers follow
  FolderID and cannot leak to a replacement folder at the old path.

## Verification

- `swift test --filter DatabaseBootstrapTests`
  - 13 tests passed.
  - Covered fresh schema creation, schema 33 and 34 migration, Shiori/tag
    preservation, and removal of the destructive Cue foreign key.
- `swift test --filter IndexingDatabaseTests`
  - 16 tests passed.
  - Covered Library/folder/media moves, path replacement, unique and ambiguous
    subtitle copies, user-confirmed rebinding, playback history isolation, and
    folder-cover isolation.
- `swift test --filter LibraryDatabaseTests`
  - 18 tests passed.
- `swift test --filter SubtitleIndexerTests`
  - 16 tests passed.

## Result

- Implementation is in progress.
