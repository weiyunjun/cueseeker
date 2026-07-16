# Playback Subtitle Navigation and Search Playlist Regressions

## Requirement

- `docs/human/requirements/20260715-Feature-Shared Workbench Playback Feature Surfaces.md`

## Scope

Restore the existing Playback Cue Reel keyboard behavior and preserve the
Workbench Search result run used by Playback Playlist after a Search result
starts playback.

## Steps

1. Replaced the published Playback-wide Pointer hide generation with a direct
   event consumed by the existing Player cursor owner. Pointer visibility for
   Recent and Library now travels through a nested visibility store observed
   only by those media layouts, so subtitle key-down no longer invalidates the
   Playback Page or Cue Reel.
2. Restored `PlaybackChromeVisibilityModel` ownership to the video stage and
   prevented repeated hidden-state assignments from publishing redundant
   updates.
3. Kept Search results resident and sourced from Workbench. The Playback
   Playlist provider now retains the Workbench result array for its exact Search
   run, refreshes it only from matching-run Workbench updates, and remains valid
   when Workbench starts a later run.
4. Routed adjacent Search playback navigation and availability checks through
   the retained Playlist source instead of the mutable current Workbench array.
5. Added regression coverage for non-invalidating Pointer hide requests and for
   reopening Playlist after Workbench has moved to another Search run.

## Verification

- Focused Playback Pointer, Search, Playlist, multi-module, and subtitle
  keyboard tests passed: 25 tests.
- The two new focused regression tests passed independently.
- Full `swift test` passed: 738 tests.

## Outcome

Subtitle Up and Down retain the pre-requirement Cue Reel path without unrelated
Playback Page refreshes. Search playback retains its complete resident Playlist
content across Overlay Session destruction and later Workbench Search changes,
without adding another database load or a second paging implementation.
