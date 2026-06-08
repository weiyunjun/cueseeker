# Test Search 2 Language Tags Phase 2

Human requirement:

- `docs/human/requirements/20260608-Feature-Test Search 2 Schema UI Shell.md`

## Scope

This record covers Phase 2 of the second Test Search 2 table UI stage:
adding a Language column to the Test Search 2 virtual table and rendering
subtitle languages as generic tags.

This phase intentionally does not implement filter semantics, speaker tags,
custom tag color persistence, or a non-virtualized table replacement.

## Changes

- Added language metadata to `SubtitleSearchResult`.
- Loaded cue group languages for the current result ID window and the current
  search candidate batch so language tags follow the same paged search path as
  visible rows.
- Added a generic `WorkbenchTag` model and `WorkbenchTagColorID` style key.
- Added a separate subtitle-language-to-tag mapper so tag identity, display
  label, and color remain decoupled from the language model.
- Mapped current English tag labels to their keys:
  `zh-hans`, `zh-hant`, `zh`, `en`, `jp`, and `unknown`.
- Kept all language tags on the default blue tag style for now.
- Added `tags` to `SubtitleTableRow` and mapped search result languages to
  tags in `TableSandboxRowModelStore`.
- Added an optional Language column to `SubtitleTableView`; `Test Search 2`
  enables it, while the existing Test Search and Shiori table routes keep the
  default three-column presentation.
- Drew tag pills directly in the AppKit virtual table without changing row
  count, row provider, row height, visible-row range mapping, hydration, or
  playback actions.

## Verification

- `swift build --target CueSeekerApp` initially exited without a concrete
  diagnostic, then succeeded on rerun.
- `swift test --filter searchResultsExposeCueGroupLanguages` succeeded.
- `swift test --filter tableSandboxRowModelStoreMapsSearchLanguagesToDefaultBlueTags` succeeded.
- `swift test --filter subtitleTableViewUsesVirtualRowCountWithoutMaterializingModels` succeeded.
- `swift test --filter CueSeekerAppTests` succeeded with 94 tests passing.
- `swift test --filter CueSeekerCoreTests` succeeded with 121 tests passing.
- `swift build --product CueSeeker` succeeded.

## Outcome

Phase 2 is complete. Test Search 2 now shows a Language column backed by paged
search result language metadata and generic blue tag rendering while preserving
the existing virtualized loading path.
