# Search Performance Follow-up

Status: Deferred

## Background

Search responsiveness was investigated after the native app felt slower than
the standalone Search benchmark suggested. The current app now records
project-local Search timing logs under:

```text
logs/search-timing/search-timing-YYYY-MM-DD.log
```

The timing logs show that the visible UI rendering path is not the dominant
cost for the measured slow search case. The slow path is inside
`SubtitleDatabase.searchPage`, after the FTS candidate query returns.

## Investigation Snapshot

Measured on May 11, 2026, local development build, one selected subtitle
folder.

The measured query was a two-character CJK query. The log intentionally records
query length rather than query text.

Search shape:

- Requested page limit: `1000`.
- Returned page results: `1000`.
- Total matching results: `1282`.
- Matching subtitle files: `81`.
- Multi-line candidate cue groups: `943`.
- Loaded cue-line rows: `29740`.

End-to-end timing:

- First result row visible: `1328.66 ms`.
- Debounce wait: `265.73 ms`.
- `database.searchPage`: `1026.52 ms`.
- State assignment after database return: `0.03 ms`.
- Search group rebuild: `1.09 ms`.
- Search completed to first result row visible: `14.55 ms`.

Internal `searchPage` timing:

- Query plan: `0.30 ms`.
- Scope resolution: `0.16 ms`.
- Statement prepare: `1.05 ms`.
- FTS candidate batch: `163.12 ms`.
- Multi-line cue-line load: `130.64 ms`.
- Line-level validation: `110.92 ms`.
- Result sort: `566.72 ms`.
- Page slice: `0.05 ms`.
- File summaries: `51.59 ms`.

## Current Read

The measured bottleneck is not SwiftUI first-row rendering, app-state
assignment, or Search group rebuilding.

The largest observed cost is `db.sort_results`, followed by FTS candidate
loading, cue-line loading, and line-level validation. `db.file_summaries` is
also visible but smaller.

The likely optimization area is Search result ordering and presentation-title
preparation inside or around `SubtitleDatabase.searchPage`. This document does
not prescribe a specific algorithm. The optimization strategy should be chosen
later after feature work priorities are clear.

## Socratic Refinement

Follow-up Socratic questioning narrowed the search-performance problem from a
generic FTS concern into a mismatch between the current search projection and
the product's desired result order.

Discussion observations:

- Query planning, scope resolution, and statement preparation are not the
  meaningful bottlenecks in the measured run.
- Time windows are first-class result identity. A raw subtitle line match should
  map to `(subtitle_file_id, start_ms, end_ms)`, and display results should be
  deduplicated by that key.
- Product results should still display the merged cue group or time window,
  even if a future FTS recall layer indexes raw cue lines.
- Library already materializes flattened work/folder blocks from the project's
  contract-alias rules. Those blocks are natural search partitions.
- The default result order can be treated as stable product order:
  Library block order, then subtitle-file order, then cue time order.
- Search does not need to finish the entire corpus before showing the first
  visible group if the query engine can produce results in that stable order.

Candidate direction:

```text
Index time:
  materialize library_block_rank
  materialize subtitle_file_rank within each block
  keep cue start/end time as the final ordering key
  index raw cue lines for FTS recall
  map each line to its display time-window/cue-group identity

Search time:
  search in stable Library/file order
  match raw lines
  deduplicate to display time windows
  emit each completed file or block group as soon as it is ready
  compute total counts and file summaries after first visible results when needed
```

This is a product-search-model optimization, not just a lower-level database
knob.

## External Optimization Methods

The following methods came from checking mature SQLite/search-engine
documentation after the Socratic discussion. They are not all equally useful for
CueSeeker.

