# Search Performance Strategy Discovery

Status: Active

Date: 2026-05-14

## Context

The user continued the explicitly started Socratic architecture alignment
session after the database freelist discussion. The focus moved from database
file size to why Search feels slow even though SQLite FTS5 is already in use.

This chronicle records how the discussion produced a candidate search
projection strategy. It does not authorize implementation by itself.

## Question Path

The session narrowed through these steps:

1. The user asked whether FTS itself explains the slow search feel.
2. Existing timing notes showed that the measured slow case spent most time in
   `SubtitleDatabase.searchPage`, especially `db.sort_results`, not in SwiftUI
   rendering.
3. The user asked what each measured phase means. This separated FTS candidate
   recall from cue-line loading, line-level validation, result sorting, page
   slicing, and file-summary generation.
4. The user challenged the group-level FTS design: if cross-line matching is
   not allowed, the searchable unit should be the original subtitle line.
5. The user then reframed time as a first-class search identity: a matched raw
   line should map to its subtitle file and exact time window, then display
   should deduplicate by that window.
6. The user connected Search order to Library's already-flattened folder/work
   projection. The Library block order, subtitle-file order, and in-file time
   order can be known during indexing.
7. The user asked whether Search can return results per ASS file as soon as a
   file is searched instead of waiting for the whole corpus.
8. After external research was requested, the discussion separated
   product-model optimizations discovered through questioning from lower-level
   FTS/database maintenance methods.
9. The user accepted an implementation sequence, added English prefix search as
   an important scenario, and required a benchmark-first workflow using
   `大丈夫`, `今日`, and `の` before and after each optimization step.

## Evidence Surfaced

The prior timing snapshot recorded:

- First visible result row: `1328.66 ms`.
- `database.searchPage`: `1026.52 ms`.
- `db.sort_results`: `566.72 ms`.
- `db.fts_batch`: `163.12 ms`.
- `db.cue_lines`: `130.64 ms`.
- `db.line_validation`: `110.92 ms`.
- `db.file_summaries`: `51.59 ms`.

The existing implementation searches cue groups, then loads cue lines for
multi-line groups to enforce no-cross-line matching after FTS recall. This makes
the search projection and the final product semantics misaligned.

## Emerging Insight

The likely primary optimization is to align the indexed search projection with
the product result model:

- Search recall should be able to operate at raw cue-line granularity.
- Matched lines should point to a stable display identity:
  `(subtitle_file_id, start_ms, end_ms)`.
- Display results should remain merged cue groups or time windows.
- Result order should be materialized during indexing:
  Library block rank, subtitle-file rank, then cue time.
- Search can then produce results in product order and emit completed files or
  Library blocks before the full corpus is searched.

This is different from treating Search slowness as a generic FTS tuning problem.
FTS remains important, but the bigger design issue is that the current query
does global post-processing to recover product order and line-level semantics.

## External Research Split

External research added supporting optimization categories that were not the
core Socratic discovery:

- FTS `optimize` and incremental `merge`.
- FTS merge-policy tuning through `automerge`, `crisismerge`, and `usermerge`.
- FTS prefix indexes.
- FTS contentless or external-content tables.
- FTS `detail` and `columnsize` storage tuning.
- Trigram tokenization.
- `fts5vocab` diagnostics.
- General index-assisted `ORDER BY` / `LIMIT` planning.
- Index sorting and early termination as used by Lucene/Elasticsearch-style
  search systems.
- Filterable, sortable, and facet-style materialized attributes.
- Query/result caching.

These methods should be evaluated as supporting tools. They do not replace the
product-model direction discovered in the questioning path.

## Implementation Evidence

The implementation evidence refined the Socratic diagnosis:

- Hybrid line-level FTS recall was a negative optimization for the measured
  speed goal. It was better than the pure line-level attempt, but worse than the
  baseline and later rolled back.
- Materialized subtitle search-order rows directly addressed the previously
  dominant sort phase. After this step, diagnostics for `今日` reported
  `orderSource=materialized` and `sort_results` at about `1 ms`.
- The accepted current baseline is group-level FTS recall plus materialized
  product ordering and line-level validation for multi-line cue groups.
- The remaining slow phases now line up with the next discussion-derived
  directions: early result emission, delayed summaries/counts, and further
  index support for ordered paging.
- The next accepted implementation pass combined two adjacent Socratic ideas:
  ordered file/block early return and delayed total-count/file-summary
  metadata. The concrete first version does not stream one completed ASS file
  at a time. Instead, it uses materialized product order to return the first
  visible page plus one lookahead result, then refreshes exact total count and
  complete summaries in the background.
- Benchmark evidence supported this narrower version for large result sets.
  With deferred metadata enabled, `今日` improved from `117.07 ms` to
  `67.28 ms`, and `の` improved from `824.51 ms` to `43.10 ms` for the visible
  page benchmark. `大丈夫` stayed in the same fast range because it has fewer
  than the requested page limit and therefore still completes exact metadata.
- The `ORDER BY` / `LIMIT` index-support step was investigated next because the
  current SQLite plan still reports `USE TEMP B-TREE FOR ORDER BY`. A database
  copy proved that forcing product-order index scans is the wrong tradeoff for
  the current FTS path: it removed the temporary sort but made `の LIMIT 1001`
  take about `87.44 s` instead of about `0.03 s` for the current FTS-driven SQL.
  This refined the strategy again: under the current SQLite FTS shape, product
  order should remain a presentation/order key after FTS recall rather than the
  primary driver for term matching.
- The index-sorting / early-termination step then found a better fit for
  SQLite FTS5: assign FTS `rowid` in materialized product order when rebuilding
  cue-group FTS rows, then query with `ORDER BY f.rowid`. This keeps FTS as the
  term-matching driver while letting SQLite return product-ordered matches
  without a separate temporary product-order sort. The measured `の` first-page
  benchmark improved from `43.10 ms` to `8.93 ms`, and complete metadata
  improved from `830.48 ms` to `572.56 ms`.

## Open Questions

- How should duplicate line hits inside the same display time window affect
  highlighting and result selection?
- Should future Search stream file-complete groups into the UI, or is
  page-level early return enough once exact metadata refresh is in the
  background?
- Should FTS maintenance commands be exposed as diagnostics, Settings
  maintenance, or automatic post-indexing work?

## Accepted Next Workflow

The user accepted the following implementation workflow:

1. Update project documentation, including this chronicle.
2. Implement accepted optimizations in the documented order, with query/result
   cache moved to the end because cache invalidation should not hide earlier
   semantic bugs.
3. Before code changes, benchmark the current implementation by searching
   `大丈夫`, `今日`, and `の` five times each and recording average timings.
4. After each optimization step, rerun the same benchmark before beginning the
   next step.
5. For query/result cache, clear cache state between benchmark query groups and
   run each query five times to separate warm-cache effects from cross-query
   contamination.
6. Summarize benchmark data across all steps.

## Next Update Trigger

Update this chronicle when the user asks to move from the search-performance
question path into a concrete implementation plan or when new timing evidence
changes the ranking of proposed optimizations.
