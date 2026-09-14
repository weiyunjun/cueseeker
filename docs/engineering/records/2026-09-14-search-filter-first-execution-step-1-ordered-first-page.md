# Search Filter-First Execution — Step 1: Ordered First Page

## Human-Owned Source

- `docs/human/requirements/20260914-Feature-Search Filter-First Execution And Ordered First Page.md` (sections 1, 2.1, 3.2 for the single-pass part, 5)
- `docs/human/design/UI Design System.md` (Search / Excerpt Table Layout)

## Baseline (commit `5265a639`, before any code change)

Database level, release `SearchBench`, limit 100, on a read-only copy of the live database (schema 47, 340,180 cue groups, 647,439 cue lines, 641 subtitle files):

| Query | Visible window warmup / hot median | Exact warmup / hot median | Results / files |
| --- | --- | --- | --- |
| `の` | 1432 ms / 87.9 ms | 3938 ms / 3176 ms | 77,145 / 638 |
| `今` | 29 ms / 23 ms | 182 ms / 171 ms | 10,145 / 636 |
| `大丈夫` | 13 ms / 10 ms | 38 ms / 36 ms | 1,476 / 499 |

App level, Debug E2E controller (click the Search field, Cmd+A, query pasted with Cmd+V from `pbcopy`), `logs/search-e2e/search-e2e-2026-09-14.jsonl`, `CUESEEKER_PERF_WATCHDOG=1 CUESEEKER_PERF_RUNLOOP=1`:

| Query | First page e2e / db | Completed e2e / db | Main-thread gaps ≥250 ms during completion |
| --- | --- | --- | --- |
| `大丈夫` | 326 / 206 ms | 574 / 225 ms | none |
| `今` | 584 / 473 ms | 1315 / 672 ms | none |
| `の` | 755 / 626 ms | 6454 / 5063 ms | 12 gaps, max 429 ms |
| `の` hot repeat | 216 / 105 ms | 5618 / 4559 ms | gaps up to 736 ms |

Root cause found while reading the code and the logs: commit `a95016be` (2026-07-25, incremental indexing) broke the Step 9 invariant that FTS rowid order equals the display order, and switched the Search SQL to `ORDER BY display_title ...`. Every page then read and sorted every hit before returning the first row, and the exact scan re-sorted the full hit set for each 5,000-row `OFFSET` batch. The first page for `の` went from 3 ms (07-16) to 650–1800 ms (07-25 onward); the exact scan became superlinear.

## Implementation

- Added `SearchFTSRows`: the FTS rowid now encodes the subtitle file and the cue group's time position inside it (`subtitleFileID << 24 | sequence`, sequence by start time, end time, original position). A file's rows always form one rowid range in time order, whenever the file was indexed.
- `IndexingDatabase` writes that rowid on every publication and no longer rebuilds the whole FTS table after indexing; the derived-index rebuild keeps only the Search order rows.
- Schema 48 (`migrateSchema47To48`) rewrites every FTS row with the encoded rowid once; 4.7 s on the live-size database, 340,180 rows. Partial fixture schemas without the Search tables skip the rewrite.
- `SearchDatabase.searchPage` now: loads the display rank of every in-scope file (641 rows), reads only the hit rowids from the FTS index (no content row), orders them by file rank then rowid in memory, and hydrates candidates in chunks by `rowid IN (...)`. The visible window stops after the first chunk that fills the page; the exact scan walks the same ordered list once, with no `OFFSET` and no re-sort. Language and watch-state filters apply on the hydration query. A single-file scope adds a rowid range to the FTS read.
- Diagnostics: `statement_prepare` is replaced by `file_ranks` and `fts_hits`; `fts_batch` and `sort_results` keep their names and fields.

## Verification

- `swift test --filter CueSeekerCoreTests`: all 302 tests pass, including the new `migratesSchema47ByEncodingFTSRowIDsByFileAndTime`. The first full run caught two things: hydrated candidates had lost their watch state (the shared row parser does not read that column; fixed with a parser that does), and the storage-compaction test measured the main file before the smaller write volume of the new rebuild had triggered a checkpoint (the test now checkpoints before measuring).
- Order equivalence on the real data (migrated copy): for `の`, `今` and `大丈夫` the full ordered cue-group id list under the new order (file rank, rowid) equals the previous SQL order exactly (76,603 / 7,841 / 1,478 groups).
- SearchBench on the migrated copy, same three queries; every count, file summary and page field is identical to the baseline:

| Query | Visible window warmup / hot median | Exact warmup / hot median |
| --- | --- | --- |
| `の` | 52 ms / 10.0 ms (was 1432 / 87.9) | 1845 ms / 1090 ms (was 3938 / 3176) |
| `今` | 6.4 ms / 4.2 ms (was 29 / 23) | 156 ms / 146 ms (was 182 / 171) |
| `大丈夫` | 8.0 ms / 4.9 ms (was 13 / 10) | 38 ms / 34 ms (was 38 / 36) |

- App level, same procedure as the baseline, after the live database migrated to schema 48 (backup taken first as `CueSeeker.sqlite.backup-20260914-before-schema-48-fts-rowids`):

| Query | First page e2e / db | Completed e2e / db |
| --- | --- | --- |
| `大丈夫` | 161 / 36 ms (was 326 / 206) | 412 / 187 ms (was 574 / 225) |
| `今` | 139 / 27 ms (was 584 / 473) | 803 / 594 ms (was 1315 / 672) |
| `の` | 165 / 40 ms (was 755 / 626) | 4727 / 2832 ms (was 6454 / 5063) |
| `の` hot repeat | 150 / 35 ms (was 216 / 105) | 4553 / 2291 ms (was 5618 / 4559) |

- Result totals and file counts unchanged in every run. The 6-scroll and 3-scroll sequences loaded further pages without stale or duplicate rows (captures `step1-ima.png`, `step1-no.png`).
- Main-thread gaps during the `の` exact completion are now fewer but longer (up to 1.97 s): the database delivers batches faster and each progress tick still re-installs every accumulated result on the main thread. That is Step 2's target (requirement section 3.2, progress increments), not a regression of this step's metric.

## Outcome

Matched expectations for the first-page metric: the first page no longer reads or sorts hit rows, and the exact scan is a single pass. Remaining gap to the requirement: the progress snapshot still republishes all results (Step 2), and filters are still applied after the scan (Steps 3 and 4).
