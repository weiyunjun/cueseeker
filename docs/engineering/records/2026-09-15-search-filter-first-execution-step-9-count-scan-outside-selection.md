# Search Filter-First Execution — Step 9: The Count Scan Reads Every Match Outside The Selection

## Human-Owned Source

- `docs/human/requirements/20260914-Feature-Search Filter-First Execution And Ordered First Page.md` (sections 4.1, 4.2, 4.3, 4.4, 5)

## Starting Point (commit `a46adf03`, after Step 8)

Step 8 had made requirement 4.4 conditional: the count pass negated one checked card at a time, so after a search with two or more checked cards the rows failing two of them were never read, and the Store answered a later selection change with a new search instead of a projection. The owner rejected that: section 4.4 is unconditional, and the count pass was always meant to read "the remaining rows", which for a selection means every match outside it. The AI had proposed the restriction in review without saying that it narrowed the requirement.

## Implementation

- The count pass is one scan of the same query with the filter negated: it accepts every match that fails the selection, so its rows joined with the filtered result are every match of the query. The database's `searchPage` takes `facetFilterNegated` instead of a card to negate; the Swift check is the plain selection check inverted, and `CueFacetFilter.matches` loses its per-card negation.
- In SQL the line conditions become `NOT (duration buckets AND length buckets AND language)` while a required language (the legacy language filter) stays a positive condition. A file that fails a checked watch state contributes every matching line: with a watch state checked alone the candidate query keeps pruning files with `NOT IN`; with line cards checked as well it stops pruning by watch state and such files' groups are read whole, the other groups through the negated line conditions.
- The Store runs one scan per filtered result; every checked card's unchecked options read "calculating" until it lands, then the joined snapshot is sorted into display order and is complete after any search. Step 8's coverage flag is removed and the per-card append becomes a single append.

## Verification

- Database test: the negated scan for one card, two cards (seven rows outside, including the three that fail both cards), a watch state alone and a watch state with a duration (the whole unwatched file plus the long lines of the watched one) each join with the filtered rows into exactly the unfiltered scan's rows in its order, with the counts under the selection equal to the unfiltered snapshot's. The language test negates the language selection the same way.
- Store tests: a two-card search whose single count scan lands rows including one that fails both cards is complete, keeps its own counts right, and projects the cleared selection over all four rows; the real-database test runs a two-card search, sees the snapshot grow to all 150 matches and projects the cleared selection to 150 rows with the first 100 read by cue ID. The single-card projection test is unchanged apart from the call.
- `swift test --filter "SearchDatabaseTests|SearchStoreTests|CueFacetCountCacheTests"`: 79 tests pass. Full `swift test`: 1231 tests, 29 issues in 16 tests: the 14 pre-existing environment-sensitive tests (native playback, Debug E2E scene and width, Library folder removal, Excerpt scroll anchor and refresh-scope counters), `failedLibraryFolderRemovalPreservesFolderAndPresentationState` (the same issue line as the folder-removal test in that set; all three folder-removal tests pass when run alone) and `sharedPersistenceMigrationCopiesLegacyValuesWithoutOverwritingSharedValues`, which again read the live shared defaults (`workbenchPanelMode` = `search`). Nothing in Search failed.
- SearchBench on the Step 5 database copy (unfiltered path, unchanged): `の` 9.9 / 1134 ms, `今` 3.9 / 140 ms, `大丈夫` 4.0 / 26.7 ms hot medians (visible window / exact), the same as after Step 7 (10.0 / 1142, 3.9 / 140, 3.8 / 27.5).
- App level through the E2E controller on the live library (schema 49, no indexing since Step 5), selection empty at launch, e2e / db ms:

| Step | Result | Timing |
| --- | --- | --- |
| `の`, no selection, cold after the test suites | 77,145 | first page 188 / 75 → complete 5858 / 5016 |
| `の`, no selection, hot | 77,145 | 151 / 41 → 3434 / 2189 (Step 6: 70 / 69 → 3342 / 2173) |
| check `English`, then `31+` (projections) | 938, 22 | rows on screen 71 / 4 and 63 / 2 |
| `の` searched with `English` + `31+` | 22 | complete 662 / 552 → counts 3071 / 2211 (Step 8: 673 / 557 → 1976 / 1272) |
| uncheck `English` (now a projection) | 2,766 | rows on screen 65 / 3 (Step 8: a search, 748 / 606 → counts 3128 / 2158) |
| uncheck `31+` (projection) | 77,145 | rows on screen 99 / 2 |
| the same two-card flow, hot repeat | 22 → 2,766 → 77,145 | search 654 / 544 → counts 3048 / 2199; projections 65 / 4 and 103 / 3 |
| `の` searched with `English` alone | 938 | 170 / 63 → 850 / 660 → counts 3209 / 2177 (Step 6: 177 / 63 → 842 / 645 → 3060 / 2132) |
| uncheck `English` (projection) | 77,145 | rows on screen 100 / 2 |

- Captures `step9-two-card-search-counts.png` (22 results; Duration 0 / 2 / 15 / 5, Character 431 / 378 / 107 / 22, English 22, Japanese 2753, nothing calculating), `step9-after-uncheck-english.png` (2,766 results; Character 15,669 / 39,980 / 18,730 / 2,766, the numbers Step 8 had shown wrong; English 22, Japanese 2753), `step9-after-uncheck-31plus.png` and `step9-single-card-search-counts.png` (938 results, Japanese 76,097) match the unfiltered counts of `step9-menu-initial.png`. The selection was left empty (`step9-final.png`).
- Main-thread probes (`log stream`, perf subsystem) during the two-card hot repeat and the single-card flow: none. The two stalls recorded (0.47 s and 1.05 s) sit at the completion of the unfiltered `の` hot run, the known gap when the table takes 77,145 row references.

## Outcome

Matched requirement 4.4 as written: after any search, once the counts are complete, a selection change is answered from memory. The cost is confined to selections with two or more checked cards, whose count pass now reads every match outside the selection (`の` with `English` + `31+`: about 3.0 s in the background instead of 2.0 s); a single-card or unfiltered search is unchanged.
