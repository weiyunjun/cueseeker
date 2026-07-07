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

## Verification

- `git diff --check`
- `swift test --filter playbackChromeSnapshotUsesEntryMetadataAcrossSources`
- `swift test --filter PlaybackNavigation`
- `swift test --filter Playback`
- `swift test` (XCTest 7 tests, Swift Testing 400 tests)

## Outcome

Playback chrome now reads title and previous/next availability from a unified
entry snapshot seeded by Search, Shiori, and Library playback entry points.
Hover-driven player chrome rebuilds no longer derive display titles or
navigation availability by branching back through source-specific store state.
