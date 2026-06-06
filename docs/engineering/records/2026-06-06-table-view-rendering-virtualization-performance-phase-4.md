# Table View Rendering Virtualization Performance - Phase 4 Append Updates

Human requirement:

- `docs/human/requirements/20260606-Feature-Table View Rendering Virtualization Performance.md`

## Scope

Phase 4 reduces AppKit table update work for Test Search and Test Shiori when
new rows are appended. It keeps all rows loaded in memory, preserves the Phase
3 visible-row height virtualization, and avoids full `reloadData` for append
only updates.

This does not change the production Search/Shiori card UI.

## Pre-Change Performance Data

The Phase 4 append benchmark modeled paged Search loading. Before this phase,
each append update used full table reload behavior, so row update callbacks
scaled with the sum of all cumulative page sizes:

| Total rows | Page size | Reload callbacks | Insert callbacks | Ratio |
| ---: | ---: | ---: | ---: | ---: |
| 1000 | 100 | 5500 | 1000 | 5.50x |
| 3000 | 100 | 46500 | 3000 | 15.50x |
| 10000 | 100 | 505000 | 10000 | 50.50x |
| 10000 | 250 | 205000 | 10000 | 20.50x |
| 10000 | 500 | 105000 | 10000 | 10.50x |

A separate probe showed that detecting append by doing an extra full prefix
comparison in `SubtitleTableView.Coordinator` would be too expensive:

| Total rows | Page size | Prefix comparisons | Prefix probe time |
| ---: | ---: | ---: | ---: |
| 10000 | 100 | 495000 | 62.450 ms |
| 10000 | 250 | 195000 | 24.114 ms |
| 10000 | 500 | 95000 | 12.048 ms |

## Changes

- Added `TableSandboxRowsUpdate` to represent `none`, `append`, and `reload`
  row update plans.
- `TableSandboxRowModelStore` now derives the update plan while it is already
  mapping rows, avoiding an extra Coordinator-level prefix comparison.
- Test Search and Test Shiori pass the update plan into `SubtitleTableView`.
- `SubtitleTableView.Coordinator` now uses `insertRows` for append-only
  updates and falls back to `reloadData` for reload updates or invalid append
  state.
- Append updates preserve existing selection, hover, and row-height cache
  state; reload updates still clear stale row-scoped state.
- Table-rendering logs now include `insertedRows` for append updates and
  `rows_mapped.reason` for the row update plan.
- Added row model store tests covering append and reload update plans.

## Verification

- `swift test --filter TableSandboxRowModelStore` succeeded.
- `swift test --filter TableSandboxRowModelStore --filter SubtitleTable`
  succeeded.
- `swift test` succeeded.
- Phase 4 post-change model benchmark:

| Total rows | Page size | Reload callbacks avoided | Insert callbacks | Ratio |
| ---: | ---: | ---: | ---: | ---: |
| 1000 | 100 | 5500 | 1000 | 5.50x |
| 3000 | 100 | 46500 | 3000 | 15.50x |
| 10000 | 100 | 505000 | 10000 | 50.50x |
| 10000 | 250 | 205000 | 10000 | 20.50x |
| 10000 | 500 | 105000 | 10000 | 10.50x |

## Outcome

Phase 4 makes append-only table updates scale with newly inserted rows instead
of the total loaded row count. The largest benchmark case avoids 505000
reload-style callbacks and inserts only 10000 rows across the same paged load.

This phase does not eliminate all repeated row mapping work in
`TableSandboxRowModelStore`; it focuses on the AppKit update path. If further
real JSONL data shows stalls during paged loading, the next phase should decide
whether to make row model updates incremental as well.
