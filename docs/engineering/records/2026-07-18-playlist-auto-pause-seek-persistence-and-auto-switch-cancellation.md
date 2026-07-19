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
4. Bound each pending Auto Switch task to a cancellation generation, the
   current Playlist position, the current Item settings snapshot, and the
   latest valid Auto Pause state. Seek, manual transport, Overlay entry, source
   replacement, or Item initialization invalidates the task; unrelated display
   controls and live settings edits do not.
5. Captured the Playlist position with each Item initialization. Old boundary
   callbacks are rejected after the position changes, and the new Item receives
   a fresh runtime state and the latest persisted settings. Closing Playback or
   replacing Playlist playback clears the old boundary, snapshot, position, and
   pending switch task.
6. Removed the Overlay-only continuous-play bypass from Current, Playlist,
   Search, and Shiori Enter actions. Every successful Enter selection now
   initializes a new logical Item and settings snapshot. Current initializes its
   replacement boundary before seeking; the other modules use their normal
   Search or Shiori Item-opening paths.
7. Moved the effective Auto Pause timestamp to `max(Cue Start, Cue End - 1ms)`
   for the native boundary, completion validation, and subtitle presentation.
   Subtitle hold no longer depends on the previously selected Search result or
   Shiori record, so Current can pause on its exact Cue even when that Cue differs
   from the original Playlist primary Cue.
8. Made Current-Cue playback submit its replacement Auto Pause boundary with the
   same-media seek. This prevents a native boundary left by the previous logical
   Item from pausing the newly selected Cue at the old timestamp.

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
- `swift test --package-path apps/macos-native --filter PlaybackSegmentCompletionTests`:
  passed all 19 tests after adding seek and Overlay cancellation coverage while
  preserving the current Item's Auto Pause boundary and settings snapshot.
- `swift test --package-path apps/macos-native --filter PlaybackSegmentCompletionTests`:
  passed all 21 tests after adding same-video next-index reinitialization, stale
  position rejection, and Playback-close cleanup coverage.
- `swift test --package-path apps/macos-native`: all feature-related tests
  passed. The concurrent 777-test run exposed two unrelated timing flakes in
  native delayed-video presentation and Recent pointer dispatch; both passed
  immediately when rerun alone.
- `swift test --package-path apps/macos-native --no-parallel`: all playback and
  feature tests passed. One unrelated shared-UserDefaults isolation test saw a
  value left by the broader process; its isolated rerun passed.
- `swift test --package-path apps/macos-native --filter PlaybackSubtitleFocusKeyboardActionTests`:
  passed all 15 Overlay keyboard-action tests, including retention of the new
  Current Item snapshot and boundary after Enter destroys the Overlay session.
- `swift test --package-path apps/macos-native --filter PlaybackSegmentCompletionTests`:
  passed all 21 tests after removing the continuous-play bypass and moving the
  effective boundary to Cue End minus one millisecond. The adjacent-Cue
  regression confirms the current Cue remains visible even when the selected
  Search result represents a different Cue.
- `swift test --package-path apps/macos-native --filter PlaybackShioriOverlayTests`:
  passed all six Shiori Overlay tests after removing the legacy continuous-play
  dispatch flag.
- `swift test --package-path apps/macos-native --filter playbackPlayerKeepsAutoPauseBoundaryAcrossUserSeeks`:
  passed with generated real media. A same-media seek replaced a stale 1000ms
  boundary with a 1500ms boundary and emitted only the replacement timestamp;
  seek persistence and rearming also remained valid.
- `swift test --package-path apps/macos-native --filter URLSchemeCuePlaybackTests`:
  passed all three CueID routing and cancellation tests.
- `swift test --package-path apps/macos-native --filter URLSchemeSearchRoutingTests`:
  passed all seven URL Scheme Search and direct-play routing tests.
- `swift test --package-path apps/macos-native --filter SettingsStorePlaybackTests`:
  passed all seven settings state, migration, and Gap persistence tests.
- `swift test --package-path apps/macos-native --no-parallel`: 776 of 777 tests
  passed. The unrelated shared-persistence isolation test observed an existing
  shared `workbenchPanelMode` value; its immediate isolated rerun passed.
- `scripts/package_macos_app.sh --output /private/tmp/CueSeeker-Auto-Pause-E2E.app`:
  passed the release build, recursive signing, dependency, self-contained
  ARM64, and bundle verification checks. The bundle is 36 MB; its CueSeeker
  executable SHA-256 is
  `fa9e5bb3708b26197690b5baed9843c568807c10c90ab1646dc59b9e28ba2fe0`.
- `scripts/package_macos_app.sh --output /Applications/CueSeeker.app`: passed
  the replacement Release build, recursive ad-hoc signing, dependency,
  self-contained ARM64, and bundle verification checks. The installed bundle is
  36 MB; its CueSeeker executable SHA-256 is
  `49f7a7f3a4abc5a5362e6d1c209e94a9ec0368d648f62192ada532beeed40f95`.
- LaunchServices registration verification: the installed bundle is active at
  `/Applications/CueSeeker.app`, claims `cueseeker:`, and is the resolved
  application for `cueseeker://cue?id=8869902`. No URL was opened during this
  check, leaving application-level behavior for owner end-to-end validation.

## Outcome

- Implementation, automated verification, installation, and URL handler
  registration completed. Owner end-to-end validation of the installed build
  remains required for final product acceptance.
