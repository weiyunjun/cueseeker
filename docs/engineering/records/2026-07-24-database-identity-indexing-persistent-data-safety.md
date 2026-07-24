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

### 3. Atomic Library Index Publication

- Separated filesystem scanning, subtitle reading, parsing, render preparation,
  and language analysis from database publication.
- Published all changed, unchanged, and stale-file decisions for one Library in
  one immediate transaction, rebuilding derived Search data only after the
  complete batch succeeds.
- Added monotonically increasing per-Library publication tokens so a stale scan
  cannot overwrite a newer result.
- Made unreadable roots, incomplete enumeration, unreadable files, malformed
  SRT blocks, and malformed ASS Dialogue records cancel publication while the
  previous successful Index remains active.

### 4. Cue Identity Reconciliation

- Added format-aware Cue reconciliation that locks exact matches before
  considering local edits and never uses Event Index or Display Order.
- Enforced ASS Style as a hard identity boundary and allowed inheritance only
  for an unambiguous single-part change among timestamp, cleaned text, and the
  canonical remaining Dialogue fields.
- Added canonical ASS remainder persistence for Layer, Name, margins, Effect,
  and any other non-time/non-text/non-Style Event fields.
- Kept unique SRT one-to-one edits on the original CueID while assigning new
  CueIDs to ambiguous same-time multi-edit results.
- Preserved CueID, Shiori relations, tags, and speaker assignments across
  accepted edits and file moves; added one-successful-index text-change
  notices.
- Advanced the Cue indexing algorithm version to 4 so existing subtitle files
  are reconciled through the new rules.

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
  - 22 tests passed.
  - Covered whole-Library rollback after an injected mid-publication failure,
    malformed-subtitle rollback, stale-token rejection, unchanged-file
    handling, stable ASS identities after adding another Style, ambiguous SRT
    replacements, one-index change notices, and successful SRT/ASS publication.
- `swift test --filter SubtitleFileScannerTests`
  - 2 tests passed.
  - Covered recursive supported-file discovery and rejection of an invalid
    Library root.
- `swift test --filter SRTParserTests`
  - 4 tests passed.
- `swift test --filter ASSParserTests`
  - 7 tests passed.
- `swift test --filter CueIdentityReconcilerTests`
  - 4 tests passed.
  - Covered Event Index/Display Order exclusion, ASS Style and single-part
    boundaries, exact-first SRT matching, and ambiguous SRT replacement.
- `swift test --filter ShioriDatabaseTests`
  - 13 tests passed.
  - Covered CueID, Shiori ID, tag, and metadata preservation after an accepted
    content edit.

## Result

- Implementation is in progress.
