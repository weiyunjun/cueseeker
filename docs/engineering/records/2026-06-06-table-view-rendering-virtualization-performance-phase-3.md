# Table View Rendering Virtualization Performance - Phase 3 Visible Row Heights

Human requirement:

- `docs/human/requirements/20260606-Feature-Table View Rendering Virtualization Performance.md`

## Scope

Phase 3 reduces first-pass row-height work in the Test Search and Test Shiori
table direction. It keeps all rows loaded in memory, but only measures exact
TextKit row heights for the currently visible rows plus an overscan window.
Rows outside that window use an estimated height until they enter the window.

This does not change the production Search/Shiori card UI.

## Pre-Change Performance Data

The Phase 3 pre-change reference benchmark compared the current all-row exact
height path with the cost of measuring an 80-row visible window:

| Rows | Exact all rows | Exact visible 80 rows |
| ---: | ---: | ---: |
| 100 | 5.279 ms | 3.076 ms |
| 500 | 19.811 ms | 3.021 ms |
| 1000 | 39.167 ms | 3.092 ms |
| 3000 | 118.427 ms | 2.922 ms |
| 10000 | 402.433 ms | 3.049 ms |

The data shows the remaining Phase 2 bottleneck is exact height work scaling
with total row count rather than visible row count.

## Changes

- Added `SubtitleTableHeightInvalidationWindow` to calculate visible-row
  invalidation windows with bounded overscan.
- `SubtitleTableView` now returns an estimated row height for rows outside the
  current exact-height window.
- Initial load, row changes, frame changes, and scroll bounds changes now
  invalidate only the visible row-height window.
- Exact row-height measurement still uses the Phase 2 row-height cache for rows
  inside the window.
- Table-rendering logs now include `reason` for visible height invalidations
  and `estimatedRows` for estimated-height batches.
- Added tests for visible-window expansion, table-bound clamping, and empty
  visible-row rejection.

## Verification

- `swift test --filter SubtitleTableHeightInvalidationWindow` succeeded.
- `swift test --filter SubtitleTable` succeeded.
- `swift test` succeeded.
- Phase 3 comparison benchmark:

| Rows | Exact all rows | Phase 3 initial | Phase 3 repeat |
| ---: | ---: | ---: | ---: |
| 100 | 5.551 ms | 3.433 ms | 0.017 ms |
| 500 | 20.663 ms | 3.322 ms | 0.073 ms |
| 1000 | 40.566 ms | 3.269 ms | 0.132 ms |
| 3000 | 123.165 ms | 3.787 ms | 0.388 ms |
| 10000 | 417.873 ms | 4.535 ms | 1.298 ms |

## Outcome

Phase 3 makes initial row-height work scale with the visible window instead of
the total loaded result count. In the reference benchmark, the 10000-row initial
path fell from about 417.873 ms to about 4.535 ms.

The remaining risk is visual settling while scrolling: rows outside the exact
window use estimated heights until they enter the window. The next performance
phase should use real table-rendering JSONL and owner observation to decide
whether row reload granularity, cell configuration, or scroll-settling needs
more work.
