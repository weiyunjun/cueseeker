# Search And Shiori Facet Filter Step 5

## Human-Owned Source

- `docs/human/requirements/20260728-Feature-Search Shiori Secondary Views And Table UI Refinement.md`

## Scope

Replace the Workbench Search Filter Editor entry point with the visible facet
data panel while preserving Shiori's existing editor until its own later step.
Persist Search selections, keep empty-query counts cache-backed, and leave
visual acceptance and `UI.md` changes to the human owner.

## Classification

- Product selection persistence: implemented in `SettingsStore`.
- App search lifecycle and table integration: implemented in `SearchStore` and
  `AppCoordinator`.
- Platform UI/UX: implemented with native SwiftUI Workbench components.
- Database and playback execution: reused without a new query path.

## Implementation

- Added one reusable `CueFacetFilterPanel` for Duration, Character, Language,
  and Watch Status.
- Displayed the four cards in one horizontal row. Each card has a minimum width
  and the panel scrolls horizontally when the window is narrow, so the table is
  not compressed by card wrapping.
- Changed the Search Filter button to show or hide the panel. Its open visual
  reuses the existing open-menu button state and it receives no count or Badge.
- Made Search panel visibility start as visible and remain session-only; no
  visibility key is written to preferences.
- Disabled every card option and displayed `Calculating` for each count while a
  non-empty query has no exact snapshot.
- Kept counts sourced from the complete unfiltered exact distribution while
  the table and Result Count Text use the current filtered projection.
- Loaded the empty-query distribution once from the index-maintained aggregate
  cache when `SearchStore` starts, then refreshed that value after indexed Cue
  or Watch Status changes. Opening Search does not scan Cue rows.
- Persisted Search selection as excluded raw values. This represents an empty
  card exactly, ignores removed values, and makes future values selected by
  default without a schema or version field.
- Removed the Primary Search Language and Search Scope controls from Settings.
  Workbench and Command Panel searches now use the complete language and watch
  domain; Command Panel does not receive the Workbench facet selection.
- Kept the old Filter Editor implementation and filter-only route available to
  Shiori and Context until their planned migration and cleanup steps.
- Extended exact text-copy hydration to accept the filtered ordered Cue IDs, so
  Select, copy, and export retain a complete filtered boundary.

## Verification

- `swift test --filter SettingsStoreSearchTests` passed all 7 tests, including
  default-all selection, partial and empty-card restoration, and forward
  compatibility for an unrecognized future value.
- `swift test --filter SearchStoreTests` passed all 30 tests, including panel
  default visibility, progressive facet projection, exact filtered count,
  Watch Status distribution refresh, context, and table hydration.
- `swift test --filter CueFacet` passed all 13 facet logic, cache, exact
  snapshot, and paged projection tests.
- `swift test --filter PlaybackSearchOverlayTests` passed all 4 Command Panel
  Search tests; `swift test --filter URLSchemeSearchRoutingTests` passed all 7
  URL Search tests.
- The complete `swift test` run executed 899 tests and reported 14 concurrent
  failures in shared-persistence migration, Library removal timeouts, Subtitle
  Focus timeouts, row-menu timing, UI invalidation probes, and native playback.
  Every affected area passed on isolated rerun: 2 persistence tests, 8 Library
  removal tests, 21 Subtitle Focus keyboard tests, 10 row-menu tests, 5 native
  playback timeline tests, the mounted Search invalidation test, both legacy
  filter-only mount tests, and the failed-removal Search restoration test.
- `git diff --check` passed.
- No visual acceptance was performed, as required. `docs/human/design/UI.md`
  remains unchanged and uncommitted.

## Outcome

Workbench Search now has the requested Toolbar, facet data panel, and result
table structure. Facet interaction stays entirely in memory after exact Search,
empty Search reads the index-time aggregate cache, Search selections persist,
panel visibility does not, and the shared component is ready for Shiori's
separate integration step.
