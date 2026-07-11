# Show Cue Group Setting

## Requirement

- `docs/human/requirements/20260710-Feature-Cue-Centric Search Shiori Context Playback And Export.md`
- `docs/human/design/UI.md`

## Scope

Add the persisted Search setting that controls whether Search, Shiori, and
Context table presentations show the complete Cue Group. This step covers only
the setting model and Settings UI. Table presentation, row geometry, Cue
interaction, and query behavior are outside this step.

## Implementation

- Added a `showCueGroup` Boolean setting backed by `UserDefaults`.
- Registered `false` as the default and loaded an existing persisted value at
  `SettingsStore` initialization.
- Added the native macOS `Show Cue Group` switch immediately below Search Scope.
- Kept the setting presentation-only by leaving it out of
  `AppCoordinator.setupSettingsObservers()`; changing it does not request a
  Search reload.

## Verification

- Focused Settings tests cover the default Off state, persistence writes, and
  loading a stored On value.
- `swift test --filter SettingsStoreSearchTests` passed all 3 selected tests.
- `swift test --filter SettingsStore` passed all 6 selected SettingsStore
  tests, including the existing playback-setting coverage.
- `git diff --check` passed.
