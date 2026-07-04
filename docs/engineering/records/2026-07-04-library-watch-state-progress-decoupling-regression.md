# Library Watch State Progress Decoupling Regression

## Human-Owned Source

- `docs/human/requirements/20260704-Feature-Library Card Action Menus.md`
- `docs/human/requirements/20260704-Bug-Library Finished State Forces Progress To 100 Percent.md`

## Scope

Fix the regression where Library card menu watch-state actions reused playback
history as the state store. That made `Mark as Finished` overwrite the saved
resume position and made `Mark as Unwatched` remove the playback history row,
which also removed the video from Recent.

## Classification

- Product semantics: watch state is explicit state; playback position remains
  the saved resume position.
- Platform UI/UX: unchanged menu labels and triggers.
- Platform integration: unchanged Finder and Context actions.
- Playback execution: unchanged playback and progress recording paths, except
  playback history writes now synchronize explicit watch state separately from
  progress.

## Changes

- Added `library_watch_states` as an explicit watch-state table.
- Backfilled watch-state rows from existing playback history during schema
  migration so current data keeps its visible state.
- Updated Library and Recent presentation queries so progress and Recent
  membership come from `library_playback_history`, while status labels come
  from `library_watch_states`.
- Updated direct playback-history reads to project explicit watch state without
  changing saved position, duration, or progress timestamps.
- Changed manual `setLibraryWatchState` writes to update only explicit watch
  state instead of touching `position_ms`, `duration`, `updated_at`, or deleting
  playback history.
- Kept regular playback progress writes from downgrading an existing Finished
  state back to Watching.
- Corrected the regression test so `Mark as Finished` must preserve the real
  saved position and `Mark as Unwatched` must keep the video in Recent.

## Verification

- `git diff --check`
- `swift build`
- `swift test --filter setLibraryWatchStatePreservesPlaybackProgressAndRecentHistory`
- `swift test --filter libraryPlaybackHistoryKeepsFinishedStateAfterSeekingBack`
- `swift test --filter recentLibraryWatching`
- `swift test --filter completeLibrary`
- `swift test --filter migrationBackfillsLibraryPlaybackHistoryWatchStateColumns`
- `swift test`

## Outcome

`Mark as Finished` updates only explicit watch state and preserves the saved
progress value. `Mark as Unwatched` clears only the explicit watch-state label,
keeps playback history intact, and leaves the item eligible for Recent.
