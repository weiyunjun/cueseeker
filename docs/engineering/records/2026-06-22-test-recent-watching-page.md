# Test Recent Watching Page

Human requirement:

- `docs/human/requirements/20260621-Feature-Test Library.md`

## Scope

Implemented the first slice of the revised Test Library interaction model:
adding a standalone Test Recent Watching page while leaving the existing Test
Library page behavior intact for this step.

## Classification

- Product semantics: Recent Watching still derives from Library playback
  history and keeps the newest Library-originated video per folder in
  `CueSeekerCore`.
- Platform UI/UX: the new test-page entry, page shell, adaptive Recent Watching
  card wall, loading/empty/error states, and card click behavior live in
  SwiftUI.
- Platform integration: asynchronous full-history loading, cancellation reset,
  and indexing/playback-history refresh hooks live in `AppCoordinator` and
  `LibraryStore`.
- Playback execution: card clicks reuse the existing Library playback path and
  saved resume position.

## Changes

- Added a `Test Recent Watching` top-bar test entry before `Test Library` using
  the system clock symbol.
- Added `WorkbenchTestRecentWatchingView` as a standalone page that reuses the
  existing Recent Watching card visual treatment.
- Added independent Test Recent Watching loading/data/revision state so the
  existing Test Library page can keep its current five-item Recent Watching
  behavior.
- Added full-history Recent Watching loading for the standalone page by reading
  all merged folder history rows instead of the legacy five-item limit.
- Refreshed the standalone page state after Library playback-history writes
  only when that page state has already been loaded.
- Included the standalone page read task in indexing cancellation and database
  compaction gating.
- Added tests for full Recent Watching history retrieval and cancellation-state
  reset.

## Verification

- `swift test --filter recentLibraryWatching` passed.
- `swift test --filter cancelDatabaseReadsResetsLibraryLoadingStates` passed.
- `swift test --quiet` passed: 315 Swift tests plus 7 XCTest cases.

## Outcome

The standalone Test Recent Watching entry can be validated independently before
the existing Test Library page is reshaped into the new folder-first flow.
