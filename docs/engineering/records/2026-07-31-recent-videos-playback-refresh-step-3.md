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

## 2026-08-01 Acceptance Follow-Up

### Cause

The playback-start refresh fixed Recent Videos membership and order, but the
Command Panel did not use the playback Modal's existing pending-history
publication boundary. Its Recent projection could therefore retain the prior
progress and resolve the first item to an older resume position. The synchronous
shutdown save also returned immediately after the active source had changed,
even when an earlier Library write was still queued.

### Implementation

- Made successful shared playback Modal suspension publish pending Library
  playback history for both playing and already-paused entry.
- Removed the duplicate Subtitle Focus publication call; Command Panel and
  Subtitle Focus now follow the same lifecycle rule.
- Made the existing synchronous shutdown save drain queued history writes when
  there is no longer a current Library source, without refreshing UI state.
- Added no timer, state source, cache, query path, or entry-specific
  synchronization.

### Verification

- `swift test --no-parallel --filter RecentPlayback`: 6 tests passed.
- Related Playback, Overlay, Recent, Library-route, URL Scheme, and playback
  history regression selection: 188 tests passed.
- `swift build`: passed.
- `git diff --check`: passed.

### Outcome

Command Panel Recent Videos now observes the latest persisted playback progress
before selection, and shutdown waits for queued Library progress even after a
source change.
