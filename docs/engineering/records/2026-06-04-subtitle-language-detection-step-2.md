# Subtitle Language Detection Step 2

Human requirement:

- `docs/human/requirements/20260604-Feature-Subtitle Language Detection And Search Filter.md`

## Scope

Implemented the second foundation step for subtitle language analysis:

- Added an analyzer that applies local language recognition to parsed SRT and ASS cue groups.
- SRT analysis uses all parsed subtitle cue text and applies the resulting language set to each cue group.
- ASS analysis detects only styles actually used by parsed dialogue lines and maps those style language sets back to cue groups.
- Added style-name canonicalization for ASS dialogue styles such as `*Default`.
- Added language segment extraction that splits subtitle line breaks and ignores likely ASS vector drawing residuals.

This step does not yet persist language data in SQLite, filter search results, or add settings UI.

## Verification

- `swift test --filter SubtitleLanguage`
- Result: passed, 10 Swift Testing tests.

## Outcome

The language analyzer can now derive file-level SRT language, used ASS style language, and cue group language sets for later SQLite persistence.
