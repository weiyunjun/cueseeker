# Search Performance Follow-up

Status: Active

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
CueSeeker. The decision column records the earlier investigation status before
the full Search rollback; the active implementation sequence is the accepted
17-step plan below.

| Method | Origin | Search-speed value | Engineering effort | Decision |
| --- | --- | --- | --- | --- |
| Line-level FTS plus time-window deduplication | Socratic discussion | Negative in measured implementation | High | Rolled back |
| Materialized Library/File/Time ordering | Socratic discussion | High | Medium to high | Done |
| File or Library-block partitioned search with early emission | Socratic discussion | High | High | Done for first-page early return |
| Delayed total count and summaries | Socratic discussion | Medium to high | Medium | Done |
| `ORDER BY` / `LIMIT` index support | External research validated the discussion direction | Negative for current FTS path | Medium to high | Investigated and rejected |
| Index sorting / early termination | External research validated the discussion direction | High | Medium | Done with FTS rowid order |
| Filterable, sortable, and facet-style attributes | External research | Medium for complete metadata | Medium | Done with unindexed FTS attributes |
| `fts5vocab` diagnostics | External research | Indirect | Low | Done as diagnostics |
| FTS `optimize` / incremental `merge` | External research | Low to medium | Low to medium | Do as maintenance |
| FTS `automerge`, `crisismerge`, `usermerge` tuning | External research | Low to medium | Medium | Defer |
| Query/result cache | External research, reprioritized by user feedback | High for repeated queries, none for cold queries | Low to medium | Do last |
| FTS prefix indexes | External research, accepted for English search | Scenario-specific but important for English prefix search | Medium | Do |
| FTS contentless or external-content tables | External research | Low | Medium to high | Defer |
| FTS `detail` / `columnsize` reduction | External research | Low | Medium | Defer |
| Trigram tokenizer | External research | Uncertain for precise search | High | Defer |

Previous implementation order before the full Search rollback:

1. Materialized Library/File/Time ordering.
2. Ordered first-page early return.
3. Delayed total count and summaries.
4. `ORDER BY` / `LIMIT` index support: investigated and rejected for the
   current FTS-driven query path.
5. Index sorting / early termination with FTS rowid product order.
6. Filterable, sortable, and facet-style attributes in FTS rows.
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

## Rollback And New Alignment

Date: 2026-05-15

The Search optimization implementation sequence has been rolled back to the
pre-optimization baseline recorded after commit `2c1fc91`.

Reason:

- The implementation optimized a page-level "first page" metric: return about
  100 ordered rows plus enough metadata for the current page.
- The user-facing target is different: render the first matching ASS file's
  results as soon as that file is complete, then continue rendering additional
  ASS files in file-sized increments.
- For queries with only a small or medium result set, waiting for 100 rows can
  require scanning most of the final result set. That made the measured
  `first` timing fail to represent the perceived time until useful results are
  visible.
- The cue-line/hybrid FTS path remains excluded. It was already benchmarked as
  a negative optimization and should not be retried automatically in the new
  round.

Current retained implementation:

- Baseline group-level FTS Search from before the optimization sequence.
- The `Developer` Settings category remains reserved for later diagnostics, but
  the active Search optimization flow must use benchmark output and logs first.
  Search-performance numbers should not be added to the front-end UI until the
  Search mechanism is stable and accepted.

New Socratic definitions:

- "First visible Search result" now means the time until the first matching ASS
  file group can render a bounded preview of matching rows.
- Progress should advance by ASS file, but a large ASS file must not block the
  first useful UI update by requiring all of that file's matches to enter app
  state.
- Visible Search counts must be exact. `Found <count> results in <count> files`
  and file-group result counts must not use lower bounds, loaded-row counts, or
  pagination sentinels.
- The benchmark headline metrics are:
  - time until the first matching ASS file group preview is rendered;
  - time until the 2nd, 5th, and 10th matching file group previews are rendered;
  - time until exact counts and summaries are complete;
  - time to load another row page inside one subtitle file.
- The prior page-level "first page" metric is no longer an acceptance metric.
- The playback overlay Search Results list is explicitly out of scope for this
  sequence. It needs its own data-windowing design later.

### Search Result Presentation State Model

The Search results page needs an explicit presentation state model. The exact
state names may evolve, but the logic relationships are fixed:

| State | Entry | Required behavior |
| --- | --- | --- |
| Searching | After the user submits a query and before the active Search/load-more work is complete. | `Collapse All` is disabled. The visible result view may lazy-load more global rows, but every visible ASS/subtitle file alias must have at least one loaded matching row. Empty file aliases and default-collapsed file aliases are not allowed. |
| Initial | After Search work is complete and before `Collapse All` is clicked. | The visible result view may lazy-load more global rows. Every visible ASS/subtitle file alias must have at least one loaded matching row. Empty file aliases and default-collapsed file aliases are not allowed. |
| Collapsed | After `Collapse All` is clicked. | Refresh into an all-results file-alias view where every matching ASS/subtitle file is collapsed. Preserve the current selected result. Clicking a file alias expands that file's matching rows, and file-internal lazy loading still applies when the file has more rows than the initial per-file page. |

