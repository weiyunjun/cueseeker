# Search Filter-First Execution — Step 7: A Selection Change After Complete Counts Is Answered From Memory

## Human-Owned Source

- `docs/human/requirements/20260914-Feature-Search Filter-First Execution And Ordered First Page.md` (section 4.4, added by the owner for this step; sections 4.1–4.3 unchanged)

## Starting Point (commit `35157012`, after Step 6)

The owner pointed out a regression: before Step 4, changing the Filter Menu selection after a search had completed showed the new rows and counts at once, because the single unfiltered scan left every match with its facet values in memory, already in display order, and a selection change was a projection over that. Steps 4–6 made every selection change a new database search, including after every count was complete, when the memory holds the same data as the old single scan. Requirement 4.4 now states the rule: once every count is complete, a changed selection uses the existing result for the new rows and counts and does not search.

## Implementation

- Every row a scan accepts gets a display-order key: the file's display rank, the cue group's time position (the FTS rowid sequence) and the line's position inside its group. The keys travel with the facet snapshot, and when the last count scan of a filtered result lands, the joined rows are sorted by key once, so the snapshot holds every match of the query in Search order. An unfiltered scan's snapshot is already in that order and is left alone.
- With every count complete, a changed selection is projected: the result becomes the snapshot's matching rows in display order with the counts by the usual rule, the result list generation advances, and only the first page's row contents are read from the database by cue ID. Later pages load as before. The Store logs `search_facet_projection_rows_loaded` with the time from the click to the rows being on screen.
- While a count scan is still running, or when no snapshot exists, the selection change still starts a new search and new counts, as sections 4.3 and 3.1 require.
- The file summaries of the last database search are kept unchanged by a projection; nothing on the Search page reads them, and their remaining readers (a playback display-title fallback behind a better source, and the folder-removal cleanup) were the same under the pre-Step-4 projection.

## Verification

- The order-key check in the database test caught a real defect before the commit: the key first used the line's index among the *matching* lines, so the two lines of one ASS group got the same key when each came from a different scan and sorted in the wrong order. The key now uses the line's fixed position inside its group; the test asserts that the joined rows of the filtered and negated scans, sorted, are exactly the unfiltered scan's rows in the unfiltered scan's order for one checked card; for two checked cards it only checks the order of the rows that were read, because the rows failing both cards are read by no scan (see Step 8, which stops the projection in that case).
- Store tests: a new test checks that a selection change while a count scan is pending is refused, that after the last scan the snapshot is in display order, that clearing and narrowing the selection are projected with the right rows, total, status, generation and counts, and that the same selection again is no change; the real-database test now continues past the completed counts, projects the cleared selection (150 rows, the first 100 read by cue ID in time order) and a duration selection (100 rows) without any scan.
- `swift test --filter "SearchDatabaseTests|SearchStoreTests|CueFacetCountCacheTests|URLSchemeSearchRoutingTests|PlaybackSearchOverlayTests|PlaybackPlaylistSourceTests|ExcerptStoreTests|ExcerptDatabaseTests|PlaybackSubtitleFocusKeyboardActionTests"`: 147 tests pass. Full `swift test`: 1230 tests, 28 issues in 14 tests, all in the pre-existing environment-sensitive set (native playback, Debug E2E scene and width, Library folder removal, Excerpt scroll anchor and refresh-scope counters); nothing new failed.
- SearchBench on the Step 5 database copy (unfiltered path, now also recording one order key per accepted row): `の` 10.0 / 1142 ms, `今` 3.9 / 140 ms, `大丈夫` 3.8 / 27.5 ms hot medians (visible window / exact), the same as after Step 6 (10.0 / 1139, 3.9 / 137, 3.9 / 26.6).
- App level through the E2E controller on the live library, `の` with `English` checked from the persisted settings, cold after the test suites: first page 341 / 223 ms, filtered result 3060 / 2681 ms, counts 6036 / 2787 ms (e2e / db). Then three selection changes with every count complete, measured from the click to the first page's rows on screen (`search_facet_projection_rows_loaded`, e2e / row-content read by cue ID):

| Change | Result | Rows on screen | Same change in Step 6 (a new search) |
| --- | --- | --- | --- |
| add `31+` | 22 | 56 / 2 ms | 529 ms |
| remove `English` | 2,766 | 66 / 4 ms | — |
| remove `31+` | 77,145 | 98 / 3 ms | 3342 ms |

- Captures `step7-proj-english-31plus.png`, `step7-proj-31plus-only.png` and `step7-proj-unfiltered.png` show each result with its count and every option count in place and nothing calculating; the 22-row list starts with the same rows in the same order as Step 6's database search for that selection (Ave Mujica - 01, then NieR Automata Ver1.1a 01–09). No main-thread stall probe fired during the flow, including the one-time sort of the 77,145-row snapshot when the counts completed. The selection was left empty (`step7-final.png`).

## Outcome

Matched requirement 4.4: after the counts are complete, a selection change shows its rows and counts in well under 0.1 s instead of 0.5–3.4 s, while a change during calculation still starts over. The E2E run also exposed two harness pitfalls, recorded for later work: a leftover FIFO reader from a quit App swallows the next launch's first command, and BSD `seq 1 0` counts down.
