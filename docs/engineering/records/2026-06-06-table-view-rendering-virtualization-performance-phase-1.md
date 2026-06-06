# Table View Rendering Virtualization Performance — Phase 1 Row Model Reuse

Human requirement:

- `docs/human/requirements/20260606-Feature-Table View Rendering Virtualization Performance.md`

## Scope

Phase 1 reduces repeated row-model derivation for the Test Search and Test
Shiori table views. It does not change the production Search/Shiori card UI and
does not yet optimize row-height measurement or visible-window rendering.

## Pre-Change Performance Data

Formal Search comparison data from `logs/search-e2e/search-e2e-2026-06-06.jsonl`:

- `大丈夫`: completed with 290 rendered rows; exact completion was about
  113.026 ms.
- `今日`: a visible-page append reached 1000 rendered rows; that append event
  was about 1241.711 ms.

Local row-derivation microbenchmark using real subtitle paths from
`/Volumes/Seagate/影视/It's MyGO!!!!!`:

| Rows | Current uncached map | Cached title map |
| ---: | ---: | ---: |
| 100 | 51.416 ms | 4.602 ms |
| 500 | 152.659 ms | 6.876 ms |
| 1000 | 305.974 ms | 10.494 ms |
| 3000 | 921.459 ms | 20.589 ms |
| 10000 | 3104.973 ms | 56.563 ms |

The benchmark shows that repeatedly resolving display titles during SwiftUI
body refresh is large enough to explain visible waits on medium and large
result sets.

## Changes

- Added `TableSandboxRowModelStore`, a test-table-only row model cache.
- Test Search and Test Shiori now observe their `@Published` source arrays and
  update cached row snapshots only when source data changes.
- Display titles are cached by subtitle path, so repeated rows from the same
  subtitle file do not repeatedly enumerate the file system.
- Rows are cached by source identity/content, so unchanged rows are reused
  across table updates.
- `SubtitleTableView` now receives a `rowsVersion`; the AppKit coordinator uses
  that version instead of full-array equality on every SwiftUI update.
- Added tests covering display-title reuse, stable versions for unchanged rows,
  and version changes when row content changes.

## Verification

- `swift test --filter TableSandboxRowModelStore` succeeded.
- `swift test` succeeded.
- Post-change cached row-derivation reference on the same real subtitle paths:
  - 100 rows: 22.896 ms.
  - 500 rows: 8.023 ms.
  - 1000 rows: 11.111 ms.
  - 3000 rows: 23.877 ms.
  - 10000 rows: 68.402 ms.

## Outcome

Phase 1 shifts row derivation out of SwiftUI body evaluation and introduces the
first Excel-style reuse layer for the test table direction. Phase 2 should use
the table-rendering JSONL to decide whether the next bottleneck is row-height
measurement, full height invalidation, or reload granularity.
