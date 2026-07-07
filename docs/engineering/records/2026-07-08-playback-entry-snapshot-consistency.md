# Playback Entry Snapshot Consistency

## Human-Owned Source

- `docs/human/requirements/20260708-Bug-Playback Entry Snapshot Consistency.md`

## Scope

Unify the playback entry metadata used by Search, Shiori, and Library playback
so the player chrome reads a single lightweight snapshot instead of deriving
source-specific state during hover-driven UI rebuilds.

## Changes

- Added a `PlaybackChromeSnapshot` on `PlaybackStore` for player title,
  previous/next availability, and whether playback has a selected item.
- Changed `PlaybackVideoStage` and `PlaybackChromeView` to read title and
  navigation availability from the snapshot.
- Updated Search, Shiori, and Library playback entry points to seed the shared
  snapshot when playback opens.
- Passed existing row/card display titles from Search, Shiori, and Library
  entry surfaces into the shared playback entry APIs.
- Kept previous/next commands routed through the existing AppCoordinator
  actions; the snapshot only owns player-chrome display and enabled state.
- Added regression coverage that opens playback through Search, Library, and
  Shiori and verifies the shared chrome snapshot receives entry metadata.

## Follow-Up Changes

- Aligned Shiori and Library playback entry preparation with Search by clearing
  workbench keyboard focus before playback state is selected.
- Removed unused Search, Shiori, and Library environment subscriptions from the
  playback page/stage where playback rendering did not read those stores.
- Kept player top/bottom chrome mounted during pointer-driven visibility
  changes and hid it with opacity/hit-testing instead of removing and
  rebuilding the control tree.
- Added a guard so repeated requests for the current player UI visibility state
  do not publish duplicate chrome visibility updates.
- Added regression coverage that Search, Library, and Shiori playback entries
  all clear workbench focus before playback proceeds.

## Playback Overlay Interaction Freeze

- Marked the underlying Workbench content as externally covered while
  `PlaybackPageView` is visible, and disabled Workbench hit testing underneath
  the playback route.
- Preserved parent external-layer state inside `SchemaWorkbenchSearchShell` so
  shell-local popover state no longer overwrites the playback overlay freeze.
- Extended the table cursor refresh path to skip cursor work while an external
  overlay layer is open, matching the existing table hover suppression rules.
- Added regression coverage for cursor-region suppression when the table is
  externally covered.

## Verification

- `git diff --check`
- `swift test --filter playbackChromeSnapshotUsesEntryMetadataAcrossSources`
- `swift test --filter PlaybackNavigation`
- `swift test --filter Playback`
- `swift test` (XCTest 7 tests, Swift Testing 400 tests)

Follow-up verification:

- `git diff --check`
- `swift test --filter playbackEntryClearsWorkbenchFocusAcrossSources`
- `swift test --filter playbackChromeSnapshotUsesEntryMetadataAcrossSources`
- `swift test --filter PlaybackNavigation`

Playback overlay freeze verification:

- `git diff --check`
- `swift test --filter subtitleTableViewSuppressesInteractiveCursorRectsWhenExternalLayerIsOpen`
- `swift test --filter playbackEntryClearsWorkbenchFocusAcrossSources`
- `swift test --filter playbackChromeSnapshotUsesEntryMetadataAcrossSources`
- `swift test --filter PlaybackNavigation`
- `swift test` (XCTest 7 tests, Swift Testing 402 tests)

## Outcome

Playback chrome now reads title and previous/next availability from a unified
entry snapshot seeded by Search, Shiori, and Library playback entry points.
Hover-driven player chrome rebuilds no longer derive display titles or
navigation availability by branching back through source-specific store state.

The follow-up closes the remaining entry inconsistency: Shiori and Library now
use the same playback entry focus preparation as Search, and pointer-driven
chrome visibility no longer destroys and recreates the top bar or bottom
controls while the playback page is active.

The playback overlay freeze follow-up keeps the underlying Workbench table out
of hit testing and table hover/cursor work while playback is visible, so
pointer-driven player chrome changes are no longer coupled to the covered
Search, Shiori, or Library workbench surface.
