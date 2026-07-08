# UI Local Refresh Boundaries Follow-up

Date: 2026-07-08

Human-owned sources:
- `docs/human/design/UI.md`
- `docs/human/requirements/20260708-Bug-UI Refresh Scope Contract Coverage.md`

## Summary

Scoped three follow-up refresh paths without changing the existing Cues flexible column behavior:

- Sidebar visibility changes now publish layout state without invalidating workbench route observers.
- Sidebar expand / collapse no longer reuses the video-size transition state observed by playback.
- Search and Shiori checkbox selection no longer starts per-toggle collage availability tasks.
- Table viewport growth is classified as a Cues width change so the virtual table can use Cues-local dirty regions and avoid full header host refreshes for that resize case.

## Implementation

- Added `WorkbenchRouteState` and routed panel mode, search focus, and test-library folder selection through it.
- Updated `SearchView` and `WorkbenchTestLibraryView` to observe route state instead of broad layout state.
- Updated app environment injection so views can subscribe to route state directly.
- Removed sidebar toggle use of `beginVideoSizeTransition`.
- Converted Search/Shiori collage availability refresh from async per-selection tasks to synchronous snapshot checks with deduplicated state writes.
- Added Cues-only layout diff helpers to `SubtitleTableColumnLayout`, Cues-only header refresh, and Cues-column dirty invalidation during viewport-only table width growth.

## Verification

- `git diff --check`
- `swift build`
- `swift test --filter WorkbenchLayoutStateTests`
- `swift test --filter SubtitleTableVirtualRowTests`
- `swift test --filter PlaybackStoreTests`

Result: All listed checks passed.
