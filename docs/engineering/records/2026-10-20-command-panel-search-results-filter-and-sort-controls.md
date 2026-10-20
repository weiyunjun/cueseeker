# Implementation Record: Command Panel Search Results Filter And Sort Controls

- **Date**: 2026-10-20
- **Requirement**: `docs/human/requirements/20261020-UI-Command Panel Search Results Filter And Sort Controls.md`
- **Design References**:
  - `docs/human/design/ui/UI Layouts - Playback.md`
  - `docs/human/design/ui/UI Layouts - Workbench.md`
  - `docs/human/design/ui/UI Components - Controls.md`
  - `docs/human/design/ui/UI Components - Menus & Overlays.md`
  - `docs/human/design/ui/UI Application Rules.md`

## Summary of Changes

1. **Command Panel Secondary Header Adaptive Layout (`PlaybackCommandPanel.swift`)**:
   - Introduced `PlaybackCommandPanelHeaderLayoutGeometry` and `PlaybackCommandPanelSecondaryHeaderLayout` to place the Leading Back button, Centered single-line tail-truncated Title, and optional Trailing controls within the `58pt` header bar (`20pt` outer horizontal inset).
   - Kept the search query title centered by default; when horizontal space narrows against the trailing Filter and Sort buttons, the title maintains a minimum `--spacing-3` (`12pt`) gap from both the leading Back button and trailing controls, shifting into available space before truncating to a single line with tail ellipsis (`...`).
   - Preserved empty trailing content on `Recent Videos` and `Recent Excerpt Lists` secondary pages.

2. **Filter & Sort Controls and Popover Menu on Command Panel Search Results (`PlaybackCommandPanel.swift`)**:
   - Added the standard `WorkbenchButton` Filter (`funnel` icon, `Filter` title, selected facet count badge) and Sort (`funnelSimple` icon, current sort option label) controls separated by `--spacing-3` (`12pt`) on the trailing side of the `Search Results` secondary header.
   - Wired the Filter button to `CueFacetFilterDialogCenter` (`source: .search`) so the shared Filter Dialog opens above the Command Panel and returns focus to Command Panel Search Results on close/cancel/show.
   - Wired the Sort button to `SchemaWorkbenchSortMenuPopover` hosted in `MenuHostingView` (`PlaybackCommandPanelSortMenuSurfaceHost`) and registered with `MenuGateClientView` (`owner: .commandPanel`, `kind: .cardMenu`) so keyboard navigation (`↑`/`↓`, `Return`, `Esc`), outside-click dismissal, and scroll/hover modality work over the AppKit virtual reel without dismissing or navigating back the Command Panel.

3. **Bi-Directional State & Preview Synchronization (`SearchStore.swift`, `PlaybackStore.swift`, `AppCoordinator+Search.swift`, `AppCoordinator+PlaybackCommandPanel.swift`, `WorkbenchTestSearchView.swift`)**:
   - Published `searchFacetFilter` on `SearchStore` and synchronized `WorkbenchTestSearchView`'s filter state and table viewport/selection reset whenever filter or sort order changes from either surface.
   - Tagged `PlaybackStore.commandPanelSearchSource` with `.search(resultListGeneration:)` and cleared any held `.searchResults` page snapshot when Filter or Sort changes so the Command Panel Search Results preview updates immediately and resets selection to the top item (`ordinal 0`).

## Verification

- Added and verified unit tests in `PlaybackSearchOverlayTests` (`commandPanelSecondaryHeaderCentersShiftsAndTruncatesTitleAroundControls`, `commandPanelSearchSynchronizesFilterAndSortWithWorkbenchAndResetsSelection`) alongside existing Command Panel search tests.
