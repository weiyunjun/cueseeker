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
3. Pending: remove Speaker product UI, playback, settings, and import tooling.
4. Pending: migrate the database once to remove Speaker and AI cache storage,
   then remove the remaining Core APIs and tests.

## Verification

- `swift test --package-path apps/macos-native --filter ApplicationPersistence`
  passed with 2 tests, including obsolete defaults and credential-deletion
  coverage.
- `swift build --package-path apps/macos-native` passed.
- Pending final full test suite and schema migration verification.

## Outcome

Implementation is in progress. Step 1 removes the AI Chunking application
layer while retaining its database table only until the combined migration.
