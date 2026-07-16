# Workbench-Owned Playback Search

## Requirement

- `docs/human/requirements/20260715-Feature-Shared Workbench Playback Feature Surfaces.md`

## Scope

Migrate Playback Search and Search-origin Playlist navigation to the existing
Workbench Search state and query pipeline. Remove the replaced Playback-only
search runner, database paging, hydrated-result cache, promotion truncation,
and delayed adjacent-item loading.

## Steps

1. Added an explicit temporary Playback filter context to `SearchStore` while
   keeping the formal Workbench filter unchanged until playback starts
   successfully.
2. Reused `AppCoordinator.startSearch` for Playback Search input, visible-page
   loading, exact completion, cancellation, and the 100 ms input debounce.
3. Made the Playback Search Reel read items by ordinal from
   `SearchStore.searchResults`; the presentation window retains no duplicate
   result array and publishes the whole currently loaded collection to the
   existing render virtualization layer.
4. Made Search-origin Playlist navigation index the same in-memory Workbench
   result collection synchronously, without a database window fallback.
5. Kept the full temporary Search result collection when playback succeeds and
   restored the formal Workbench filter through the same Search pipeline when
   the overlay closes or playback fails.
6. Deleted `PlaybackSearchSessionStore`, `PlaybackSearchRun`, their independent
   page loaders and database readers, the Playback-search source origin, and
   their obsolete tests.
7. Replaced the removed tests with shared-store, zero-duplicate-retention,
   temporary-filter, failed-play, Playlist, and multi-module lifecycle coverage.

## Verification

- `swift build` passed.
- `swift test` passed with 766 tests.
- Focused Playback Search, Search-origin Playlist, and multi-module tests
  passed after the final lifecycle changes.
- `git diff --check` passed.
- Repository search found no remaining `PlaybackSearchSessionStore`,
  `PlaybackSearchRun`, `PlaybackSearchPageLoader`, or Playback-search source
  origin references.

## Outcome

Playback Search now has one authoritative result collection: the Workbench
`SearchStore`. Database work, paging, exact completion, cancellation, and input
debounce are the existing Workbench implementation. Playback adds only the
reviewed empty-filter context and Reel presentation adapter. Once results are
loaded, keyboard and scrollbar navigation do not fetch more text or wait for a
Playback-specific window loader.

## Follow-Ups

- Migrate Playback Shiori to `ShioriStore`.
- Migrate Playback Recent and Library to `LibraryStore`.
- Remove the remaining generic Playback source/window loading infrastructure
  after its final non-Search consumer is migrated.
