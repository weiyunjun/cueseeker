# ASS System Font Alias Step 3

Requirement: `docs/human/requirements/20260603-Bug-ASS System Font Alias Name Table.md`

## Scope

- Added an ASS font intent extractor for style `Fontname` fields and inline `\fn` override tags.
- Added index-time storage for ASS requested font names, source location, occurrence count, and first occurrence order.
- Added a per-subtitle ASS font reference manifest keyed by the extractor algorithm version.
- Bumped the database schema version to 16 for the new derived index tables.
- Updated `SubtitleIndexer` so unchanged ASS files are skipped only after the current font reference manifest exists.

## Verification

- `swift test --package-path apps/macos-native --filter 'ASSFont|assFont|indexesASSFont|storesAndLoadsASSFontReferences|extractsASSReferenced'`
- `swift test --package-path apps/macos-native`

Both commands passed. The full suite reported 177 passing tests.

## Result

The third implementation step matched expectations: ASS index now records the subtitle file's requested fonts as diagnostic intent data without resolving aliases or making final libass fallback decisions at index time.
