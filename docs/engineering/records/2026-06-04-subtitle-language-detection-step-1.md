# Subtitle Language Detection Step 1

Human requirement:

- `docs/human/requirements/20260604-Feature-Subtitle Language Detection And Search Filter.md`

## Scope

Implemented the first foundation step for subtitle language detection:

- Added the core subtitle language codes used by later indexing and search filtering.
- Added confidence bands and a detection result model that can represent language sets.
- Added a local Apple NaturalLanguage-backed subtitle language recognizer.
- Added focused tests for single-language, mixed-language, Chinese script, low-information, and identifier mapping behavior.

This step does not yet connect language detection to indexing, database persistence, search filtering, or settings UI.

## Verification

- `swift test --filter SubtitleLanguage`
- Result: passed, 5 Swift Testing tests.

## Outcome

The core language model and local NaturalLanguage recognizer are ready for the later indexing and database integration steps.
