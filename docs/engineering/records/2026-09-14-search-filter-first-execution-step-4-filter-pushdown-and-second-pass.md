# Search Filter-First Execution — Step 4: Filter Pushdown And The Second Pass For Counts

## Human-Owned Source

- `docs/human/requirements/20260914-Feature-Search Filter-First Execution And Ordered First Page.md` (sections 3.1, 4.1, 4.2, 5)

## Starting Point (commit `77e2a0f4`, after Step 3)

Owner's report: with Character `31+` checked and the App restarted, searching `の` still took over 2 s before the result count appeared, while an unfiltered search took a little over 3 s. Reading the code confirmed the cause: Step 3 evaluated the filter in Swift after loading every line of every hit so that the same pass could also collect the facet values for the unchecked options. A filter therefore saved only result building and publishing, not the row reads and matching, so the database time stayed about 2 s with or without a filter. That is not what requirement section 4.1 asks for: the filtered result first, the counts for the unchecked options afterwards.

## Implementation

- With a checked filter, `SearchDatabase.searchPage` pushes it into the row reads. Duration and character length become SQL conditions on the cue-line query (`end_ms - start_ms` buckets and `LENGTH(content)` buckets, the same edges as the Swift facets), so only lines in the checked buckets come back and only their groups are read for context; the watch state becomes a condition on the candidate query, so whole files are skipped. The Swift facet check still runs on every returned line, so the SQL only prunes and the semantics stay those of the counts. Language is not pushed into SQL; its display rule lives in Swift, so a language-only filter still reads every line.
- A filtered page carries no facet snapshot. When a filtered search completes, `SearchStore` starts the second pass: the same query and scope without a filter at utility priority, whose only product is the snapshot for the option counts. The snapshot belongs to the query and scope, so a filter change while it runs neither cancels nor repeats it, and a later filter-only search that already has a snapshot runs no second pass at all. A new query or scope cancels it. An unfiltered search still gets its snapshot from its own single pass.
- The second pass writes `search_facet_counts_completed` to the Search E2E JSONL, which is the requirement's fourth measurement: time until the unchecked options have their counts.
- A two-line group whose lines fall on both sides of a character filter still returns the whole group as context for the matching line, because the group's lines are read in full once one of them passes the SQL filter.

## Verification

- `swift test --filter "SearchDatabaseTests|SearchStoreTests|CueFacetCountCacheTests|URLSchemeSearchRoutingTests|PlaybackSearchOverlayTests"`: 87 tests pass. The database test now asserts that a filtered page has no snapshot, that a two-line group keeps both lines as context, and that the unfiltered snapshot counts every match; new `filteredSearchCompletesFirstAndTheOptionCountsFollowFromASecondScan` runs a real store against an indexed database and checks that the filtered result is complete and exact before any count exists, that the counts scan is running, and that after it finishes the counts cover all 150 matches while the result stays at 50.
- Full `swift test`: 1227 tests, 29 issues in 15 tests, the same pre-existing environment-sensitive set as after Step 3 (native playback, Debug E2E scene and width, Library folder removal, Excerpt scroll anchor and refresh-scope counters); none in Search execution.
- SearchBench on the migrated copy (no filter, unchanged path): `の` 9.8 / 1075 ms, `今` 4.1 / 143 ms, `大丈夫` 4.7 / 32.7 ms hot medians (visible window / exact).
- App level through the E2E controller, launched with the owner's persisted Character `31+` selection, first page e2e / db → filtered result complete e2e / db → unchecked counts complete e2e / db:

| Query | Filtered result | Counts | Step 3 filtered result for comparison |
| --- | --- | --- | --- |
| `大丈夫` (6 results) | 162 / 45 ms | 261 / 53 ms | — |
| `今` (258 results) | 171 / 58 → 304 / 95 ms | 567 / 242 ms | — |
| `の` (2,766 results) | 186 / 74 → 840 / 620 ms | 2797 / 1914 ms | 2078 / 1819 ms |
| `の` hot repeat | 187 / 78 → 826 / 606 ms | 2802 / 1934 ms | — |

- Unchecking `31+` ran the unfiltered `の`: first page 69 ms, complete 3264 / 2056 ms, the same as Step 3. Re-checking `31+` with the snapshot already known: first page 190 / 69 ms, complete 885 / 656 ms with 2,766 results and no second pass. Main-thread gaps of 250 ms or more appeared only in the unfiltered run (the known completion gap, 1.06 s); none during the filtered runs. The owner's selection was left checked as found (capture `step4-31plus-restored.png`).

## Outcome

Matched expectations and the owner's report: with `31+` checked the `の` result count now appears after about 0.8 s instead of about 2.1 s, and the option counts follow about 2 s later without blocking anything. Remaining known limits: a language-only filter gains nothing from the pushdown, and the unfiltered completion gap of about 1 s is unchanged.