| Method | Origin | Search-speed value | Engineering effort | Decision |
| --- | --- | --- | --- | --- |
| Line-level FTS plus time-window deduplication | Socratic discussion | Negative in measured implementation | High | Rolled back |
| Materialized Library/File/Time ordering | Socratic discussion | High | Medium to high | Done |
| File or Library-block partitioned search with early emission | Socratic discussion | High | High | Done for first-page early return |
| Delayed total count and summaries | Socratic discussion | Medium to high | Medium | Done |
| `ORDER BY` / `LIMIT` index support | External research validated the discussion direction | High | Medium to high | Do |
| Index sorting / early termination | External research validated the discussion direction | High | High | Do |
| Filterable, sortable, and facet-style attributes | External research | Medium to high | Medium to high | Do |
| `fts5vocab` diagnostics | External research | Indirect | Low | Do as diagnostics |
| FTS `optimize` / incremental `merge` | External research | Low to medium | Low to medium | Do as maintenance |
| FTS `automerge`, `crisismerge`, `usermerge` tuning | External research | Low to medium | Medium | Defer |
| Query/result cache | External research, reprioritized by user feedback | High for repeated queries, none for cold queries | Low to medium | Do last |
| FTS prefix indexes | External research, accepted for English search | Scenario-specific but important for English prefix search | Medium | Do |
| FTS contentless or external-content tables | External research | Low | Medium to high | Defer |
| FTS `detail` / `columnsize` reduction | External research | Low | Medium | Defer |
| Trigram tokenizer | External research | Uncertain for precise search | High | Defer |

Current implementation order after rollback:

1. Materialized Library/File/Time ordering.
2. Ordered first-page early return.
3. Delayed total count and summaries.
4. `ORDER BY` / `LIMIT` index support.
5. Index sorting / early termination.
6. Filterable, sortable, and facet-style attributes.
7. `fts5vocab` diagnostics.
8. FTS `optimize` / incremental `merge`.
9. FTS prefix indexes.
10. Query/result cache.

The line-level/hybrid FTS attempt is no longer part of the accepted sequence.
It can be reconsidered only with a narrower hypothesis and benchmark evidence
that proves it is not a search-speed regression.

Query/result cache is intentionally last. It is valuable for repeated searches,
but it should be layered on top of the final search semantics so cache
invalidation does not hide correctness or ordering bugs introduced by earlier
changes.

Deferred methods:

- FTS `automerge`, `crisismerge`, and `usermerge` tuning. These settings can
  move cost from search into indexing and should wait until diagnostics show
  FTS segment count is a real bottleneck.
- FTS contentless or external-content tables. They are mostly storage
  optimizations and introduce stricter consistency requirements between FTS and
  ordinary content tables.
- FTS `detail` and `columnsize` reduction. They primarily reduce storage and
  can affect phrase, location, ranking, or future highlighting behavior.
- Trigram tokenizer. It targets arbitrary substring search, not CueSeeker's
  current precise subtitle search model.

## Benchmark Plan

Before code changes for this optimization sequence, record a baseline benchmark
against the current local app database.

Benchmark queries:

- `大丈夫`
- `今日`
- `の`

Rules:

- Use the same database path, selected corpus, app build mode, and search limit
  for every run in the sequence.
- Run each query five times and use the average as the headline number.
- Keep the raw five timings for each query so outliers remain visible.
- After each implementation step in the accepted order, rerun the same
  benchmark before starting the next step.
- For the final query/result-cache step, clear the cache between benchmark
  query groups, then run each query five times so warm-cache behavior is
  measured without cross-query contamination.
- Record benchmark results in this document or a linked benchmark artifact
  before merging the next optimization step.

## Benchmark Results

### Baseline Before Search Optimizations

Date: 2026-05-15

Commit: `87686ca`

Database:
`/Users/weiyunjun/Library/Application Support/CueSeeker/CueSeeker.sqlite`

Build: SwiftPM debug `SearchBench`

Limit: `1000`

Schema version: `11`

| Query | Warmup ms | Results returned | Total count | File summaries | Hot avg ms | Hot raw ms |
| --- | ---: | ---: | ---: | ---: | ---: | --- |
| `大丈夫` | 936.89 | 185 | 185 | 74 | 103.67 | 102.67, 102.90, 104.79, 103.17, 104.85 |
| `今日` | 487.14 | 1000 | 1282 | 81 | 201.68 | 228.91, 195.00, 197.32, 193.66, 193.53 |
| `の` | 1114.70 | 1000 | 20770 | 87 | 927.81 | 986.37, 887.11, 864.27, 973.56, 927.74 |

