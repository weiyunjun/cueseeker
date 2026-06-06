# Table View Rendering Virtualization Performance — Phase 0 Instrumentation

Human requirement:

- `docs/human/requirements/20260606-Feature-Table View Rendering Virtualization Performance.md`

## Scope

Phase 0 establishes table-specific performance observability before any
virtualization optimization.

The current Search E2E logs already cover the production Search pipeline and can
be used as the formal Search comparison for first visible result and exact
completion timings. They do not measure the test table's row mapping,
`NSTableView` reloads, row-height measurement, or cell reuse behavior, so this
phase adds a separate table-rendering JSONL stream.

## Changes

- Added `TableRenderingPerformanceLogger`, enabled only by
  `CUESEEKER_PERF_TABLE=1` or the broader `CUESEEKER_PERF=1`.
- The logger writes JSONL under `logs/table-rendering/`.
- Test Search and Test Shiori now label table instances as `test-search` and
  `test-shiori`.
- Test Search and Test Shiori row mapping now records `rows_mapped` events with
  source count, mapped row count, and elapsed milliseconds.
- `SubtitleTableView.Coordinator` now records:
  - `rows_compared` for whole-array equality checks.
  - `reload_data` for whole-table reloads.
  - `height_invalidated_all` for full row-height invalidation.
  - `height_measure_batch` for batched TextKit row-height measurements.
  - `cell_configure_batch` for batched visible cell configuration.

## Phase 0 Test Data Plan

Search baseline queries:

- `大丈夫` — medium result set.
- `巨人` — medium-large result set.
- `今日` — large result set.
- `今` — pressure result set.

Shiori baseline:

- Current real Shiori data.
- Optional owner-provided pressure data at roughly 100, 500, 1000, and 3000 rows.

The table logs should be collected alongside `logs/search-e2e/` so Search
pipeline timings can be compared with the table rendering costs for the same
queries.

## Verification

- `swift build --target CueSeekerApp` succeeded.
- `swift test` succeeded.

## Outcome

Phase 0 instrumentation is in place. No virtualization optimization has been
performed yet; the next step is to run the fixed Search/Shiori data set with
`CUESEEKER_PERF_TABLE=1` and compare the table-rendering JSONL against the
existing Search E2E JSONL.
