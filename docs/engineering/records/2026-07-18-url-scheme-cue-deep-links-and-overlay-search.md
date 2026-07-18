# URL Scheme Cue Deep Links And Overlay Search Implementation

## Requirement

- `docs/human/requirements/20260718-Feature-URL Scheme Cue Deep Links And Overlay Search.md`

## Status

In progress after owner requirement correction.

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
   Playlist` and `Auto Switch to Next Cues in Playlist` preferences. The first
   controls native Cue-end stopping and the second controls Gap-delayed
   Playlist navigation while the first is on. The initially implemented
   four-state interpretation was superseded by the owner's correction:
   on/on, on/off, and off/off are the only valid states.
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
5. Added the Overlay-only `X` action for Current, Playlist, and Shiori settled
   Primary Cues. It writes only the exact plain Markdown string with the CueID,
   leaves Overlay Search unchanged, and reports
   `Subtitle(markdown format) Copied`: completed.
6. Ran full regression and isolated reruns, built and verified the self-contained
   ARM64 application, archived the previous installed bundle, installed the new
   bundle, refreshed Launch Services, and verified both cold and running-state
   URL dispatch: completed.
7. Normalize the persisted settings to the three valid states, disable Auto
   Switch when Only Play is off, remove the invalid continuous OFF/ON playback
   path, and retain the stopped Cue subtitle independently of Auto Switch:
   pending.

## Verification

- `git diff --check`: passed for the technical-contract change set.
- Confirmed the updated URL, playback, functional, and testing documents cite
  the committed human-owned requirement without modifying `docs/human/`.
- The original Playlist settings/playback focused selection passed against the
  superseded four-state interpretation. The owner corrected that contract in
  committed requirement version `b81e54b`; replacement three-state and subtitle
  retention verification is pending.
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
- Overlay Markdown-copy focused test selection: 6 tests passed, covering exact
  plain-string clipboard output without HTML/RTF, Current and Playlist `X`
  routing, settled Shiori Primary Cue identity, exact success feedback, and the
  Overlay Search exclusion.
- Two final full runs executed 761 tests each. All requirement-related tests
  passed. The first run reported only the existing native first-frame timing
  assertion
  `nativePlaybackUsesCommonTimelineWhenVideoTrackStartsAfterAudio`; the second
  non-parallel run reported only the existing shared-defaults isolation case
  `sharedPersistenceMigrationCopiesLegacyValuesWithoutOverwritingSharedValues`.
  Each reported test passed immediately in isolation.
- `scripts/package_macos_app.sh --output /private/tmp/CueSeeker.app`: passed,
  including controlled-runtime, ARM64, dependency-closure, ad-hoc signature,
  and bundle verification.
- Archived the prior `/Applications/CueSeeker.app` as
  `/Users/weiyunjun/Downloads/CueSeeker-20260712.app.zip`; `unzip -t` reported
  no errors and its SHA-256 is
  `c22c9caf4d1fef49e8818ac594b272b4f1d2b2f35d49dc812f02987024330b54`.
- Installed and re-verified `/Applications/CueSeeker.app`; its bundle ID is
  `com.cueseeker.app`, its declared URL Scheme is `cueseeker`, and its version
  is `0.1.0`.
- Refreshed Launch Services and opened distinct Search URLs from both cold and
  already-running states. Both calls resolved to the same installed
  `/Applications/CueSeeker.app/Contents/MacOS/CueSeeker` process.

## Outcome

The original implementation and package require the accepted three-state and
subtitle-retention correction before renewed owner end-to-end acceptance.
