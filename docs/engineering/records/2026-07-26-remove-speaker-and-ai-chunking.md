# Remove Speaker and AI Chunking

## Requirement

- `docs/human/requirements/20260726-Feature-Remove Speaker And AI Chunking.md`

## Scope

Remove the retired Speaker and AI Chunking product paths and their persisted
state without changing Cue, Language, Shiori Tag, subtitle playback, or other
search-filter behavior.

## Steps

1. Removed the AI Chunking app client, prompt configuration, settings state,
   and app-level cache compatibility hook.
2. Added startup cleanup for the five obsolete AI Chunking UserDefaults keys
   and the `CueSeekerAI/deepseek` Keychain item. The cleanup is idempotent and
   does not create another migration marker.
3. Removed the Speaker playback setting and prefix-rendering path for SRT, ASS,
   and subtitle screenshots; removed the Speaker-specific UI tokens and the
   `SpeakerImport` executable. Obsolete saved Speaker filter rules are removed
   without discarding other rules in the same Filter Set.
4. Added schema 39, which drops `subtitle_cue_line_speakers` and
   `ai_chunk_cache_entries` in place. Removed the remaining Speaker and AI
   cache models, database APIs, search/filter projection, table presentation,
   and feature-specific tests.
5. Updated the schema 36 migration fixture to include its required
   `shiori_lists` table so the complete 36-to-39 migration chain remains
   covered.

## Verification

- `swift test --package-path apps/macos-native --filter ApplicationPersistence`
  passed with 2 tests, including obsolete defaults and credential-deletion
  coverage.
- `swift build --package-path apps/macos-native` passed.
- The Step 2 targeted run passed 4 tests covering obsolete preference cleanup,
  saved Speaker-rule removal, and ASS playback source construction.
- The post-Step 2 `swift build --package-path apps/macos-native` passed.
- `swift test --package-path apps/macos-native --filter
  migratesSchema38ByDroppingOnlySpeakerAndAICacheStorage` passed and verified
  that schema 39 removes only the obsolete tables while retaining Cue,
  Language, Shiori, and FTS rows.
- The focused database, search/filter, table, and persistence suite passed all
  213 tests.
- The first full-suite run compiled and executed 872 tests; 16 existing
  timing/resource-contention checks failed. Every failed test passed when
  rerun in its focused group, including Library removal, native playback,
  Subtitle Focus Shiori, and mounted Search refresh checks.
- `swift build --package-path apps/macos-native` and `git diff --check` passed.

## Outcome

Speaker and AI Chunking are removed from active product, application, Core,
database, and test paths. Existing databases upgrade directly to schema 39;
the migration preserves Cue, Language, Shiori Tag, subtitle playback, and
search data, so reindexing is neither required nor expected.