Lazy loading applies in all states, but the loaded unit differs by state:

- In `Searching` and `Initial`, scrolling near the threshold loads the next
  global page of 100 matching rows.
- In `Collapsed`, expanding or scrolling inside a file group loads that file's
  matching rows in pages, also with a page size of 100 unless a later rule
  changes it.

The strict alias/result invariant is:

```text
In Searching or Initial state:
  visible ASS/subtitle file alias <=> at least one loaded matching row exists
  for that file in the current Search result view.

In Collapsed state:
  visible ASS/subtitle file alias <=> the file has at least one match in the
  complete Search result set.
```

Sorting and filtering work must build on this state model so later result
projections do not mix loaded-row views, all-file collapsed views, and
file-internal lazy loading into one ambiguous UI state.

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

## Excluded Items

The following items are not part of the next implementation sequence:

- Line-level FTS plus time-window deduplication. The measured implementation
  was a negative optimization and must not be retried automatically.
- `ORDER BY` / `LIMIT` index support. The prior database-copy experiment showed
  a severe regression for the current SQLite FTS shape.
- Playback overlay Search Results lazy loading. It is a separate consumer-side
  list problem and should be designed after the Search results page is aligned.

## Accepted Stage-Gated Plan

This supersedes the earlier item order. The active flow is stage-gated: measure
the current baseline first, add only log or benchmark observability next, prove
the behavior with automated and end-to-end tests, and only then continue to the
next implementation step.

There is no bundled "first round". Each step must be implemented, benchmarked,
tested, and accepted or rejected before moving to the next step. If the data
does not support the step's goal, the step stops.

### Pre-Implementation Gates

These gates must pass before any new Search optimization mechanism starts:

| Gate | Item | Acceptance |
| --- | --- | --- |
| A | Baseline benchmark | Run the three benchmark queries, record raw timings, averages, result counts, file counts, and the current commit. No code changes are allowed in this gate. |
| B | Log or benchmark diagnostics | Add or verify machine-readable diagnostics in logs or benchmark output only. Do not add Search-performance data to the Search panel or front-end Developer UI during unstable work. |
| C | Automated tests | Add or verify fixture-based tests for Search correctness, including identity, grouping, ordering, folder scope, counts, pagination, and lazy-loading boundaries touched by the planned step. |
| D | End-to-end test | Follow the fixed Search E2E sequence in `docs/engineering/08_end_to_end_testing.md`: search `大丈夫`, `今日`, and `の` in order, use the documented waits and scroll counts, and record pass/fail evidence before accepting the step. |

### Implementation Backlog

After the gates pass, the implementation backlog proceeds one item at a time.
Diagnostic visibility remains in benchmark output or logs unless the user
explicitly accepts a front-end diagnostic surface after the core mechanism is
stable.

| Step | Item | Ownership | Purpose |
| ---: | --- | --- | --- |
| 1 | New benchmark gaps | Test / benchmark, backend-leaning | Fill only the missing benchmark coverage needed to measure file-group preview readiness, exact-count completion, and per-file load-more latency after the baseline has been recorded. |
| 2 | Search-layer pagination / cursor | Backend-first, AppState integration | Make continuation state an explicit Search-layer cursor so AppState consumes bounded pages instead of deriving the next page from loaded row counts. |
| 3 | Provisional count model (Deprecated) | Deprecated; sequence number retained for traceability | Do not execute. The accepted Search UI semantics require exact visible counts; lower-bound or loaded-row counts must not feed `Found` or file-group totals. |
| 4 | Exact count background completion (Deprecated) | Deprecated; sequence number retained for traceability | Do not execute. Background replacement of provisional counts was rejected; current Search pages return exact total count and exact file summaries before the initial result list settles. |
| 5 | `fts5vocab` diagnostics | Backend / diagnostic tool | Make high-frequency terms and possible FTS index pollution observable through benchmark or log output before later tuning. |
| 6 | Precomputed Library/File/Time sorting | Backend / index data | Provide stable product order without recomputing friendly-title order on every Search. |
| 7 | Block search / completed unit return | Backend-first, front-end consumes results | Let Search emit usable file or block units before the whole corpus finishes. |
| 8 | Delayed count / summaries | Backend / state model | Keep exact totals out of the first useful result path. |
| 9 | Index sorting / early termination | Backend / database query optimization | Test whether FTS row order or equivalent index-sorted recall improves the new file-preview metrics. |
| 10 | Filterable / sortable / facet attributes | Backend / data model and index | Test whether denormalized Search hot-path attributes reduce metadata and join cost under the new flow. |
| 11 | Prefix index | Backend / index | Support and benchmark English prefix search after core Search semantics are stable. |
| 12 | FTS `optimize` / `merge` | Backend / maintenance strategy | Treat FTS segment maintenance as a measured maintenance step, not as assumed speed work. |
| 13 | File-group progressive display (Deprecated) | Deprecated; sequence number retained for traceability | Do not execute. The current front-end lazy-loading behavior would not make this step's near-bottom polling effect observable while the Search request itself is still the bottleneck. |
| 14 | File-group initial preview (Deprecated) | Deprecated; sequence number retained for traceability | Do not execute. A smaller file-group preview conflicts with the accepted 100-row lazy-loading unit and would introduce a second loading model. |
| 15 | File-internal `Show more` (Deprecated) | Deprecated; sequence number retained for traceability | Do not execute. The accepted interaction is automatic lazy loading, not a separate per-file `Show more` control. |
| 16 | UI virtualization / windowing validation | Front-end / test | Confirm through tests or logs that loaded rows and rendered row views are separate, and that visible row count stays bounded. |
| 17 | Query / result cache | Backend / cache | Add repeated-query acceleration last so cache behavior cannot hide earlier correctness or ordering bugs. |

