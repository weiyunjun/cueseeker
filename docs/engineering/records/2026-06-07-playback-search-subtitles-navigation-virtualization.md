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

## Follow-up Step 1: Sidebar Virtual List Foundation

Date: 2026-06-07

Additional covering requirement commit: `51c762dc`

### Scope

Start the five-step follow-up requested after the requirement was extended to
cover playback shortcut focus and the SRT playback subtitle path. This step adds
the reusable side-panel virtual list foundation only; Search Results and
Subtitles are connected in later steps.

### Changes

- Added `PlaybackSidebarVirtualList`, an AppKit-backed virtual list for playback
  side-panel rows.
- The list keeps an `NSScrollView` document height for the scrollbar while only
  hosting SwiftUI row views for the visible row range plus overscan.
- The list reports visible row ranges and supports centered row scroll targets,
  so Search and Subtitles can later load content by offset instead of relying on
  SwiftUI spacer rows and `ScrollViewReader.scrollTo`.

### Verification

- Passed: `swift build`

### Outcome

The playback side panel now has a reusable renderer foundation that separates
scrollbar range from hosted row views. Existing UI behavior is not changed until
the Search Results and Subtitles tabs are migrated onto this foundation.

## Follow-up Step 2: Search Results Offset Window

Date: 2026-06-07

Additional covering requirement commit: `51c762dc`

### Scope

Connect the playback Search Results side-panel tab to the virtual list
foundation. This step targets the blank-panel and sequential-loading behavior
seen when dragging the side-panel scrollbar over large Search result sets.

### Changes

- Added Search store state for the side-panel visible result window, its start
  index, total count, and row version.
- Added a cancellable `searchNavigationVisibleWindowTask` owned by
  `AppCoordinator`.
- Added `loadSearchNavigationVisibleWindow(rows:)`, which loads the requested
  visible row range by global Search rank using the cached result-ID index and
  `searchIndexedVisiblePage`.
- Kept playback previous/next navigation snapshot state separate from the
  side-panel visible-window state, so scrolling the side panel does not mutate
  the playback navigation anchor.
- Replaced the Search side-panel `ScrollViewReader`/`LazyVStack` spacer path
  with `PlaybackSidebarVirtualList`.
- Search reset and Playback Quick Search submission now clear the side-panel
  visible window and cancel stale loads.

### Verification

- Passed: `swift build`
- Passed: `swift test --jobs 1 --filter Search`
  - 57 Testing tests passed.

### Outcome

The Search Results side panel now maps scrollbar position to global result
offset and requests the current visible window directly. It no longer renders
giant SwiftUI spacer rows or depends on `ScrollViewReader.scrollTo` to reach the
selected result.

## Follow-up Step 3: Current Subtitles Offset Window

Date: 2026-06-07

Additional covering requirement commit: `51c762dc`

### Scope

Connect the playback Subtitles side-panel tab to the virtual list foundation.
This step targets fast scrollbar dragging in the current-video subtitle list and
removes the same spacer/scroll-to coupling that affected Search Results.

### Changes

- Added a subtitle row version and row lookup helper to `PlaybackStore`.
- Added `loadCurrentSubtitleEntriesWindow(rows:)`, which loads the requested
  current-video subtitle row range using `entries(forSubtitleFile:limit:offset:)`.
- The current-video subtitle refresh now clears the old window before loading a
  new subtitle file window so stale indexes cannot drive a new video's side
  panel.
- Replaced the Subtitles side-panel `ScrollViewReader`/`LazyVStack` spacer path
  with `PlaybackSidebarVirtualList`.
- The Subtitles tab now maps each virtual row to the subtitle file's global
  cue index and requests visible windows by offset.

### Verification

- Passed: `swift build`
- Passed: `swift test --jobs 1 --filter Playback`
  - 69 Testing tests passed.
- Passed: `swift test --jobs 1 --filter subtitleEntryIndexAndWindowLoadCurrentSubtitleRows`

### Outcome

The current-video Subtitles side panel now loads the current visible subtitle
window by offset instead of scrolling through placeholder spacer rows. Fast
scrollbar movement can request the destination window directly.
