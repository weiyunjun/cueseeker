# Search Filter-First Execution — Step 2: Progress Increments

## Human-Owned Source

- `docs/human/requirements/20260914-Feature-Search Filter-First Execution And Ordered First Page.md` (section 3.2: the exact scan publishes only what is new; section 5)

## Starting Point (commit `281a8020`, after Step 1)

Every exact-scan progress snapshot carried all results accepted so far plus the full cue id list, and the store re-installed all of them into the content store, rebuilt the rank map and republished the table references on every tick; the final page carried everything again. A 200 ms throttle dropped snapshots that came too fast. For `の` (77,145 results, 16 batches) that was up to 15 main-thread installs of a growing list, and the completion of `の` showed main-thread gaps up to 1.97 s.

## Implementation

- `SubtitleSearchProgressSnapshot` now carries only the results and cue ids accepted since the previous snapshot, with `resultOffset` giving the rank of the first one. `SubtitleSearchPage` gained `renderableResultsOffset`; with a progress sink the final page's `renderableResults` is only the tail after the last snapshot, while `cueIDs` stays complete.
- `SearchDatabase.searchPage` keeps a pending list that is cleared after each snapshot; the never-used `progressResultLimit` parameter is gone.
- `SearchStore` merges increments: rows already loaded at the same ranks (the visible page is the same order as the exact scan) are kept when their cue ids match and only the rest is appended; a snapshot that starts at rank 0 with different rows replaces them; a snapshot that would leave a gap keeps the rows and applies only its counts. The 200 ms drop throttle is removed, because dropping an increment would lose rows; ticks are bounded by the scan's 5,000-candidate batches.

## Verification

- `swift test --filter "SearchDatabaseTests|SearchStoreTests"`: 70 tests pass. `searchPageEmitsExactProgressCountSnapshotsBeforeFinalExactCounts` now asserts that the concatenated increments are the ordered 5,000 rows with ranks 0..4999 and that the final page carries the 100-row tail at offset 5,000 with the full cue id list. New `searchCountProgressAppendsIncrementsAfterTheLoadedPrefix` covers overlap, append, gap and the final tail merge.
- Full `swift test`: 1225 tests, 24 issues in 13 tests, none in Search: native playback media timeline and presentation transitions, Debug E2E window scene and width, Library folder removal, and the Excerpt table scroll-anchor and refresh-scope tests. Every one of them is on the failure list this machine recorded on 2026-09-12 before that day's unrelated change, so they are pre-existing environment-sensitive failures, not regressions of this step.
- SearchBench on the migrated copy (no progress sink, so unchanged as expected): `の` 9.7 / 1065 ms, `今` 4.2 / 144 ms, `大丈夫` 4.8 / 32.7 ms hot medians (visible window / exact).
- App level, same E2E procedure. First pass right after launch (cold file cache), second pass warm:

| Query | First page e2e / db | Completed e2e / db | Step 1 for comparison (completed e2e / db) |
| --- | --- | --- | --- |
| `大丈夫` cold / warm | 235 / 107 ms, 211 / 10 ms | 809 / 531 ms, 300 / 64 ms | 412 / 187 |
| `今` cold / warm | 162 / 51 ms, 121 / 10 ms | 1592 / 1382 ms, 431 / 259 ms | 803 / 594 |
| `の` cold / warm | 180 / 51 ms, 179 / 38 ms | 4285 / 3367 ms, 3355 / 2083 ms | 4727 / 2832 (cold), 4553 / 2291 (hot) |

- Warm `の`: the gap between completion and database time fell from about 2.3 s to about 1.3 s; main-thread stalls during the scan are now 260–560 ms instead of up to 1.5 s. The one remaining long stall (about 1.0 s) sits at completion, where the facet projection is rebuilt and the table reloads all 77,145 references; that belongs to Steps 3 and 4, which change what the projection has to do.
- The cold first pass is slower than Step 1's app run because that run came right after the schema migration had just touched every FTS page; the warm pass is the like-for-like comparison. Result totals and file counts unchanged in every run.

## Outcome

Matched expectations: progress ticks publish only new rows and the store appends them. Remaining gap to the requirement: filters still apply after the scan (Steps 3 and 4).
