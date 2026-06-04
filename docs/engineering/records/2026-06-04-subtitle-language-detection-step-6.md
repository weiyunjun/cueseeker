# Subtitle Language Detection Step 6

Human requirement:

- `docs/human/requirements/20260604-Feature-Subtitle Language Detection And Search Filter.md`

## Scope

Exposed the primary search language setting and wired it into App-layer search
flows:

- Added `PrimarySearchLanguage` as the App-layer setting model for `All`,
  Japanese, English, Chinese, Simplified Chinese, and Traditional Chinese.
- Persisted the setting in `SettingsStore`, defaulting to `All`.
- Added a `Search` subsection under Settings > Appearance with the current
  Search icon and a `Primary Search Language` picker.
- Passed the selected language filter to visible search pages, exact search
  completion, search navigation snapshots, per-file group expansion loads, and
  playback history search restoration.
- Refreshed the current search when the setting changes.
- Added stale-result guards so background search, count, navigation, and group
  load tasks cannot overwrite the UI after the language setting changes.

## Verification

- `swift test --filter settingsStorePersistsPrimarySearchLanguage` passed 1
  Swift Testing test.
- `swift test` passed 198 Swift Testing tests and 7 XCTest tests.

## Outcome

The selected primary search language now affects user-facing search result
groups at cue-group granularity through the existing core language filter, while
`All` remains the default behavior.
