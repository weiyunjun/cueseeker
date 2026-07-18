# URL Scheme Cue Deep Links And Overlay Search Implementation

## Requirement

- `docs/human/requirements/20260718-Feature-URL Scheme Cue Deep Links And Overlay Search.md`

## Status

In progress.

## Scope

- Route URL Scheme Search to direct playback, Playback Overlay Search, or
  Workbench Search according to the accepted requirement.
- Split Playlist Cue-boundary playback from automatic Playlist navigation.
- Add CueID direct playback as a one-item Playlist with Search Return Context.
- Add plain Markdown Cue-link copy on `X` in supported Overlay modules.
- Verify the packaged application through macOS Launch Services before owner
  acceptance.

## Implementation Steps

1. Synchronized the engineering, product, and testing contracts with the
   human-owned requirement.
2. Split the former coupled Playlist toggle into persisted `Only Play Cues in
   Playlist` and `Auto Switch to Next Cues in Playlist` preferences. The
   playback coordinator now applies the first only to native Cue-end stopping
   and the second only to Gap-delayed Playlist navigation. When Only Play is
   off and Auto Switch is on, playback-time boundary tracking starts the Gap
   without pausing the current video. Added legacy preference migration and
   four-combination coverage: completed.
3. Routed URL Scheme Search through the shared non-debounced Search pipeline
   without closing active Playback. Active Playback now opens or reuses its
   Overlay Session on Search, including empty direct-play results; inactive
   Playback routes to Workbench Search. Existing Overlay Sessions can accept an
   external module presentation request while still opening: completed.
4. Added strict positive-`Int64` CueID parsing, cancellable indexed Cue lookup,
   direct playback, and an explicit one-item `.cue` Playlist source. Cue
   playback has no adjacent item, remains one item when operated from Overlay
   Playlist, ignores unavailable CueIDs without replacing the current
   presentation, and fixes Playback Return Context to Workbench Search:
   completed.
5. Markdown Cue-link copy: pending.
6. Full regression, packaging, and Launch Services verification: pending.

## Verification

- `git diff --check`: passed for the technical-contract change set.
- Confirmed the updated URL, playback, functional, and testing documents cite
  the committed human-owned requirement without modifying `docs/human/`.
- Playlist settings/playback focused test selection: 10 tests passed, including
  defaults, persistence, legacy migration, Gap bounds, all four independent
  toggle combinations, Cue-end pause, continuous playback through the Gap, and
  continuous-from-start override behavior.
- `swift test --package-path apps/macos-native`: application and test targets
  built successfully and all tests related to this step passed. Repeated full
  runs each encountered one unrelated isolation/timeout failure
  (`playbackRecentPointerDispatcherUsesSharedWorkbenchItem`,
  `sharedPersistenceMigrationCopiesLegacyValuesWithoutOverwritingSharedValues`,
  or `playbackPlaylistCopyAndShioriTargetTheSettledPrimaryCue`); every reported
  failure passed immediately when rerun in isolation.
- URL Scheme and Overlay-routing focused test selection: 14 tests passed,
  covering Workbench versus new/reused Overlay Search, active Playback
  preservation, empty-result routing with and without Playback, non-debounced
  state synchronization, command cancellation, direct first-result playback,
  parser validation, and covered-Workbench invalidation behavior.
- Cue URL Scheme and Playlist focused test selection: 15 tests passed, covering
  valid and invalid CueID parsing, indexed Cue hydration with active video
  matching, one-item Playlist identity and Overlay availability, unavailable
  Cue behavior, command supersession, adjacent-navigation suppression, and
  Search Return Context on Playback close.

## Outcome

Pending implementation and verification.
