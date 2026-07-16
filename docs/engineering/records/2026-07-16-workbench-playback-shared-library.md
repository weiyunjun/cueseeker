# Workbench-Owned Playback Recent and Library

## Requirement

- `docs/human/requirements/20260715-Feature-Shared Workbench Playback Feature Surfaces.md`

## Scope

Migrate Playback Recent, Library Folder, and Library Folder Detail to the
existing Workbench `LibraryStore` pipelines. Remove Playback-owned database
loaders, refresh tasks, revision tracking, and result collections while keeping
selection, hierarchy, and scroll position session-local.

## Steps

1. Made `LibraryStore.testRecentWatchingItems` and
   `completeLibraryFolderSummaries` the direct data sources for both Workbench
   and Playback.
2. Added the loaded Library Folder Detail collection and its statuses to
   `LibraryStore`, replacing Workbench view-local detail data and Playback
   session-local detail data with one shared cache.
3. Added one AppCoordinator Library detail pipeline that coalesces concurrent
   requests, publishes results to `LibraryStore`, cancels stale generations,
   and invalidates details when folder summaries or playback history change.
4. Routed Recent playback navigation and Library folder watch-state actions
   through the same shared detail cache instead of retaining a separate query
   result.
5. Reduced `PlaybackRecentSessionStore` to availability-aware selection and
   scroll state over `LibraryStore`; Session destruction no longer clears or
   cancels Workbench Recent data.
6. Reduced `PlaybackLibrarySessionStore` to folder/episode selection, hierarchy,
   and scroll state over `LibraryStore`; it no longer owns folders, details,
   database tasks, source revisions, or result refresh logic.
7. Deleted `PlaybackRecentLoader`, `PlaybackLibraryLoader`,
   `PlaybackLibrarySourceRevision`, their live database paths, and obsolete
   cancellation/cache tests. Replaced them with shared-store and session-local
   presentation lifecycle coverage.

## Verification

- `swift build` passed.
- `swift test` passed with 752 tests.
- Focused Recent, Library, shared folder-detail, playback-history, and
  multi-module tests passed.
- `git diff --check` passed.
- Repository search found no remaining Playback Recent/Library loader, source
  revision, or session-owned load-task symbols.

## Outcome

`LibraryStore` is now the authoritative Recent and Library data owner for both
surfaces, including loaded folder details. Playback observes those collections
directly and owns only the reviewed host differences: persistent selection,
directional navigation, Library hierarchy, and session-local scroll position.
Closing the Overlay clears that temporary presentation state without clearing
Workbench data or cancelling shared Feature Store work.

## Follow-Ups

- Remove obsolete generic Playback source/window infrastructure after reviewing
  the remaining Current, Playlist, and Reel consumers.
- Run the final full-flow verification and hand off the user E2E checklist.
