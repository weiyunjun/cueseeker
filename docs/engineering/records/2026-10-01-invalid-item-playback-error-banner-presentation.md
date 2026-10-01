# Invalid Item Playback Error Banner Presentation

Human-owned documents:

- `docs/human/requirements/20261001-Bug-Invalid Item Playback Error Banner Presentation.md`

## Why

1. When clicking an invalid search result or excerpt item that is no longer in the library, playback enters a black screen state. Previously, the error banner presentation lifecycle was incomplete:
   - When switching from an invalid item to a valid item, the red error banner (`This item is no longer in the library`) lingered for up to 5 seconds instead of immediately disappearing.
   - When opening an invalid item whose resulting playlist was completely empty, the required 1-second centered feedback (`No Available Results`) was not presented.
2. In `PlaybackLibraryChangeTests`, several older assertions had outdated English strings from before the toast unification requirement.

## What changed

- **Error Banner Immediate Dismissal**:
  - `PlaybackStore`: Added `clearAllErrors()` to dismiss all error banner lines immediately.
  - `AppCoordinator+Excerpt`: In `openExcerpt` (when `itemInLibrary == true`) and `play(_ excerpt:)`, immediately calls `playback.clearError(on: .notInLibrary)`.
  - `AppCoordinator+Playback`: In `openSearchResult` (when `itemInLibrary == true`) and `play(_ result:)`, immediately calls `playback.clearError(on: .notInLibrary)`.
  - `AppCoordinator+Library`: In `openLibraryVideo` and `play(_ video:)`, immediately calls `playback.clearError(on: .notInLibrary)`.
  - `AppCoordinator+Playback`: In `stopPlayback()`, calls `playback.clearAllErrors()` to cleanly dismiss all error lines when exiting playback via back button, ESC, or Backspace.

- **Empty Playlist Centered Feedback**:
  - In `openSearchResult` and `openExcerpt`, when `!itemInLibrary` and `(playback.playlistSource?.boundary.totalCount ?? 0) == 0`:
    Calls `playback.playbackViewModel?.showNoAvailableNavigationFeedback(direction: nil, text: L("playback.hud.no_available_results"))` to display the centered HUD warning for 1 second.

- **Playlist Validity Filtering**:
  - `AppCoordinator+PlaybackPlaylist`: In `installSearchPlaybackPlaylistSource`, enhanced `liveCueIDs` calculation to verify `!isCueInLibrary(result.entryID)` against the library database, guaranteeing invalid search items are excluded from the playlist.

## Tests

- `ExcerptLifecycleAndInvalidItemsTests`:
  - `openingInvalidExcerptShowsNotInLibraryErrorAndStopsPlayer`: Asserts red error banner is shown on black screen, 1-second `No Available Results` center HUD is displayed when playlist is empty, and `stopPlayback()` immediately clears the banner.
  - `invalidExcerptKeepsPlaylistSourceAndAllowsNavigatingToSurvivingExcerpt`: Asserts red error banner is shown on invalid excerpt, and navigating via `goNext()` to a surviving valid excerpt immediately dismisses the banner.
- `SearchInvalidItemsPruningTests`:
  - `invalidSearchResultShowsErrorBannerAndNavigatesToSurvivingResultClearingError`: Asserts red error banner is shown on invalid search result, playlist contains surviving items, and navigating via `goNext()` to a valid result immediately clears the banner.
  - `openingInvalidSearchResultWithEmptyPlaylistShowsErrorBannerAndNoAvailableResultsFeedback`: Asserts opening an invalid search result with empty playlist displays red error banner and 1-second centered `No Available Results` feedback.
- `PlaybackLibraryChangeTests`: Updated assertions to match unified toast strings (`Cue Not in Library`, `No Available Results`).
- All 14 tests in `PlaybackLibraryChangeTests`, all 5 tests in `SearchInvalidItemsPruningTests`, and all 4 tests in `ExcerptLifecycleAndInvalidItemsTests` pass.
