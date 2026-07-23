# Search Cue Group Persistence Fix

## Human-Owned Source

- `docs/human/requirements/20260723-Bug-Search Cue Group Disappears After Interaction And Tab Switching.md`
- Requirement commit: `e837f43`

## Classification And Scope

- Platform UI/UX correction in the shared native Search, Context, and Shiori
  table renderer.
- No product-semantic, database, playback, dependency, or architecture change.

## Cause

The row snapshot retains its latest update description, such as `.reload`,
alongside its version. Unrelated SwiftUI updates repeatedly passed that same
description to the native table after the version had already been applied.

Search commonly retains a `.reload` after replacing an existing result
projection. Selecting a row or remounting Search could therefore replay the old
reload, clear dynamic row and Cue Group measurements, and redraw before any new
row version requested remeasurement. The fallback drawing measurement contains
only the primary Cue. Shiori more commonly retained an initial `.append`, which
did not clear the measurements and therefore did not expose the same symptom.

## Changes

- Derived an effective row update from the row count and version transition.
- Applied `.reload`, `.append`, and cell invalidations only when their
  corresponding row version is new to the native coordinator.
- Preserved existing behavior for genuine reloads, appends, cell patches,
  column changes, and Show Cue Group changes.
- Added a coordinator regression test for repeated `.reload` metadata at the
  same row version.
- Added a mounted Search regression test covering Cue Group display across row
  selection and Search-to-Shiori-to-Search remounting.

## Verification

- `swift test --filter subtitleTableViewDoesNotReplayReloadForTheSameRowsVersion`
  - Passed 1 selected Swift Testing test.
- `swift test --filter searchCueGroupSurvivesSelectionAndPanelRemountAfterReload`
  - Passed 1 selected Swift Testing test.
- `swift test --filter CueGroupRefreshScopeIntegrationTests`
  - Passed all 14 selected Swift Testing tests.
- `swift test --filter subtitleTableView`
  - Passed all 81 selected Swift Testing tests.
- `swift test`
  - Passed all 7 XCTest tests.
  - Ran 838 Swift Testing tests. The full concurrent workload did not pass
    because 7 unrelated library-removal, playback, and Overlay asynchronous
    tests timed out or missed media expectations under suite load.
  - The complete Cue Group integration suite, including the new regression
    scenario, passed within the full run.
- Individual reruns of all 7 full-suite failures:
  - `libraryFolderRemovalPublishesProgressWithoutBlockingMainActor`
  - `nativePlaybackUsesCommonTimelineWhenVideoTrackStartsAfterAudio`
  - `playbackPlaylistCopyAndShioriTargetTheSettledPrimaryCue`
  - `playbackRecentPointerDispatcherUsesSharedWorkbenchItem`
  - `subtitleFocusShioriIdentityDistinguishesSameTimeSiblingCues`
  - `nativeAutoStopKeepsSessionAliveAndResumesFromBoundary`
  - `nativePlaybackRebuildsAudioOutputAndContinuesInCurrentSession`
  - Passed all 7 tests.

## Outcome

- Automated checks confirm that selection and panel remount no longer remove
  Cue Group measurement or rendered text fragments after a Search reload.
- Final visual and interaction acceptance remains with the human owner.
