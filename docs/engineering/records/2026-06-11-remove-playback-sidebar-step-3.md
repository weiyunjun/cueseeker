# Remove Playback Sidebar Step 3

Human requirement:

- `docs/human/requirements/20260611-Feature-Remove Playback Sidebar Performance Regression.md`

## Scope

This record covers step 3 of the playback sidebar removal: removing automatic
sidebar data preparation from playback startup and subtitle-path refresh. It
does not remove playback-time sidebar synchronization or the remaining sidebar
list implementation, which are reserved for the next scoped step.

## Changes

- Removed playback-page appearance and subtitle-path hooks that eagerly refreshed
  sidebar search navigation and current-video subtitle-list data.
- Removed the automatic search-navigation snapshot refresh after opening a
  search result for playback.
- Preserved the on-demand previous/next search result path, which still loads a
  navigation snapshot when the user invokes previous or next.

## Verification

- `swift build --product CueSeeker`

## Outcome

- Opening a video no longer automatically prepares sidebar search navigation or
  sidebar subtitle-list data.
- Search result previous/next remains available through the normal playback
  navigation command path instead of playback-start preloading.