## Testing Workflow

Each step uses the same local database and selected corpus unless the step
explicitly changes indexing or schema.

Benchmark queries:

- `大丈夫`
- `今日`
- `の`

Benchmark rules:

- Before changing code for an implementation step, run the three benchmark
  queries and record the current baseline for the exact commit under test.
- After each step, run each query five times and record the average plus all
  five raw timings.
- Record at least these timings when applicable:
  - first file-group preview visible;
  - 2nd file-group preview visible;
  - 5th file-group preview visible;
  - 10th file-group preview visible;
  - exact counts and summaries complete;
  - complete Search work finished;
  - per-file load-more request complete.
- Record result shape with the timing:
  - visible file groups;
  - loaded rows;
  - exact total count;
  - exact file-summary count;
  - summary count update cadence when count progress is part of the step;
  - maximum active rendered row views for virtualization checks.
- Prefer non-UI automated benchmark coverage for Search-layer timings. During
  unstable Search work, diagnostic data belongs in logs or benchmark output, not
  in the Search panel.
- Run the relevant automated test suite before accepting the step. If the step
  changes Search semantics, add fixture coverage before relying on manual
  acceptance.
- Run or update the Search optimization end-to-end procedure before accepting a
  step that affects the app's visible Search workflow, scrolling, collapse or
  expansion behavior, lazy loading, or playback result selection. The procedure
  must use the fixed query order `大丈夫`, `今日`, `の` and the documented
  per-query wait and scroll requirements.
- For Step 2, Search E2E JSONL evidence must include the requested `cursor`, the
  returned `nextCursor`, `limit`, `returned`, `groups`, `renderedRows`, and
  `hasMore` for every observed page. The accepted shape is continuous cursor
  progression with no duplicate rows, no skipped rows, no stale rows from the
  previous query, and no unintended global load after `Collapse All`.
- Steps 3 and 4 are deprecated. Current Search E2E JSONL evidence must show
  `countState: exact`; `knownResultCount`, `knownFileCount`, `totalCount`, and
  `fileSummaries` must all represent exact counts for the Search page.
- For Step 17, clear cache state between benchmark query groups, then run each
  query five times so warm-cache behavior is measured without cross-query
  contamination.

### Current Gate A Baseline

Date: 2026-05-15

Commit: `fe8d09a`

Database:
`/Users/weiyunjun/Library/Application Support/CueSeeker/CueSeeker.sqlite`

Build: SwiftPM debug `SearchBench`

Limit: `1000`

Schema version: `11`

Run shape: one warmup search followed by five hot searches for each query.
This baseline records the existing `searchPage` complete-metadata path. It is
comparable with the historical `SearchBench` tables below, but it does not yet
measure the new file-group progressive UX metrics. Those missing metrics belong
to Step 1, after this baseline has been recorded.

In this table, `File summaries` is the count of unique matching subtitle files.

| Query | Warmup ms | Results returned | Total count | File summaries | Hot avg ms | Hot raw ms |
| --- | ---: | ---: | ---: | ---: | ---: | --- |
| `大丈夫` | 535.50 | 185 | 185 | 74 | 90.88 | 89.39, 88.91, 89.44, 93.34, 93.31 |
| `今日` | 316.74 | 1000 | 1282 | 81 | 170.28 | 170.23, 167.20, 167.40, 169.72, 176.85 |
| `の` | 1447.85 | 1000 | 20770 | 87 | 1125.95 | 1120.03, 1119.29, 1124.35, 1143.77, 1122.32 |

### Step 1 Benchmark Gap Outputs

Step 1 adds measurement coverage only. It does not change Search ordering,
pagination semantics, grouping semantics, or the visible Search UI.

The app E2E JSONL stream records the new measurements under schema version 3:

- `fileGroupPreviewMilestones` for the 1st, 2nd, 5th, and 10th loaded
  file-group previews.
- `exactCountsCompletion` for exact result totals and file summaries.
- `perFileLoadMore` for subtitle-path-filtered page loads triggered by
  per-file expand/load-more behavior.

`SearchBench --step1-gaps` prints a `STEP1_GAPS_JSON` line with matching
machine-readable metrics for automated benchmark capture.

Verification run:

Date: 2026-05-15

Worktree base before this Step 1 commit: `ff163df`

Command:

```bash
.build/arm64-apple-macosx/debug/SearchBench "$HOME/Library/Application Support/CueSeeker/CueSeeker.sqlite" 大丈夫 100 --step1-gaps
```

