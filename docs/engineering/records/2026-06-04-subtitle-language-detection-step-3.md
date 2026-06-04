# Subtitle Language Detection Step 3

Human requirement:

- `docs/human/requirements/20260604-Feature-Subtitle Language Detection And Search Filter.md`

## Scope

Implemented SQLite persistence support for subtitle language detection:

- Bumped the subtitle database schema to version 17.
- Added language manifest storage for algorithm-version checks.
- Added file/style-level language detection storage with final language codes and diagnostic distributions.
- Added cue group language set storage for later search filtering.
- Added database query APIs for stored detections, cue group languages, and current language manifest checks.
- Extended subtitle replacement APIs to optionally persist a `SubtitleLanguageAnalysis` in the same transaction as cue groups.
- Added cleanup for language tables when a subtitle path is replaced or removed.

This step does not yet run language analysis during indexing, filter search SQL by language, or expose settings UI.

## Verification

- `swift test --filter Language` passed 17 Swift Testing tests.
- `swift test --filter SubtitleDatabase` passed 70 Swift Testing tests.

## Outcome

Database persistence is ready for the next integration step: running subtitle
language analysis during indexing and using cue-group languages for search
filtering.
