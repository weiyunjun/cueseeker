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

| Method | Feasibility | Engineering Effort | Likely Impact | Downside |
| --- | --- | --- | --- | --- |
| FTS `optimize` / incremental `merge` | High for maintenance after large reindex operations. | Low to medium. Add a maintenance command and measure before enabling automatic use. | Low to medium for current bottleneck; can reduce FTS segment merge cost and disk use. | Can take time because it reorganizes the FTS index; should not run in the foreground unexpectedly. |
| FTS `automerge`, `crisismerge`, `usermerge` tuning | Medium. SQLite exposes these controls, but their effects depend on write patterns. | Medium. Requires instrumentation around indexing and search after reindex. | Low to medium. Helps if many FTS segment b-trees accumulate. | Trades faster reads for slower writes; bad settings can make indexing pauses worse. |
| FTS prefix indexes | Medium only if prefix queries are a real hot path. | Medium because schema migration and FTS rebuild are required. | Medium for frequent prefix queries such as Latin `abc*`; low for exact CJK phrase cases. | Increases FTS index size and write cost. |
| FTS contentless or external-content tables | Medium. CueSeeker already stores cue text in ordinary tables, so duplicate FTS content may be removable. | Medium to high. Requires schema migration, rebuild, and consistency checks. | Mostly storage reduction; possible IO reduction. | More fragile consistency model. External-content FTS returns unpredictable results if the backing table and FTS index diverge. |
| FTS `detail` / `columnsize` reduction | Low to medium. Worth testing only after exact phrase, highlighting, and line-validation requirements are fixed. | Medium. Requires schema migration and semantic regression tests. | Mainly storage reduction; uncertain speed gain. | Reduces FTS capability or efficiency. `detail` settings can restrict long-token queries and slow or disable some positional operations. |
| Trigram tokenizer | Low for default search. | High if added safely, because it changes tokenization and index size. | Could help arbitrary substring search. | Does not match the current precise subtitle-search model by default; can greatly increase index size and has awkward behavior for short queries. |
| `fts5vocab` diagnostics | High as an investigation tool. | Low. Can be added as a diagnostic query or one-off tool. | Indirect. Helps explain high-candidate terms and CJK hot spots. | Does not speed search by itself. |
| Query-plan/index work for `ORDER BY` and `LIMIT` | High. This aligns with the Socratic direction. | Medium to high depending on schema changes. | High if stable order can be materialized and searched without a global sort. | Requires careful result-order semantics and migration. |
| Index sorting / early termination | Conceptually high, directly supported by search engines such as Lucene/Elasticsearch; in SQLite it must be modeled with ranks and ordered scans. | High. Requires data model and query-shape changes. | High for first visible results. | Total counts and complete summaries may become asynchronous or approximate until background completion. |
| Filterable/sortable/facet-style attributes | High conceptually. Library block, subtitle file, and time-window keys are natural filter/sort fields. | Medium to high. Requires materialized ranks and possibly diagnostic summary tables. | High for scoped or block-first search. | More index-time state to keep consistent with Library presentation. |
| Query/result cache | Medium. Useful after the search model is stable. | Low to medium. | Medium for repeated or incremental searches. | Cache invalidation around indexing, folder removal, and setting changes can become subtle. |

Near-term priority should remain:

1. Materialize stable Library/file/time order at index time.
2. Explore line-level FTS recall that maps to display time windows.
3. Return first completed file or Library block before full-corpus completion.
4. Move total counts and summaries off the first-visible-results path.
5. Treat FTS maintenance commands and diagnostics as supporting work, not the
   main optimization path.

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