Result:

| Query | Limit | Warmup complete ms | Hot avg complete ms | Hot raw complete ms | Returned | Total count | File summaries | Loaded preview groups | Per-file target | Per-file warmup ms | Per-file hot avg ms | Per-file hot raw ms |
| --- | ---: | ---: | ---: | --- | ---: | ---: | ---: | ---: | --- | ---: | ---: | --- |
| `大丈夫` | 100 | 478.54 | 90.87 | 89.84, 90.77, 90.36, 91.52, 91.86 | 100 | 185 | 74 | 39 | `Ave Mujica - 01` | 1.07 | 0.74 | 0.77, 0.75, 0.73, 0.72, 0.73 |

Preview milestones were reached for the 1st, 2nd, 5th, and 10th loaded file
groups in the current complete-page baseline. Because this step adds
measurement only, those preview milestones currently use the complete-page
elapsed time; later mechanism steps must move them earlier before they can
count as a Search responsiveness improvement.

### Step 2: Search-layer Pagination / Cursor

Date: 2026-05-15

Comparison:

- Baseline commit: `77eab8f`
- Implementation commit: `926a9b5`
- Command shape: `SearchBench "$HOME/Library/Application Support/CueSeeker/CueSeeker.sqlite" <query> 100`
- Scope: first Search page, limit `100`, same local schema 11 database.

Result:

| Query | Baseline warmup ms | Baseline hot avg ms | Baseline hot raw ms | Current warmup ms | Current hot avg ms | Current hot raw ms | Returned | Total count | File summaries | Cursor | Next cursor |
| --- | ---: | ---: | --- | ---: | ---: | --- | ---: | ---: | ---: | ---: | ---: |
| `大丈夫` | 329.35 | 91.47 | 92.45, 90.18, 91.60, 91.65, 91.44 | 559.88 | 90.76 | 90.33, 91.00, 90.58, 90.65, 91.26 | 100 | 185 | 74 | 0 | 100 |
| `今日` | 1149.00 | 187.04 | 191.60, 191.54, 185.42, 182.71, 183.91 | 334.48 | 185.62 | 184.56, 184.34, 185.65, 186.72, 186.85 | 100 | 1282 | 81 | 0 | 100 |
| `の` | 5937.47 | 5626.13 | 5714.94, 5586.21, 5629.36, 5560.39, 5639.75 | 6601.57 | 5583.92 | 5540.53, 5595.57, 5577.02, 5600.92, 5605.59 | 100 | 20770 | 87 | 0 | 100 |

Read after implementation:

- Core Search now returns an explicit `SubtitleSearchCursor` and `nextCursor`
  with each `SubtitleSearchPage`.
- AppState global Search lazy loading now advances with `nextCursor` from the
  prior page instead of deriving the next request from loaded row count.
- Search E2E JSONL schema version `4` added `cursor` and `nextCursor` on Search
  page records; later schemas must retain those fields.
- The hot-average benchmark did not regress for the three required queries.
  Warmup timings remained noisy, especially for broad exact-count queries, so
  acceptance should use the fixed E2E cursor sequence in addition to automated
  tests.

### Step 4 Provisional Metadata Smoke Check (Superseded)

Date: 2026-05-15

Commit under test: working tree after `0c505aa`, before the follow-up commit
that records this implementation.

This smoke check is retained as historical evidence only. The provisional
metadata path was rejected because visible `Found` and file-group counts must
represent exact counts, not lower bounds or pagination sentinels.
Current `SearchBench` no longer supports `--provisional-metadata`.

Command:

```text
.build/arm64-apple-macosx/debug/SearchBench "$HOME/Library/Application Support/CueSeeker/CueSeeker.sqlite" 大丈夫 100 --provisional-metadata
```

Result:

| Query | Limit | Metadata mode | Warmup ms | Returned | Total count shown | File summaries shown | Count state | Known result count | Known file count | Hot avg ms | Hot raw ms | Cursor | Next cursor |
| --- | ---: | --- | ---: | ---: | ---: | ---: | --- | ---: | ---: | ---: | --- | ---: | ---: |
| `大丈夫` | 100 | provisional | 538.89 | 100 | 101 | 39 | provisional | 101 | 39 | 59.01 | 60.01, 58.07, 58.19, 60.32, 58.46 | 0 | 100 |

Read:

- Superseded. Do not use this output shape as an acceptance target.
- Current acceptance requires `countState: exact` on Search page records and
  exact `totalCount` / `fileSummaries` before the initial list settles.

### Step 5: `fts5vocab` Diagnostics

Date: 2026-05-15

Before version: `a338672`

Commit under test: working tree after `a338672`, before the follow-up commit
that records this implementation.

Implementation notes:

- `SubtitleDatabase` exposes explicit FTS vocabulary diagnostics for
  `subtitle_cue_groups_fts` through SQLite `fts5vocab`.
- `SearchBench` prints the diagnostics only when
  `CUESEEKER_BENCH_FTS_VOCAB=1` is set.
- Settings > Developer exposes an `FTS Vocabulary Diagnostics` switch, default
  on, plus an inline data panel with refresh, vocabulary totals, current-query
  term stats, and most-frequent terms.
