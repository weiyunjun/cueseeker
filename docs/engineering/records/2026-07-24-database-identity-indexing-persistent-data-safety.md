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

## Verification

- `swift test --filter DatabaseBootstrapTests`
  - 13 tests passed.
  - Covered fresh schema creation, schema 33 and 34 migration, Shiori/tag
    preservation, and removal of the destructive Cue foreign key.

## Result

- Implementation is in progress.
