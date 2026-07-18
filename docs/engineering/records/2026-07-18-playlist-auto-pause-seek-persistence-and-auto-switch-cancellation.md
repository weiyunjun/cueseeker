# Playlist Auto Pause Seek Persistence And Auto Switch Cancellation

## Human-Owned Requirement

- `docs/human/requirements/20260718-Feature-Playlist Auto Pause Seek Persistence And Auto Switch Cancellation.md`

## Implementation

1. Renamed the persisted setting and Play settings label from Auto Stop to Auto
   Pause. Existing `autoStopAfterCueFinishesEnabled` values migrate to
   `autoPauseAfterCueFinishesEnabled`, after the older Only Play migration, so
   upgrades preserve the user's normalized on/off state.
2. Added an immutable effective-settings snapshot for each initialized Playlist
   Item. Auto Pause, Auto Switch, and Gap now stay fixed for that Item while
   settings edits persist immediately for the next initialized Item. Live
   settings changes no longer cancel or mutate the current Auto Switch task.
3. Kept the current Item's Auto Pause boundary installed across user seeks.
   Seeking to or beyond the boundary does not trigger it; seeking back before
   it rearms natural-playback completion. Resuming after an automatic pause
   passes the already-consumed boundary without immediately pausing again.
   Paused seeks use the same native boundary while still presenting the sought
   frame before remaining paused.

## Verification

- `swift test --package-path apps/macos-native --filter SettingsStorePlaybackTests`:
  passed all seven setting default, normalization, migration, precedence, and
  Gap persistence tests.
- `swift test --package-path apps/macos-native --filter PlaybackSegmentCompletionTests`:
  passed all 17 segment-completion tests, including the current Item retaining
  its Auto Pause, Auto Switch, and Gap snapshot while the next initialized Item
  receives the newly persisted values.
- `swift test --package-path apps/macos-native --filter PlaybackSegmentCompletionTests`:
  passed all 18 tests after adding the before/at-or-beyond boundary rearming
  state regression.
- `swift test --package-path apps/macos-native --filter playbackPlayerKeepsAutoPauseBoundaryAcrossUserSeeks`:
  passed with generated real media. Seeking beyond the active boundary emitted
  no event, and a paused seek back before it emitted a second event only after
  playback resumed and naturally reached the boundary.

## Outcome

- Auto Pause terminology and persisted preference migration completed. Runtime
  seek persistence and Auto Switch lifecycle work remain in progress.
