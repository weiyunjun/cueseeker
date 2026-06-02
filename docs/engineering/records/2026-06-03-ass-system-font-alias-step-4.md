# ASS System Font Alias Step 4

Requirement: `docs/human/requirements/20260603-Bug-ASS System Font Alias Name Table.md`

## Scope

- Added a playback-side provider that loads indexed ASS requested font names from the render cache database.
- Passed indexed requested font names into the source-faithful ASS renderer worker before creating libass sessions.
- Updated the alias resolver so indexed font intent can skip render-script rewriting when none of the requested fonts has an alias replacement.
- Kept the existing full script scan fallback when indexed font intent is unavailable.
- Kept final font selection and glyph fallback in libass at render time.

## Verification

- `swift test --package-path apps/macos-native --filter 'assFont|ASSFont|assPlaybackFontIntent'`
- `swift test --package-path apps/macos-native`

Both commands passed. The full suite reported 179 passing tests.

## Result

The fourth implementation step matched expectations: playback now uses index-time ASS font intent to guide alias rewriting before libass session creation, while preserving runtime libass font selection semantics.
