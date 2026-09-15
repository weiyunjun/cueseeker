# Search Single Full Scan — Step 1: One Scan For The Result And Every Count

## Human-Owned Source

- `docs/human/requirements/20260915-Feature-Search Single Full Scan And Show Disabled Until Search Completes.md` (sections 1, 2, 4)
- `docs/human/design/UI Design System.md` (Filter Dialog Layout, Search / Excerpt Table Layout; no change)

## Baseline (commit `50d3c14c`, before any code change)

App level, Debug E2E controller, live library (77,145 matches for `の`), window 1221 × 798 (1445 spans two displays here), query pasted with Cmd+V, `logs/search-e2e/search-e2e-2026-09-15.jsonl`, stall probes from `log stream`. Hot runs search `abc` first.

| Run | First page e2e / db | Filtered result complete e2e / db | Every count complete e2e / db | Main-thread stalls |
| --- | --- | --- | --- | --- |
| No filter, cold | 198 / 81 ms | 5627 / 4918 ms | same | 410 ms at completion |
| No filter, hot | 166 / 52 ms | 2762 / 2116 ms | same | none |
| Character `11–20`, hot | 165 / 51 ms | 2032 / 1605 ms | 3760 / 1485 ms (second scan) | 262 ms |
| Character `11–20`, hot repeat | 172 / 54 ms | 2050 / 1618 ms | 3791 / 1498 ms (second scan) | 263 ms |

`11–20` leaves 39,980 results.

## Implementation

- `SearchDatabase.searchPage` no longer pushes the facet filter into the row reads. Every match of the query goes into the page's facet snapshot, and only the matches inside the selection become results, file summaries, cue ids and progress rows. The negated scan (`facetFilterNegated`), the SQL duration and length buckets, the candidate watch-state condition and the whole-group reads for it are removed; the line query keeps only the legacy required-language condition (`languageMatchingLineIDs`).
- An exact scan's first candidate batch is a visible window's (twice the page size, at least 100), later batches stay at 5,000, so the first page is found as early as a visible window finds it.
- `SearchStore.startSearch` runs one scan at user-initiated priority. Its progress sink collects rows on the scan thread and, once 100 rows are known, yields the first page through an `AsyncStream`; the search task installs it as before (`search_visible_page_loaded`), then installs the rest with the completed page (`search_status_completed`). A result under 100 rows is installed once. Loading a later page (`appending`) still uses the visible window.
- Since the snapshot now holds every match in display order, the second scan and what only served it are removed: `startExactCompletion`, `startFacetCounts`, their tasks, `searchFacetCountsPendingKinds`, `appendSearchFacetCounts`, `isSearchFacetSnapshotComplete`, `CueFacetFilter.selectedKinds`, `CueFacetSnapshot.orderKeys` / `appending` / `sortedByDisplayOrder`, `SearchFTSRows.displayOrderKey`, and the per-card pending state of the Filter dialog counts (`pendingKinds`, `isUnknown`). The dialog shows every count as unknown until the search completes, then all of them.
- A changed selection is projected whenever a snapshot exists, that is once the search has completed; before that Show still searches again (unchanged until Step 2).

Files:

- `apps/macos-native/Sources/CueSeekerCore/SearchDatabase.swift`
- `apps/macos-native/Sources/CueSeekerCore/CueFacetFilter.swift`
- `apps/macos-native/Sources/CueSeekerCore/SearchFTSRows.swift`
- `apps/macos-native/Sources/CueSeekerApp/Search/SearchStore.swift`
- `apps/macos-native/Sources/CueSeekerApp/Search/SearchStore+Execution.swift`
- `apps/macos-native/Sources/CueSeekerApp/Shared/WorkbenchSchemaSearch/CueFacetFilterPanel.swift`
- Tests: `SearchDatabaseTests`, `SearchStoreTests`, `SettingsStoreSearchTests`, `URLSchemeSearchRoutingTests`, `PlaybackSubtitleFocusKeyboardActionTests`
- `docs/changelog.md`

## Verification

- Database tests: a filtered page carries the same snapshot as the unfiltered scan and its cue ids are the snapshot's rows under the selection (two cards, a watch state, a watch state with a line card, a language); the progress test now expects a first batch of 100 candidates for a page of 50.
- Store tests: a filtered result counts every option at once; a selection is projected once the search has completed and not before; the real-database test completes 50 results with a 150-row snapshot in one scan and projects both ways; new `searchHandsTheTableItsFirstPageAndThenTheRestFromOneScan` checks that 250 matches reach the table as exactly two updates, 100 rows then 250, with ranks 0–249.
- `swift test --filter "SearchDatabaseTests|SearchStoreTests|SettingsStoreSearchTests|URLSchemeSearchRoutingTests|PlaybackSubtitleFocusKeyboardActionTests|CueFacetCountCacheTests|PlaybackSearchOverlayTests|PlaybackPlaylistSourceTests"`: 148 tests pass.
- Full `swift test`: 1231 tests, 31 issues in 16 tests: native playback (6), Debug E2E scene and width (2), Excerpt scroll anchor (2), Library folder removal (2), `playbackPlayerKeepsAutoPauseBoundaryAcrossUserSeeks`, `progressiveSearchProjectionRefreshesOnlyMountedTable`, `searchFacetSelectionDoesNotRefreshGlobalOrInactiveSurfaces` and `playbackExcerptCopiesSettledPrimaryCueAsMarkdownLink`. Run alone, the two Search tests pass; the Excerpt copy test fails on its expected English feedback text because the system language is Chinese. The rest are the environment-sensitive set of the earlier records.
- App level, same procedure as the baseline:

| Run | First page e2e / db | Result and every count complete e2e / db | Main-thread stalls |
| --- | --- | --- | --- |
| Character `11–20`, cold | 197 / 77 ms | 5315 / 4954 ms | none logged |
| Character `11–20`, hot | 159 / 49 ms | 2420 / 2049 ms (was 3760) | 260 ms at completion |
| Character `11–20`, hot repeat | 166 / 52 ms | 2404 / 2035 ms (was 3791) | 261 ms at completion |
| No filter, hot | 155 / 46 ms | 2685 / 2119 ms (was 2762) | 441 ms at completion |
| No filter, hot repeat | 143 / 35 ms | 2701 / 2118 ms | 381 ms at completion |

- The unfiltered completion stall (381–441 ms, while installing 77,145 rows took 266–278 ms against 269 ms before) was not logged in the single hot baseline run, but was 410 ms in the cold baseline run and 476 ms in the previous record's warm run; it is left as observed, not attributed to this step.

- With `11–20` checked the dialog opened after completion showed every count with no placeholder, the same numbers as the baseline (Duration 61 / 25,207 / 12,091 / 2,621, Character 15,669 / 39,980 / 18,730 / 2,766). Reset showed the unfiltered counts at once (77,145); Show ran no search and installed 77,145 rows in 1,058 ms (`search_facet_projection_rows_loaded`).

## Outcome

Matched the requirement's targets: with a filter, every count is complete after about 2.4 s instead of 3.8 s; unfiltered completion is not slower (2.69 s against 2.76 s); the first page is not slower (155–166 ms against 165–172 ms). The filtered result itself now completes together with the counts, about 0.4 s later than the baseline's filtered result, which is the accepted cost of reading every match. The saved Search selection was left empty.
