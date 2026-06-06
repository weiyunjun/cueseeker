# Table View Rendering Virtualization Performance - Phase 2 Row Height Cache

Human requirement:

- `docs/human/requirements/20260606-Feature-Table View Rendering Virtualization Performance.md`

## Scope

Phase 2 optimizes repeated dynamic row-height work in the Test Search and Test
Shiori table direction. It does not change the production Search/Shiori card
UI, and it does not remove the first-pass cost of measuring every row that
AppKit asks about.

## Pre-Change Performance Data

The Phase 2 reference benchmark showed that TextKit row-height measurement is
linear when every row is measured, while a cached repeat pass can be near zero:

| Rows | Uncached height | Cached first pass | Cached repeat |
| ---: | ---: | ---: | ---: |
| 100 | 12.258 ms | 10.115 ms | 0.010 ms |
| 500 | 49.209 ms | 48.420 ms | 0.048 ms |
| 1000 | 97.983 ms | 98.487 ms | 0.100 ms |
| 3000 | 298.782 ms | 298.583 ms | 0.336 ms |
| 10000 | 1004.875 ms | 1010.594 ms | 1.027 ms |

An intermediate dictionary-based cache reduced repeat work but added too much
first-pass overhead in larger runs, so it was replaced with a row-indexed array
cache.

## Changes

- Added `SubtitleTableRowHeightCache`, scoped to the table sandbox.
- Cached row heights by row index, row identity/content, and rounded column
  widths.
- Pruned stale row-height cache entries when the row snapshot changes.
- Avoided full row-height invalidation when the cues column width key is
  unchanged after a frame notification.
- Extended table rendering performance logs with `cacheHits` and
  `cacheMisses` for height-measurement batches.
- Added tests for row-height reuse, width/content invalidation, and cache
  pruning.

## Verification

- `swift test --filter SubtitleTableRowHeightCache` succeeded.
- `swift test` succeeded.
- Phase 2 comparison benchmark:

| Rows | Uncached | First cache fill | Cached repeat |
| ---: | ---: | ---: | ---: |
| 100 | 13.541 ms | 3.998 ms | 0.018 ms |
| 500 | 20.325 ms | 19.938 ms | 0.084 ms |
| 1000 | 39.351 ms | 40.545 ms | 0.174 ms |
| 3000 | 122.573 ms | 120.600 ms | 0.556 ms |
| 10000 | 408.913 ms | 421.055 ms | 1.943 ms |

## Outcome

Phase 2 is effective for repeated row-height queries: the 10000-row cached
repeat pass was about 1.943 ms in the comparison benchmark. First cache fill
remains roughly the same class as uncached measurement and can be slightly
slower because it writes cache entries. The remaining large stall risk is
therefore first-pass/full-range work, which should be handled by the next phase
with visible-window or chunked measurement rather than more cache-only tuning.
