# Workbench-Owned Playback Shiori

## Requirement

- `docs/human/requirements/20260715-Feature-Shared Workbench Playback Feature Surfaces.md`

## Scope

Migrate Playback Shiori and Shiori-origin Playlist navigation to the existing
Workbench `ShioriStore` result state. Keep the complete loaded text collection
resident in the Workbench store, virtualize presentation only, and remove the
replaced Playback database paging and result retention.

## Steps

1. Moved Shiori table loading out of the Workbench view into one
   `AppCoordinator` pipeline so Workbench and Playback share the same submitted
   search, filter, result-ID order, hydrated rows, cancellation, and reload
   lifecycle.
2. Kept the existing first-page and continuation paging implementation for
   database hydration, then continued loading until the complete result text
   collection was installed in `ShioriStore.tableRowStore`.
3. Extended the table snapshot to retain each row's exact
   `ShioriCuePresentation`, allowing Playback actions to reuse the Workbench
   cue identity and surrounding text without another query.
4. Made the Playback Shiori Reel project items by ordinal directly from the
   shared table snapshot. Its presentation window retains no duplicate Shiori
   item array and observes Workbench snapshot updates.
5. Made Shiori-origin Playlist sources project table, explicit-ID, and database
   order scopes from `ShioriStore`; table navigation uses the Workbench result
   ID order rather than a Playback-owned identity index.
6. Routed successful Playback Shiori saves through one Workbench invalidation
   and reload, while preserving the existing legacy Shiori list hydration
   without a second table invalidation.
7. Deleted the Playback-only Shiori overlay loader and the Shiori page/count
   methods from `PlaybackSubtitleFocusDatabaseReader`, and replaced their tests
   with shared-store, zero-duplicate-retention, filter, action, navigation, and
   lifecycle coverage.

## Verification

- `swift build` passed.
- `swift test` passed with 757 tests.
- Focused Playback Shiori, Shiori-origin Playlist, keyboard-save, and mounted
  Workbench Shiori tests passed.
- `git diff --check` passed.
- Repository search found no remaining Playback Shiori page/count loader,
  `makePlaybackShioriOverlaySource`, or `refreshShioriAfterSave` references.

## Outcome

Workbench `ShioriStore` is now the authoritative Shiori result state for both
surfaces. Playback owns only presentation adapters and selection state. Once
the Workbench pipeline has loaded the complete result collection, keyboard and
scrollbar navigation read resident text synchronously and do not trigger
Playback-specific database paging.

## Follow-Ups

- Migrate Playback Recent and Library to `LibraryStore`.
- Remove the remaining generic Playback source/window loading infrastructure
  after its final non-shared consumer is migrated.