### Step 1: Hybrid Line-Level FTS Recall

Date: 2026-05-15

Commit under test: working tree after `c45ce41`, before the follow-up commit
that records this benchmark.

Implementation notes:

- Cue-line FTS recall was added for cross-line-sensitive queries.
- Cue-group FTS recall was retained for cheaper high-frequency single-token
  queries.
- Full cue lines are loaded only for current page results.
- FTS tables are recreated, rebuilt, and optimized during migration.

| Query | Warmup ms | Results returned | Total count | File summaries | Hot avg ms | Hot raw ms |
| --- | ---: | ---: | ---: | ---: | ---: | --- |
| `大丈夫` | 103.38 | 185 | 185 | 74 | 125.16 | 98.75, 102.59, 105.27, 116.41, 202.79 |
| `今日` | 501.70 | 1000 | 1282 | 81 | 692.49 | 473.13, 755.15, 1018.23, 717.60, 498.30 |
| `の` | 4061.83 | 1000 | 20770 | 87 | 2265.56 | 2599.48, 2186.61, 2365.02, 2550.65, 1626.05 |

Read:

- Step 1 was a negative optimization for search speed.
- Hybrid FTS was better than the pure line-level attempt, but still worse than
  the baseline on all three benchmark queries.
- This step was later rolled back and must not be treated as accepted current
  architecture.

### Step 2: Materialized Library/File/Time Ordering

Date: 2026-05-15

Commit under test: working tree after `1a2a176`, before the follow-up commit
that records this benchmark.

Implementation notes:

- Schema version 16 adds `subtitle_search_order_rows` as rebuildable derived
  index data.
- Library/index snapshot rebuilds precompute subtitle folder order, file order,
  and display title order.
- Search joins the materialized order rows and can skip the legacy Swift
  display-title sort when all accepted results have order rows.
- If order rows are missing, Search falls back to the old in-memory order.

| Query | Warmup ms | Results returned | Total count | File summaries | Hot avg ms | Hot raw ms |
| --- | ---: | ---: | ---: | ---: | ---: | --- |
| `大丈夫` | 104.30 | 185 | 185 | 74 | 47.39 | 47.37, 47.23, 47.22, 48.26, 46.88 |
| `今日` | 211.92 | 1000 | 1282 | 81 | 140.56 | 147.02, 142.58, 137.25, 137.99, 137.98 |
| `の` | 1017.91 | 1000 | 20770 | 87 | 869.67 | 865.88, 863.04, 862.15, 874.90, 882.36 |

Read:

- This step addresses the previously dominant `sort_results` phase directly.
- Diagnostics for `今日` confirmed `orderSource=materialized` and reduced
  `sort_results` to about `1 ms`.
- Remaining visible costs are now file summaries, cue-line loading, line-level
  validation, and high-frequency candidate volume.

### Step 3: Roll Back Hybrid FTS, Keep Materialized Ordering

Date: 2026-05-15

Commit under test: working tree after `30d71e6`, before the follow-up commit
that records this benchmark.

Implementation notes:

- Schema version 17 removes the cue-line FTS table from the production search
  path and migration rebuild.
- Search uses cue-group FTS recall again.
- Multi-line cue groups still load cue lines and validate at line level before
  results are returned, preserving the no-cross-line-match rule.
- Materialized search ordering from schema version 16 is retained.

| Query | Warmup ms | Results returned | Total count | File summaries | Hot avg ms | Hot raw ms |
| --- | ---: | ---: | ---: | ---: | ---: | --- |
| `大丈夫` | 1125.54 | 185 | 185 | 74 | 50.05 | 50.71, 48.30, 50.16, 49.32, 51.75 |
| `今日` | 189.02 | 1000 | 1282 | 81 | 117.07 | 123.14, 118.68, 113.21, 114.36, 115.92 |
| `の` | 939.75 | 1000 | 20770 | 87 | 824.51 | 824.96, 806.48, 844.80, 817.05, 829.26 |