- Normal Search and normal SearchBench runs do not create or query
  `fts5vocab`.
- The diagnostics report unique vocabulary terms, total term-document
  references, total term occurrences, most frequent terms, and the vocabulary
  scale for the query terms.

Pre-change exact baseline:

| Query | Warmup ms | Returned | Total count | File summaries | Count state | Hot avg ms | Hot raw ms |
| --- | ---: | ---: | ---: | ---: | --- | ---: | --- |
| `大丈夫` | 716.71 | 185 | 185 | 74 | exact | 91.69 | 90.54, 88.76, 88.50, 90.33, 100.34 |
| `今日` | 330.65 | 1000 | 1282 | 81 | exact | 171.81 | 170.42, 170.07, 173.95, 168.02, 176.58 |
| `の` | 1434.38 | 1000 | 20770 | 87 | exact | 1119.68 | 1108.98, 1116.25, 1123.55, 1137.04, 1112.58 |

Post-change benchmark with vocabulary diagnostics disabled:

| Query | Warmup ms | Returned | Total count | File summaries | Count state | Hot avg ms | Hot raw ms |
| --- | ---: | ---: | ---: | ---: | --- | ---: | --- |
| `大丈夫` | 553.53 | 185 | 185 | 74 | exact | 92.26 | 92.93, 91.90, 92.19, 91.96, 92.34 |
| `今日` | 311.32 | 1000 | 1282 | 81 | exact | 173.73 | 170.48, 168.23, 184.94, 169.25, 175.75 |
| `の` | 1593.83 | 1000 | 20770 | 87 | exact | 1135.53 | 1132.81, 1131.75, 1135.62, 1131.93, 1145.52 |

Vocabulary totals from explicit diagnostics:

| Metric | Value |
| --- | ---: |
| Unique vocabulary terms | 11,337 |
| Total term-document references | 1,481,292 |
| Total term occurrences | 9,135,487 |

Query-term diagnostics:

| Query | Diagnostic elapsed ms | Term | Document count | Occurrences |
| --- | ---: | --- | ---: | ---: |
| `大丈夫` | 129.40 | `大` | 2,697 | 3,114 |
| `大丈夫` | 129.40 | `丈` | 263 | 266 |
| `大丈夫` | 129.40 | `夫` | 431 | 523 |
| `今日` | 82.77 | `今` | 2,668 | 21,864 |
| `今日` | 82.77 | `日` | 2,220 | 12,884 |
| `の` | 83.00 | `の` | 20,770 | 88,481 |

Most frequent terms:

| Term | Document count | Occurrences |
| --- | ---: | ---: |
| `0` | 8,286 | 1,016,421 |
| `30` | 8,300 | 871,220 |
| `15` | 8,293 | 726,013 |
| `b` | 8,314 | 580,844 |
| `7` | 8,283 | 580,805 |
| `23` | 8,282 | 580,802 |
| `m` | 8,568 | 145,494 |
| `い` | 25,403 | 117,454 |
| `て` | 23,122 | 102,581 |
| `的` | 24,841 | 93,126 |
| `た` | 21,748 | 91,457 |
| `の` | 20,770 | 88,481 |

Read:

- The default Search path is unchanged for diagnostics: `fts5vocab` is queried
  only when `CUESEEKER_BENCH_FTS_VOCAB=1`.
- `の` is a high-frequency indexed token: it appears in `20,770` documents and
  `88,481` occurrences, matching the broad query's large exact result count.
- The most frequent terms are dominated by ASS markup/style-like tokens such
  as numbers and tag letters. This makes index pollution observable for later
  FTS maintenance or tokenizer cleanup work.

## Acceptance Standards

General standards:

- The step must preserve Search correctness: result identity, grouping, query
  matching behavior, result ordering, and playback target timestamps.
- `swift build`, `swift test`, and `git diff --check` must pass before commit.
- The benchmark table for the step must be recorded before moving to the next
  step.
- Required automated tests and end-to-end evidence must be recorded before the
  step is accepted.
- Front-end Search-performance display is not part of the early acceptance
  path. It can be proposed only after the underlying Search mechanism is stable
  and the user explicitly accepts the UI surface.
- If a step is slower on the metric it is meant to improve, the default action
  is to revert or disable it. Keeping a negative result requires explicit user
  approval and a documented reason.

Metric-specific standards:

- Test and diagnostic steps are accepted when the agreed measurement is
  available, repeatable, and does not materially change Search behavior.
- Mechanism steps are accepted when the intended user-visible behavior works
  and the new benchmark can observe it directly.
- Performance steps are accepted only when their target metric improves or
  stays neutral while providing a documented non-speed benefit.
- Cache is accepted only if warm repeated queries improve while cold-query
  behavior, cache invalidation after indexing, and result correctness remain
  valid.

## Historical Benchmark Plan Before Rollback

The following benchmark plan and results are retained as evidence from the
rolled-back optimization sequence. They are not the active acceptance standard;
the active standard is the new Testing Workflow above.

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

## Historical Benchmark Results Before Rollback

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

