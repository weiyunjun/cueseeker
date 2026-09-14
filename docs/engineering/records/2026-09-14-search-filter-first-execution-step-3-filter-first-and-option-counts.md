# Search Filter-First Execution — Step 3: Filter-First Results And Option Counts

## Human-Owned Source

- `docs/human/requirements/20260914-Feature-Search Filter-First Execution And Ordered First Page.md` (sections 2.2, 3.1, 4, 5)
- `docs/human/design/UI Design System.md` (Filter Menu, Filter Option Menu Item)

## Starting Point (commit `9dcbd6b3`, after Step 2)

The Filter Menu selection never reached the database. Every search scanned all hits, the first page showed unfiltered rows, and only when the exact scan had finished did the store project the filter over the in-memory facet snapshot, swapping the table to a second, filtered id list and hydrating it in 1,000-row pages. The menu refused any change while that snapshot was still calculating.

## Implementation

- `SearchDatabase.searchPage` and its entry points take a `facetFilter`. Every line match still contributes its facet values to the snapshot, but only matches that pass the filter become results: first page, progress increments, exact total, ordered cue ids and file summaries are all filtered. The scan is still a single pass; the filter check reuses the facet values it already computes.
- `SearchStore` no longer projects. The facet filter is part of the search: `updateSearchFacetFilter` stores it and reports whether it changed; `AppCoordinator.applySearchFacetFilter` then searches the current query again without debounce, so the first page is already filtered and nothing replaces it later. The facet snapshot is kept for the query and scope across filter-only restarts, so the option counts update at once; a new query or scope drops it, and the menu shows calculating until the new scan completes.
- The option counts (`searchFacetDistribution`) come from the snapshot under the current filter through the existing disjunctive rule: each card ignores its own selection and applies the other three. They are recomputed when the filter changes or a snapshot arrives; for `の` that is a few milliseconds over 77,145 entries.
- Removed the projection machinery: the facet table projection source, projection task and generation, the filtered cue id list and count, `projectedSearchResults`, and the `usesFacetProjection` playlist flag. The Command Panel, playlist, URL scheme and copy boundary read the filtered `searchResults` and `searchResultCueIDs` directly.
- The Filter Menu and the Enter key no longer refuse a toggle while counts are calculating; a toggle during a scan starts the next search and the old one is superseded by the existing generation checks.

## Verification

- `swift test --filter "SearchDatabaseTests|SearchStoreTests|URLSchemeSearchRoutingTests|PlaybackSearchOverlayTests|PlaybackSubtitleFocusKeyboardActionTests|PlaybackPlaylistSourceTests|PlaybackSegmentCompletionTests|CueFacetCountCacheTests|TableSandboxRowModelStoreTests|CueGroupRefreshScopeIntegrationTests"`: 200 tests, the only two failures are the pre-existing Excerpt scroll-anchor tests. New `searchPageAppliesTheFacetFilterToResultsWhileTheSnapshotKeepsEveryMatch` covers the database side; the store tests now assert the counts and the snapshot lifetime instead of a projection; playlist, overlay and URL scheme tests commit already-filtered pages.
- Full `swift test`: 1226 tests, 30 issues in 15 tests, none in Search execution: the same native playback, Debug E2E scene, Library folder removal and Excerpt/refresh-scope tests as after Step 2, plus `libraryFolderRemovalAndIndexingRejectEachOther`; every one of them appears in the failure lists this machine recorded on 2026-09-12 before that day's unrelated change. The two refresh-scope tests that mention Search facets assert global view-body counters that already failed then and do not use the removed projection API.
- SearchBench on the migrated copy, unchanged as expected with no filter: `の` 10.0 / 1067 ms, `今` 4.2 / 142 ms, `大丈夫` 4.7 / 32 ms hot medians (visible window / exact).
- App level without a filter, same E2E procedure, cold then hot: `大丈夫` 217 / 101 → 797 / 527 ms; `今` 163 / 54 → 1570 / 1354 ms; `の` 182 / 52 → 4389 / 3415 ms, hot 151 / 41 → 3401 / 2101 ms (first page e2e / db → completed e2e / db). Same as Step 2 within run-to-run variance.
- App level with a filter, driven through the E2E controller: with `の` showing 77,145 results, clicking the Filter trigger opened the menu with Duration `<1s` 1596, `1–2.999s` 40195, `3–4.999s` 28724, `≥5s` 6630 (sum 77,145). Clicking `<1s` searched again: first page 206 / 84 ms, completed 2078 / 1819 ms with exactly 1,596 results; the table showed only short cues from the first row on and no row was replaced later; the Duration card kept all four counts while Character became 1516 / 61 / 19 / 0 and Language English 63, Japanese 1280; the menu stayed open; no main-thread gap of 250 ms or more during that run. Clicking `<1s` again restored 77,145 results (first page 69 ms, completed 3299 / 2086 ms). Captures `step3-filter-menu-open.png`, `step3-filter-under1s.png`, `step3-filter-cleared.png`.
- The remaining long main-thread gap (about 1.0 s) still sits at the moment an unfiltered `の` completes, when the table takes the 77,145-row reference list. It is unchanged by this step and is not caused by the filter path.

## Outcome

Matched expectations: the first page is the filtered result, later rows only extend it, the unchecked options get their counts from the same scan, and the projection code is gone.
