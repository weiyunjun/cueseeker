# Test Library Complete Library

Human requirement:

- `docs/human/requirements/20260621-Feature-Test Library.md`

## Scope

Implemented the first Complete Library slice for the Test Library page while
leaving the existing Recent Watching slice intact.

## Classification

- Product semantics: Complete Library folder/video presentation, watch-state
  derivation, latest watched episode, and continue-target selection live in
  `CueSeekerCore`.
- Platform UI/UX: Complete Library section rendering, folder cards, disclosure
  controls, episode cards, hover/pressed/disabled states, and empty/loading
  states live in SwiftUI.
- Platform integration: asynchronous loading, cancellation, indexing refresh,
  and in-app expansion-state persistence live in `AppCoordinator` and
  `LibraryStore`.
- Playback execution: folder Continue Watching and episode-card clicks reuse
  the existing Library playback path and resume-position loading.

## Changes

- Added `LibraryWatchState`, `CompleteLibraryVideoPresentation`, and
  `CompleteLibraryFolderPresentation`.
- Added `completeLibraryPresentation(under:)` to read Library rows, playback
  history, generated video covers, and folder covers without changing database
  schema.
- Implemented Continue Watching selection as the last `Watching` episode,
  otherwise the first `Unwatched` episode, otherwise the first episode.
- Added Complete Library loading/data/revision state and in-app expanded folder
  state to `LibraryStore`.
- Added Complete Library refresh, cancellation reset, removal pruning, and
  indexing refresh hooks.
- Added the Test Library Complete Library section with folder cards, Neutral
  Continue Watching buttons, disclosure controls, and wrapping episode cards.
- Added database tests for Complete Library presentation, continue-target
  selection, and fallback behavior.
- Extended the database-read cancellation test to include Complete Library
  loading state.

## Verification

- `swift test --filter completeLibrary` succeeded with 2 selected tests.
- `swift test --filter cancelDatabaseReadsResetsLibraryLoadingStates` succeeded
  with 1 selected test.

## Outcome

Complete Library now loads real indexed Library data in the Test Library page,
keeps expansion state during the App session, exposes folder-level Continue
Watching, expands folders into wrapping video cards, and opens videos through
the existing resume-capable Library playback path.

## Known Follow-Up

- Exact page scroll-position restoration is not implemented in this slice. The
  expanded/collapsed state persists during the App session; scroll behavior can
  be refined after end-to-end UI testing.
