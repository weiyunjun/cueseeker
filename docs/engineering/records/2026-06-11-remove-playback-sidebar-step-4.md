# Remove Playback Sidebar Step 4

Human requirement:

- `docs/human/requirements/20260611-Feature-Remove Playback Sidebar Performance Regression.md`

## Scope

This record covers step 4 of the playback sidebar removal: deleting playback-time
sidebar synchronization, sidebar window data, and the virtualized sidebar list
implementation. It preserves the minimal previous/next search result navigation
path by keeping search navigation snapshots.

## Changes

- Removed the playback-page time observer that updated the sidebar's active
  search result during playback.
- Removed current-video subtitle sidebar window state, loading tasks, and row
  lookup data from playback state and app coordination.
- Removed search-navigation visible-window state and loading tasks from search
  state and app coordination.
- Deleted the playback sidebar shell, subtitles list, virtual list, row-height
  metrics, and their dedicated sidebar tests.
- Renamed the Quick Search result row away from the sidebar namespace so Quick
  Search can still render search results without retaining the right-side
  playback sidebar.
- Temporarily disabled Quick Search current-subtitle-line preselection by
  providing no candidates; the replacement state machine is reserved for the
  follow-up requirement.

## Verification

- `swift build --product CueSeeker`
- `swift test --jobs 1 --filter SearchStoreTests`
- `swift test --jobs 1 --filter PlaybackSubtitleRefreshLifecycleTests`
- `swift test --jobs 1 --quiet`

## Outcome

- Playback no longer has right-side sidebar UI, sidebar data windows, or
  playback-time sidebar synchronization in the runtime path.
- Search previous/next can still load a navigation snapshot on demand.
