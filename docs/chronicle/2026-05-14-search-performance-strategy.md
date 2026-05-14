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

## Open Questions

- Should the first implementation search one subtitle file at a time, one
  Library block at a time, or use a hybrid batch strategy?
- Should total counts and file summaries be delayed, approximate, or computed
  asynchronously after first results are visible?
- How should duplicate line hits inside the same display time window affect
  highlighting and result selection?
- Which ranks should be persisted: Library block rank, subtitle-file rank,
  display-window rank, or all of them?
- Should FTS maintenance commands be exposed as diagnostics, Settings
  maintenance, or automatic post-indexing work?

## Next Update Trigger

Update this chronicle when the user asks to move from the search-performance
question path into a concrete implementation plan or when new timing evidence
changes the ranking of proposed optimizations.
