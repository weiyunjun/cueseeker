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

## Follow-up Step 4: Search Playback Keyboard Focus

Date: 2026-06-07

Additional covering requirement commit: `51c762dc`

### Scope

Fix keyboard shortcut focus when entering playback from Search result rows,
including the test Search table.

### Changes

- Added `preparePlaybackKeyboardFocus()` to clear Search focus and release the
  current key window first responder before opening a Search result.
- `openSearchResult` now calls that focus preparation before expanding playback,
  so all Search result entry points share the same playback shortcut behavior.

### Verification

- Passed: `swift build`
- Passed: `swift test --jobs 1 --filter PlaybackQuickSearch`
  - 14 Testing tests passed.

### Outcome

Opening a Search result no longer leaves the previous Search input or test table
focus as the active responder, which keeps playback keyboard shortcuts available
after entering playback from the test Search table.

## Follow-up Step 5: SRT Playback Subtitle Path

Date: 2026-06-07

Additional covering requirement commit: `51c762dc`

### Scope

Optimize the playback-surface SRT subtitle cue path so opening a video does not
synchronously read the full subtitle file into playback cues and active subtitle
lookup does not linearly scan every cue on each playback time refresh.

### Changes

- Search, Shiori, and Library playback now set only an initial SRT fallback cue
  before opening playback.
- Full SRT cue loading now runs in a cancellable background task after playback
  opens.
- Background SRT cue loads are guarded by the current video/subtitle path before
  updating the `PlaybackViewModel`, preventing stale task writeback.
- Playback stop and database reindexing cancel the background SRT cue task.
- `PlaybackSubtitleTrack.activeText(at:)` now uses a start-time binary search
  plus prefix maximum end times instead of filtering the full cue array.
- Added a large-track subtitle lookup test to cover late-cue lookup behavior.

### Verification

- Passed: `swift build`
- Passed: `swift test --jobs 1 --filter playbackSubtitleTrack`
  - 3 Testing tests passed.
- Passed: `swift test --jobs 1 --filter Playback`
  - 70 Testing tests passed.

### Outcome

Opening an SRT-backed playback item no longer performs full subtitle-entry
hydration on the main playback-opening path. Once the background track is ready,
active subtitle text lookup is indexed by time rather than a full-array scan.

## Regression Fix: Search Navigation Time Anchor

Date: 2026-06-07

Additional covering requirement commit: `51c762dc`

### Scope

Fix the Search previous/next regression where the result-ID index navigation
path anchored only to the originally selected result/rank and ignored the
current playback time.

### Changes

- Restored time-first navigation anchoring for
  `searchNavigationSnapshotFromResultIDIndex`.
- The result-ID path now resolves the latest matching cue in the current
  playback video/subtitle at or before the displayed playback time, then maps
  that cue back to the cached global result rank.
- The selected result/rank remains the fallback when no playback-time match is
  available.
- Added a regression test covering playback moving from an earlier selected
  Search result to a later matching cue in the same video.

### Verification

- Passed: `swift test --jobs 1 --filter searchNavigationSnapshotUsesCachedResultIDIndexWindow`
- Passed: `swift test --jobs 1 --filter Search`
  - 57 Testing tests passed.
- Passed: `swift test --jobs 1 --filter PlaybackNavigation`
  - 14 Testing tests passed.

### Outcome

The cached result-ID navigation path now preserves the previous time-based
playback anchor behavior. When playback has naturally advanced to a later
matching Search result in the same video, previous/next navigation uses that
current playback position instead of the originally clicked result.

## Final Verification

Date: 2026-06-07

- Passed: `swift test --jobs 1`
  - 7 XCTest tests passed.
  - 232 Testing tests passed.

The five requested implementation steps are complete in code. Human end-to-end
acceptance is still required for subjective scrollbar smoothness and playback
feel on large real-world Search/SRT/ASS datasets.