Read:

- The rollback confirms the user's objection: hybrid FTS itself was a negative
  optimization for the measured speed goal.
- Compared with Step 2, removing hybrid FTS improved `今日` and `の` while
  keeping `大丈夫` in the same fast range.
- Future Search performance work should proceed from group-level FTS plus
  materialized ordering unless a new benchmark proves otherwise.

### Step 4: Ordered First Page With Deferred Metadata

Date: 2026-05-15

Commit under test: working tree after `f14e511`, before the follow-up commit
that records this benchmark.

This step covers the accepted list's third and fourth items in one narrow
implementation: return the first ordered page as soon as enough product-ordered
matches are available, and delay exact total-count/file-summary metadata until
after the visible page is usable.

Implementation notes:

- `SubtitleDatabase.searchPage` now supports `metadataMode: .deferred`.
- Deferred mode scans only far enough to return the requested ordered page plus
  one lookahead result when materialized order is available.
- Deferred pages return a lower-bound `totalCount`, `hasMoreResults`, partial
  file summaries for loaded results, and `metadataState: .deferred`.
- The macOS app uses deferred mode for visible Search pages, then refreshes
  exact total count and file summaries in a background task using a separate
  SQLite connection.

Benchmark mode:

```text
CUESEEKER_BENCH_METADATA=deferred
```

| Query | Warmup ms | Results returned | Total count shown | File summaries shown | Metadata state | Hot avg ms | Hot raw ms |
| --- | ---: | ---: | ---: | ---: | --- | ---: | --- |
| `大丈夫` | 650.22 | 185 | 185 | 74 | complete | 51.38 | 49.67, 49.30, 48.26, 58.61, 51.05 |
| `今日` | 120.54 | 1000 | 1001 | 23 | deferred | 67.28 | 67.81, 71.32, 67.86, 66.20, 63.24 |
| `の` | 159.75 | 1000 | 1001 | 11 | deferred | 43.10 | 49.90, 43.75, 42.16, 40.27, 39.43 |

Read:

- `大丈夫` has fewer than the requested page limit, so metadata is complete and
  performance stays in the same fast range.
- `今日` and `の` no longer wait for full corpus count/summaries before the
  first page returns.
- A diagnostic run for `の` reported `metadataState=deferred`,
  `candidateBatchLimit=1001`, and `search_page_complete` around `33-43 ms`.

## Development Decision

This performance issue is a known follow-up and should not block ordinary
feature development.

Rules:

- Keep the detailed Search timing logs available during development.
- Do not pause unrelated feature work solely because this Search hot path still
  needs optimization.
- Before changing the Search ranking, title preparation, or result-summary
  algorithm, compare against the timing snapshot above and capture a new timing
  log for the same broad case.
- Any later optimization should preserve current Search semantics unless a
  separate product or engineering decision changes those semantics first.

## Acceptance Direction

A future optimization pass should be judged against real app timing logs, not
only standalone benchmark output.

Useful comparison metrics:

- `db.search_page_complete phase`.
- `db.sort_results phase`.
- `db.file_summaries phase`.
- `db.fts_batch phase`.
- `database_search_returned phase`.
- `first_result_row_appeared elapsed`.

The next pass should record before-and-after logs for at least:

- The two-character CJK high-result query shape above.
- A lower-result CJK query.
- Repeating the same query without restarting the app.

## External References

- SQLite FTS5 extension documentation:
  https://www.sqlite.org/fts5.html
- SQLite query planner documentation:
  https://www.sqlite.org/queryplanner.html
- Elasticsearch index sorting and early termination:
  https://www.elastic.co/docs/reference/elasticsearch/index-settings/sorting
- Meilisearch filtering, sorting, and faceting overview:
  https://www.meilisearch.com/docs/capabilities/filtering_sorting_faceting/overview
