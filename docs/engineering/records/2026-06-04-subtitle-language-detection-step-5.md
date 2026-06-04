# Subtitle Language Detection Step 5

Human requirement:

- `docs/human/requirements/20260604-Feature-Subtitle Language Detection And Search Filter.md`

## Scope

Added cue-group-level subtitle language filtering to the core search layer:

- Added `SubtitleSearchLanguageFilter` for `all`, Japanese, English, Chinese,
  Simplified Chinese, and Traditional Chinese search scopes.
- Added an optional `languageFilter` argument to search page, visible page,
  direct search, and search navigation APIs.
- Applies non-`all` filters at the FTS candidate SQL stage using
  `subtitle_cue_group_languages`.
- Non-`all` filters match cue groups containing the selected language or
  `unknown`.
- Chinese filter matches either Simplified Chinese or Traditional Chinese.
- Cue groups without stored language rows are treated as `unknown` for legacy
  index compatibility.
- Added language filter to search result cache keys so different language
  filters cannot reuse stale pages.

This step does not yet expose the Search setting in the UI.

## Verification

- `swift test --filter searchLanguage` passed 2 Swift Testing tests.
- `swift test --filter SubtitleDatabase` passed 72 Swift Testing tests.
- `swift test` passed 197 Swift Testing tests and 7 XCTest tests.

## Outcome

Core search can now return language-filtered result pages at cue group
granularity, ready for the settings UI to pass the selected primary search
language.