### Step 4: Ordered First Page With Deferred Metadata (Superseded)

Date: 2026-05-15

Commit under test: working tree after `f14e511`, before the follow-up commit
that records this benchmark.

This section is retained as historical benchmark evidence only. The deferred
metadata design conflicts with the accepted Search UI count semantics because
visible counts must be exact before the initial list settles.

Historical implementation notes:

- `SubtitleDatabase.searchPage` supported `metadataMode: .deferred`.
- Deferred mode scanned only far enough to return the requested ordered page plus
  one lookahead result when materialized order is available.
- Deferred pages returned a lower-bound `totalCount`, `hasMoreResults`, partial
  file summaries for loaded results, and `metadataState: .deferred`.
- The macOS app used deferred mode for visible Search pages, then refreshed
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

Complete metadata comparison on the same commit:

| Query | First-page hot avg ms | Complete metadata hot avg ms | Approx. time until exact metadata ms |
| --- | ---: | ---: | ---: |
| `大丈夫` | 51.38 | 47.92 | 51.38 |
| `今日` | 67.28 | 116.39 | 183.67 |
| `の` | 43.10 | 830.48 | 873.58 |

Read:

- `大丈夫` has fewer than the requested page limit, so metadata is complete and
  performance stays in the same fast range.
- `今日` and `の` no longer wait for full corpus count/summaries before the
  first page returns.
- A diagnostic run for `の` reported `metadataState=deferred`,
  `candidateBatchLimit=1001`, and `search_page_complete` around `33-43 ms`.
- Future benchmark tables should include first-page time, complete metadata
  time, and approximate time until exact metadata is refreshed.

### Step 5: `ORDER BY` / `LIMIT` Index Support Investigation

Date: 2026-05-15

Commit under test: `2091ec8`

Outcome: not implemented.

The current query plan still uses a temporary B-tree for SQL ordering:

```text
SCAN f VIRTUAL TABLE INDEX 0:M2
SEARCH g USING INTEGER PRIMARY KEY
SEARCH sf USING INTEGER PRIMARY KEY
SEARCH m USING INDEX sqlite_autoindex_subtitle_video_matches_1
SEARCH vf USING INTEGER PRIMARY KEY
SEARCH sor USING INDEX sqlite_autoindex_subtitle_search_order_rows_1 LEFT-JOIN
USE TEMP B-TREE FOR ORDER BY
```

An experimental database copy tested an order-driven cue index:

```text
subtitle_cue_search_order_rows(
  cue_group_id,
  subtitle_path,
  folder_order,
  file_order,
  start_ms,
  end_ms
)
```

with an index on:

```text
(folder_order, file_order, start_ms, end_ms, cue_group_id)
```

This changed the plan to scan the cue-order index first and eliminated the
global temporary sort, but it forced SQLite to probe FTS from product-order
rows. On the copied database, `の LIMIT 1001` took about `87.44 s` for the
order-driven query, versus about `0.03 s` for the current FTS-driven query.

Decision:

- Do not implement order-driven `ORDER BY` / `LIMIT` indexing on the current
  FTS query path.
- The current FTS-driven query with a small temporary sort is much faster than
  scanning product order and checking FTS row by row.
- Revisit this only if the search projection changes, for example to a search
  engine or table shape that can natively combine term matching with product
  order.

### Step 6: FTS Rowid Index Sorting And Early Termination

Date: 2026-05-15

Commit under test: working tree after `e8afe3d`, before the follow-up commit
that records this benchmark.

Implementation notes:

- Schema version 18 rebuilds `subtitle_cue_groups_fts` rows with explicit FTS
  `rowid` values assigned in product order:
  Library block rank, subtitle-file rank, cue start time, cue end time, cue id.
- Search now uses `ORDER BY f.rowid ASC` instead of a joined product-order SQL
  expression.
- Rebuilding the subtitle search-order snapshot also rebuilds cue-group FTS
  rows so rowid order stays aligned with the materialized product order.
- The v18 migration rebuilds existing FTS rows so older schema 17 databases do
  not keep stale insertion-order rowids.

Query-plan check for `の LIMIT 1001` after migration:

```text
SCAN f VIRTUAL TABLE INDEX 64:M2
SEARCH g USING INTEGER PRIMARY KEY
SEARCH sf USING INTEGER PRIMARY KEY
SEARCH m USING INDEX sqlite_autoindex_subtitle_video_matches_1
SEARCH vf USING INTEGER PRIMARY KEY
SEARCH sor USING INDEX sqlite_autoindex_subtitle_search_order_rows_1 LEFT-JOIN
```

The plan no longer reports `USE TEMP B-TREE FOR ORDER BY`.

Deferred first-page benchmark:

| Query | Warmup ms | Results returned | Total count shown | File summaries shown | Metadata state | Hot avg ms | Hot raw ms |
| --- | ---: | ---: | ---: | ---: | --- | ---: | --- |
| `大丈夫` | 464.30 | 185 | 185 | 74 | complete | 46.53 | 48.27, 46.13, 45.83, 45.95, 46.49 |
| `今日` | 68.49 | 1000 | 1001 | 23 | deferred | 64.74 | 64.98, 65.65, 64.88, 64.47, 63.75 |
| `の` | 12.24 | 1000 | 1001 | 11 | deferred | 8.93 | 9.12, 9.21, 8.71, 8.71, 8.91 |

