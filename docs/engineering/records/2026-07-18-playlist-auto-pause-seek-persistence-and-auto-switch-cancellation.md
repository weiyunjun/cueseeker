# Playlist Auto Pause Seek Persistence And Auto Switch Cancellation

## Human-Owned Requirement

- `docs/human/requirements/20260718-Feature-Playlist Auto Pause Seek Persistence And Auto Switch Cancellation.md`

## Implementation

1. Renamed the persisted setting and Play settings label from Auto Stop to Auto
   Pause. Existing `autoStopAfterCueFinishesEnabled` values migrate to
   `autoPauseAfterCueFinishesEnabled`, after the older Only Play migration, so
   upgrades preserve the user's normalized on/off state.

## Verification

- `swift test --package-path apps/macos-native --filter SettingsStorePlaybackTests`:
  passed all seven setting default, normalization, migration, precedence, and
  Gap persistence tests.

## Outcome

- Auto Pause terminology and persisted preference migration completed. Runtime
  seek persistence and Auto Switch lifecycle work remain in progress.
