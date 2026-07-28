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
- Replaced the fixed four-card horizontal scroller with one adaptive SwiftUI
  `Layout`. It derives 2, 3, or more columns from the available width and the
  200-point minimum card width, accepts any card count, keeps incomplete last
  rows on the same column width, and equalizes natural card heights per row.
- Removed fixed card and panel heights. The panel now wraps vertically without
  horizontal scrolling and reports only the height required by its card rows.
- Aligned title icons and option checkboxes on the same 16-point leading
  control column. Applied the documented control/body/caption typography,
  secondary/muted colors, circular checkbox states, and Calculating count
  presentation through existing Workbench tokens.
- Restored the original SF Symbol checkbox instead of maintaining a custom
  circle, stroke, and checkmark renderer. The checked symbol now changes only
  to the required muted color and no longer gains an extra outline.
- Split Calculating interaction suppression from the visual Disabled state.
  Calculating counts still block option changes while preserving the current
  checked or unchecked appearance; Select mode disables the options with the
  global Disabled colors and cannot exit Select through a facet click.
- Reused the existing `StaticButtonStyle` for facet option rows so clicking a
  checkbox changes only its selection state and does not add a Button pressed
  effect.
- Applied Select's Disabled colors to the card title icon and title as well as
  every option, while leaving the card surface and border unchanged.
- Kept Filter interaction scoped to the existing in-memory table projection,
  and made Search Playlist installation and refresh consume that current
  projection instead of falling back to the unfiltered exact result set.
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
- Kept the persisted Search facet value outside `SettingsStore`'s global
  `objectWillChange` stream and moved the mounted selection into Search-local
  view state. A checkbox change therefore does not invalidate App Root,
  Sidebar, Settings, Shiori, or other unrelated surfaces.
- Scoped `TableSandboxRowModelStore` observation to the table subtree. Later
  progressive projection batches update only the table snapshot and native
  table instead of rebuilding the Search toolbar and facet panel.
- Removed the Primary Search Language and Search Scope controls from Settings.
  Workbench and Command Panel searches now use the complete language and watch
  domain; Command Panel does not receive the Workbench facet selection.
- Kept the old Filter Editor implementation and filter-only route available to
  Shiori and Context until their planned migration and cleanup steps.
- Extended exact text-copy hydration to accept the filtered ordered Cue IDs, so
  Select, copy, and export retain a complete filtered boundary.

## Verification

- `swift test --filter SettingsStoreSearchTests` passed all 9 tests, including
  default-all selection, persistence restoration, forward compatibility,
  2/3/arbitrary-column calculation, and proof that facet persistence emits no
  global Settings invalidation.
- `swift test --filter SearchStoreTests` passed all 30 tests, including panel
  default visibility, progressive facet projection, exact filtered count,
  Watch Status distribution refresh, context, and table hydration.
- `swift test --filter CueFacet` passed all 13 facet logic, cache, exact
  snapshot, and paged projection tests.
- `swift test --filter PlaybackSearchOverlayTests` passed all 4 Command Panel
  Search tests; `swift test --filter URLSchemeSearchRoutingTests` passed all 7
  URL Search tests.
- `swift test --filter PlaybackPlaylist` passed all 14 Playlist tests,
  including the regression test proving that Playlist order, count, and
  selected ordinal come from the active facet projection. `swift test --filter
  facetFilter` also passed both projection tests.
- `swift test --filter CueGroupRefreshScopeIntegrationTests` passed all 16
  mounted tests. The added probes verify that facet selection does not rebuild
  global or inactive surfaces and progressive batches rebuild only the Search
  table snapshot/native table, not the Search surface.
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

Workbench Search now has the requested Toolbar, responsive facet data panel,
and result table structure. Facet interaction stays entirely in memory after
exact Search, empty Search reads the index-time aggregate cache, Search
selections persist without global invalidation, later projection batches stay
inside the table subtree, panel visibility does not persist, and the shared
component is ready for Shiori's separate integration step.