Complete metadata benchmark:

| Query | Warmup ms | Results returned | Total count | File summaries | Hot avg ms | Hot raw ms |
| --- | ---: | ---: | ---: | ---: | ---: | --- |
| `大丈夫` | 54.49 | 185 | 185 | 74 | 50.49 | 50.85, 50.79, 50.24, 50.23, 50.34 |
| `今日` | 311.59 | 1000 | 1282 | 81 | 118.53 | 120.05, 117.16, 118.79, 118.16, 118.50 |
| `の` | 604.71 | 1000 | 20770 | 87 | 572.56 | 579.01, 569.37, 578.00, 569.51, 566.91 |

Combined comparison:

| Query | Previous first-page ms | Step 6 first-page ms | Previous complete ms | Step 6 complete ms | Step 6 approx. time until exact metadata ms |
| --- | ---: | ---: | ---: | ---: | ---: |
| `大丈夫` | 51.38 | 46.53 | 47.92 | 50.49 | 46.53 |
| `今日` | 67.28 | 64.74 | 116.39 | 118.53 | 183.27 |
| `の` | 43.10 | 8.93 | 830.48 | 572.56 | 581.49 |

Read:

- This is the first accepted implementation of index sorting / early
  termination for the current SQLite FTS path.
- The important design distinction from Step 5 is that FTS remains the query
  driver. Product order is encoded into FTS `rowid`, so SQLite can return
  product-ordered FTS matches directly.
- The largest gain is for high-frequency CJK queries such as `の`, where the
  first-page path no longer pays the old FTS candidate ordering cost.
- The one-time migration on the measured local database rebuilt rowids in about
  `2227.29 ms`.

### Step 7: Filterable, Sortable, And Presentation Attributes In FTS

Date: 2026-05-15

Commit under test: working tree after `4f7948f`, before the follow-up commit
that records this benchmark.

Implementation notes:

- Schema version 19 recreates `subtitle_cue_groups_fts` with unindexed
  candidate attributes: cue group id, subtitle path/format, video path/name,
  cue start/end milliseconds, original search content, line count, folder/file
  order, and display title.
- Search candidate loading now reads from FTS only. It no longer joins
  `subtitle_cue_groups`, `subtitle_files`, `subtitle_video_matches`,
  `video_files`, and `subtitle_search_order_rows` for every FTS hit.
- The indexed FTS `content` still stores segmented text for matching. The
  unindexed `search_content` stores original clean cue-group text for display
  and final line-level validation.
- Rebuilding FTS rows preserves schema 18's product-ordered rowid behavior.

Query-plan check for `の LIMIT 1001` after migration:

```text
SCAN f VIRTUAL TABLE INDEX 64:M13
```

Deferred first-page benchmark:

| Query | Warmup ms | Results returned | Total count shown | File summaries shown | Metadata state | Hot avg ms | Hot raw ms |
| --- | ---: | ---: | ---: | ---: | --- | ---: | --- |
| `大丈夫` | 556.72 | 185 | 185 | 74 | complete | 46.32 | 48.89, 45.96, 45.85, 45.73, 45.17 |
| `今日` | 67.98 | 1000 | 1001 | 23 | deferred | 64.71 | 65.15, 64.60, 65.19, 65.36, 63.23 |
| `の` | 21.18 | 1000 | 1001 | 11 | deferred | 8.98 | 8.90, 8.88, 9.08, 8.71, 9.34 |

Complete metadata benchmark:

| Query | Warmup ms | Results returned | Total count | File summaries | Hot avg ms | Hot raw ms |
| --- | ---: | ---: | ---: | ---: | ---: | --- |
| `大丈夫` | 62.29 | 185 | 185 | 74 | 55.08 | 57.20, 57.63, 56.36, 52.65, 51.57 |
| `今日` | 156.80 | 1000 | 1282 | 81 | 112.92 | 118.36, 116.48, 110.54, 109.99, 109.24 |
| `の` | 806.29 | 1000 | 20770 | 87 | 497.09 | 606.68, 463.68, 468.65, 479.82, 466.63 |

Combined comparison:

| Query | Step 6 first-page ms | Step 7 first-page ms | Step 6 complete ms | Step 7 complete ms | Step 7 approx. time until exact metadata ms |
| --- | ---: | ---: | ---: | ---: | ---: |
| `大丈夫` | 46.53 | 46.32 | 50.49 | 55.08 | 46.32 |
| `今日` | 64.74 | 64.71 | 118.53 | 112.92 | 177.63 |
| `の` | 8.93 | 8.98 | 572.56 | 497.09 | 506.07 |

Read:

- This step is a modest but accepted optimization, not a large first-page win.
- The first-page path was already dominated by a single product-ordered FTS
  batch after Step 6, so removing joins did not materially change it.
- Complete metadata improved for `今日` and `の` because those paths still scan
  more candidates and therefore benefit from avoiding per-candidate joins.
