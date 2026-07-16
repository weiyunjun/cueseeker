# Playback Resident Cue Result Sources

## Requirement

- `docs/human/requirements/20260715-Feature-Shared Workbench Playback Feature Surfaces.md`

## Scope

Remove the obsolete Playback-owned paging and result-retention transport after
Search and Shiori became direct consumers of their Workbench-owned in-memory
collections. Keep only session selection and Reel presentation virtualization.

## Steps

1. Reduced `PlaybackPlaylistSource` to an origin, collection boundary, and
   ordinal item provider over the authoritative resident feature collection.
2. Removed the async window loader, request and response models, batch policy,
   load accumulator, pending requests, load tasks, stable-identity copy, and
   compatibility aliases.
3. Reduced `PlaybackPlaylistSessionWindowStore` to dataset metadata and
   session-local selection. Its snapshot always describes the complete resident
   collection, and item access delegates directly to the source provider.
4. Removed Reel window requests. The Reel still virtualizes measurement,
   drawing, placement, scrolling, and scrollbar geometry through its bounded
   presentation caches.
5. Updated Search, Shiori, Playlist, keyboard-action, and multi-module tests to
   verify immediate resident access, shared Workbench ownership, lifecycle,
   selection validation, and large-collection rendering bounds without testing
   the deleted loader implementation.

## Verification

- Focused Playback Playlist, Search, Shiori, keyboard-action, multi-module, and
  Reel tests passed with 18 tests.
- The 50,000-item Reel test kept measurement state at or below 64 entries and
  mounted fewer than 50 placements while selecting the scrollbar target from
  the resident collection.
- `swift test` passed with 732 tests. The first full run had one transient
  three-second asynchronous Shiori-save timeout; that test passed alone in
  0.083 seconds, and the complete 732-test rerun passed.
- `git diff --check` passed.
- Repository search found no remaining Playback result window request,
  response, loader, batch policy, accumulator, or retained item-array symbols.

## Outcome

Playback no longer has a second data-loading or result-retention path for
Playlist, Search, or Shiori Cue Results. Keyboard and scrollbar targets resolve
directly against the complete authoritative in-memory collection, while Reel
work remains limited to viewport presentation virtualization. The change
deletes the replaced infrastructure instead of preserving compatibility code
for nonexistent consumers.

## Follow-Up

- Run the final cross-surface verification and hand off the manual E2E checklist.
