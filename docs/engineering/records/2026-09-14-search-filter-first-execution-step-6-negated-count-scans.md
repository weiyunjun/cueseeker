# Search Filter-First Execution — Step 6: Counting The Unchecked Options From The Remaining Rows Only

## Human-Owned Source

- `docs/human/requirements/20260914-Feature-Search Filter-First Execution And Ordered First Page.md` (sections 4.1, 4.2, 4.3)

## Starting Point (commit `f02b6775`, after Step 5)

The owner asked why, with `English` checked, every Filter Menu option still read "calculating" after the result count was already visible, and why the second pass scanned every hit instead of only the remaining rows. Reading the code confirmed two deviations from requirement section 4 that Step 4 had introduced on its own: the filtered scan threw the facet values of its own rows away and the second pass was one unfiltered scan of every hit, kept across selection changes so its snapshot could serve any later selection. That made every count wait for the full scan, and a changed selection did not restart the count calculation as 4.3 requires. The owner rejected the reuse: the second pass must read only what the unchecked options need, and a changed selection starts over.

## Implementation

- The filtered scan keeps the facet values of the rows it accepts, so a filtered page's snapshot holds exactly the result's rows. Every card without a selection and every checked option is counted from those rows the moment the filtered result completes.
- For each card with a selection, one scan of the same query runs with that card negated: the other cards' conditions still apply in SQL and in the Swift check, the card's own buckets, language set or watch states become `NOT (...)`, `NOT EXISTS` or `NOT IN`. That reads only the rows the card's unchecked options are counted from. The rows join the result's snapshot as each scan lands, and the usual rule (each card ignores its own selection and applies the other three) produces the same numbers as one unfiltered scan; the database test checks that equality for one and for two checked cards and for the watch state.
- The Filter Menu marks calculating per option: every option while the result's rows do not exist yet, afterwards only the unchecked options of a card whose scan is still running (`searchFacetCountsPendingKinds`).
- The count scans belong to the result list. A new selection, query or scope cancels them and drops the snapshot, and the next search brings its own rows and starts its own scans; nothing from the old result is published. Filter-only restarts no longer keep anything.

## Verification

- `swift test --filter "SearchDatabaseTests|SearchStoreTests|CueFacetCountCacheTests|URLSchemeSearchRoutingTests|PlaybackSearchOverlayTests|PlaybackPlaylistSourceTests|SettingsStoreSearchTests|WorkbenchPageScrollbarTests|CueGroupRefreshScopeIntegrationTests|PlaybackSubtitleFocusKeyboardActionTests"`: 163 tests, 5 issues in the same 3 `CueGroupRefreshScopeIntegrationTests` tests that failed identically after Steps 3, 4 and 5; everything else passes. The store tests now check that a filtered result counts its own cards at once with only the checked card pending, that a scan's rows complete the counts, that a selection change drops the counts while the rows stay, and the real-database test checks the Duration card's unchecked options arrive from the second scan while the result stays at 50.
- Full `swift test`: 1229 tests, 26 issues in 14 tests, all in the pre-existing environment-sensitive set (native playback, Debug E2E scene and width, Library folder removal, Excerpt scroll anchor and refresh-scope counters); one of Step 5's 15 failing tests passed this time and nothing new failed.
- SearchBench on the Step 5 database copy (schema 49, unfiltered path): `の` 10.0 / 1139 ms, `今` 3.9 / 137 ms, `大丈夫` 3.9 / 26.6 ms hot medians (visible window / exact), the same as after Step 5 (10.5 / 1192, 4.1 / 150, 4.1 / 27.9): an unfiltered scan already kept every row's facet values, so nothing changed on that path.
- App level through the E2E controller on the live library (schema 49, no indexing since Step 5), first page e2e / db → filtered result complete e2e / db → unchecked-option counts complete e2e / db:

| Selection | Query | Result | Timings |
| --- | --- | --- | --- |
| `English` | `大丈夫` | 27 | complete 58 / 20 → counts 174 / 49 |
| `English` | `今` | 518 | 201 / 85 → 1139 / 904 → counts 1771 / 607 |
| `English` | `の`, cold | 938 | 237 / 124 → 1759 / 1491 → counts 4486 / 2638 |
| `English` | `の`, hot repeat | 938 | 177 / 63 → 842 / 645 → counts 3060 / 2132 |
| `English` + `31+` clicked while the counts above were running | `の` | 22 | complete 529 / 528 → counts 1799 / 1207; the earlier scan never published |
| `Japanese` | `の` | 76,097 | 161 / 33 → 3387 / 2128 → counts 5045 / 1482 |
| none | `の` | 77,145 | 70 / 69 → 3342 / 2173, no second scan (Step 5: 77 / 32 → 3423 / 2200) |

- Captures: `step6-no-english-menu-calculating.png` shows, right after the filtered `の` completed, every Duration and Character count and `English 938` in place with only `Japanese` reading "Calculating"; `step6-no-english-menu-counts.png` shows `Japanese 76097` three seconds later. `step6-click-during-counts-1/2.png` show the click on `31+` during the scan emptying the counts and the new result of 22 arriving with its own counts. `step6-japanese-calculating/counts.png` show the mirror case (only `English` calculating, then 938). The selection was left empty as found (`step6-final.png`).
- The `English` filtered result of `の` completes in the same time as after Step 5 (842 vs 914 ms e2e); the first-page numbers are unchanged. Main-thread stalls of 250 ms or more appeared only during the three scans that complete with 76–77k rows (the known completion gap), none during the filtered runs.
- The `Japanese` case shows the limit of "only the remaining rows": the negated scan accepts 1,048 rows but still takes 1.5 s instead of 2.1 s, because it still hydrates every hit's candidate row before the line condition prunes; only the line reads and the matching shrink with the remaining rows.

## Outcome

Matched the requirement as the owner restated it: with `English` checked the menu shows every count except `Japanese` as soon as the 938 results are in, the second pass reads only the rows the unchecked options need, and a click on another option while it runs starts a fresh search and count. Remaining known items: the completion gap of about 1 s on 76k-row results, and the candidate hydration cost of a negated scan that accepts few rows.