- `大丈夫` complete metadata regressed slightly in the stable rerun. It has only
  185 matches, so the larger FTS row payload can outweigh the removed joins.
- The first complete `大丈夫` run had a transient raw outlier
  `163.92 ms`; the table above uses the immediate rerun, whose raw timings were
  stable.
- The one-time v19 migration on the measured local database rebuilt FTS rows in
  about `2202.26 ms`.

### Step 8: `fts5vocab` Diagnostics (Historical)

Date: 2026-05-15

Commit under test: working tree after `485a8cd`, before the follow-up commit
that records this benchmark.

Implementation notes:

- `SubtitleDatabase` exposes FTS vocabulary diagnostics for
  `subtitle_cue_groups_fts` through SQLite `fts5vocab`.
- `SearchBench` can print the diagnostics when
  `CUESEEKER_BENCH_FTS_VOCAB=1` is set.
- The diagnostics report unique vocabulary terms, total term occurrences,
  high-frequency terms, and query-term vocabulary scale.
- This step is observability work. It should explain query cost and index
  pollution; it is not expected to directly improve default Search timings.

Pre-change benchmark:

| Query | Deferred hot avg ms | Deferred raw ms | Complete hot avg ms | Complete raw ms |
| --- | ---: | --- | ---: | --- |
| `大丈夫` | 47.40 | 48.35, 48.46, 48.77, 46.65, 44.75 | 43.83 | 43.40, 43.67, 43.94, 44.02, 44.13 |
| `今日` | 63.04 | 62.94, 63.06, 62.96, 63.33, 62.92 | 112.76 | 116.80, 121.40, 108.63, 109.59, 107.40 |
| `の` | 8.78 | 9.06, 9.02, 8.46, 8.69, 8.66 | 463.04 | 460.65, 467.39, 461.35, 462.68, 463.12 |

Diagnostic snapshot before implementation:

| Metric | Value |
| --- | ---: |
| Unique vocabulary terms | 11,337 |
| Total term occurrences | 9,135,487 |
| Total term-document references | 1,481,292 |

Most frequent terms before implementation:

| Term | Document count | Occurrences |
| --- | ---: | ---: |
| `0` | 8,286 | 1,016,421 |
| `30` | 8,300 | 871,220 |
| `15` | 8,293 | 726,013 |
| `b` | 8,314 | 580,844 |
| `7` | 8,283 | 580,805 |
| `23` | 8,282 | 580,802 |
| `m` | 8,568 | 145,494 |
| `い` | 25,403 | 117,454 |
| `て` | 23,122 | 102,581 |
| `的` | 24,841 | 93,126 |
| `た` | 21,748 | 91,457 |
| `の` | 20,770 | 88,481 |

Read:

- The top terms show obvious ASS markup/style token pollution such as numbers
  and tag letters. That is useful evidence for later tokenizer or ASS text
  cleaning work, but Step 8 only makes the diagnosis repeatable.
- `の` is both a common query and a very frequent indexed token, so its high
  result volume is expected.
- The CJK benchmark queries are segmented into per-character FTS terms, which
  explains why diagnostics should report query-term scale rather than only the
  raw query string.

Post-change benchmark with default vocabulary diagnostics disabled:

| Query | Deferred hot avg ms | Deferred raw ms | Complete hot avg ms | Complete raw ms |
| --- | ---: | --- | ---: | --- |
| `大丈夫` | 49.88 | 50.72, 49.42, 50.01, 49.44, 49.80 | 46.90 | 46.84, 46.53, 46.46, 47.51, 47.15 |
| `今日` | 62.99 | 63.68, 64.38, 64.41, 61.96, 60.53 | 114.90 | 118.82, 113.33, 112.96, 113.86, 115.55 |
| `の` | 8.89 | 9.00, 8.84, 8.86, 8.72, 9.01 | 472.36 | 480.01, 471.36, 469.74, 470.09, 470.62 |

Diagnostic command check:

Historical command; current `SearchBench` no longer supports deferred metadata
mode.

```bash
CUESEEKER_BENCH_FTS_VOCAB=1 CUESEEKER_BENCH_METADATA=deferred \
  .build/arm64-apple-macosx/debug/SearchBench \
  "/Users/weiyunjun/Library/Application Support/CueSeeker/CueSeeker.sqlite" \
  "の" 1000
```

The diagnostic output reported `の [exact] terms=1 docs=20770
occurrences=88481`, with the same top terms listed above.

Read after implementation:

- The default Search path does not create or query `fts5vocab`; diagnostics are
  off unless explicitly requested.
- The benchmark did not show a Search-speed improvement, which is expected for
  this observability-only step.
- The diagnostic itself took about `157.02 ms` on the measured local database,
  so it belongs in development, benchmark, or maintenance surfaces, not in the
  normal keystroke Search path.
- This historical implementation exposed the diagnostic in Settings under
  `Developer`. The current accepted Step 5 implementation keeps the diagnostic
  in Core and `SearchBench` only.
- The next optimization step should use this evidence when deciding whether FTS
  maintenance or tokenizer cleanup is worth pursuing.

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
