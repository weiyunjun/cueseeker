# Recent Videos Playback Refresh — Step 3

## Requirement

- `docs/human/requirements/20260731-Feature-Command Panel Search Integration And Recent Videos Refresh.md`

## Classification

- Recent Videos membership and refresh timing: product semantics.
- Shared Workbench and Command Panel presentation: existing platform UI/UX.
- Native media execution: unchanged.

## Cause

Opening a Library video recorded its Recent history before playback started but
deliberately deferred presentation refresh. The pending refresh normally ran
only after a later playback close or another lifecycle event, leaving loaded
Workbench and Command Panel Recent Videos projections stale during playback.

## Implementation

- Moved the existing Recent history write after the existing Library playback
  entry point reports a successful start.
- Used the existing playback-history presentation refresh path immediately
  after that write.
- Reused the authoritative `LibraryStore` overview and complete Recent
  projections; no state, task, query, or presentation collection was added.

## Verification

- `swift test --filter RecentPlayback`: 4 tests passed.
- `swift test --filter 'RecentPlayback|LibraryRouteSnapshotReuse|playbackEntry'`:
  8 tests passed.
- `git diff --check`: passed.

## Outcome

Library and Recent video entry now updates the shared Recent Videos projections
as soon as playback starts successfully. Workbench and an already loaded
Command Panel therefore observe the refreshed history during playback instead
of waiting for playback close.
