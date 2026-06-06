# Playback Search And Subtitles Navigation Virtualization Performance

Date: 2026-06-07

Human requirement:

- `docs/human/requirements/20260607-Feature-Playback Search And Subtitles Navigation Virtualization Performance.md`
- Covering requirement commit: `93f19906`

## Scope

Optimize playback side-panel Search navigation/results and current-video
subtitle list loading without changing the visible UI style. This record covers
the implementation requested after the test table virtualization work exposed
that playback navigation and side-panel lists still had full-result/full-file
loading paths.

## Changes

- Search playback previous/next now asks `SubtitleDatabase` for a navigation
  snapshot from the cached exact result-ID order instead of materializing every
  search result.
- Search navigation falls back to already loaded Search rows when the exact
  result-ID index is not ready, avoiding a blocking full exact rebuild.
- Playback Search side-panel rows are rendered from the current navigation
  window with global ranks, plus invisible top/bottom spacers to preserve the
  total scroll range.
- Current-video subtitles now load a lightweight subtitle entry index first and
  hydrate only the active subtitle window into `PlaybackStore`.
- Current-video subtitle side-panel rows use the windowed entries plus invisible
  top/bottom spacers to represent unloaded rows.
- Window loads are cancelled and guarded by the current subtitle path/search
  context so stale work cannot overwrite a newer playback context.
- Sidebar scroll-to-selected/active now retries when a new window arrives.

## Verification

- Passed: `swift test --jobs 1 --filter searchNavigationSnapshotUsesCachedResultIDIndexWindow`
- Passed: `swift test --jobs 1 --filter subtitleEntryIndexAndWindowLoadCurrentSubtitleRows`
- Passed: `swift test --jobs 1 --filter searchNavigationUsesCompleteResultOrderAndPlaybackTimeAnchor`
- Passed: `swift test --jobs 1 --filter storesSubtitleEntriesAndSearchesWithFTS5`
- Passed: `swift test --jobs 1 --filter PlaybackStore`
- Passed: `swift test --jobs 1 --filter Search`
  - 57 Testing tests passed.
- Passed: `swift test --jobs 1 --filter Playback`
  - 69 Testing tests passed.
- Passed: `swift test --jobs 1`
  - 7 XCTest tests passed.
  - 231 Testing tests passed.

One full-test attempt failed before running tests due to a macOS
`posix_spawn`/fork resource error. The retry succeeded.

## Outcome

The App no longer calls the old full-result `searchNavigationSnapshot` path for
playback Search previous/next or side-panel results. That old Core method
remains for compatibility tests, but playback uses result-ID windows or already
loaded results.

Current-video subtitles no longer require full subtitle text hydration into the
side-panel data source before display. The side panel keeps a lightweight timing
index for active-cue lookup and hydrates only a bounded row window.

Human end-to-end acceptance is still required for the subjective macOS playback
side-panel scroll and next-result feel.
