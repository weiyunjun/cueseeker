# Table View Rendering Virtualization Performance - Viewport Priority Refactor

Date: 2026-06-07

Human requirement:

- `docs/human/requirements/20260606-Feature-Table View Rendering Virtualization Performance.md`
- Covering requirement commit: `2fc4da93`

## Scope

Refactor the test Search table rendering and hydration path so fast scrollbar
dragging is governed by the current viewport, not by sequential loading from
row 0. This keeps the existing test table UI style and does not change the
production Search/Shiori card interface.

This record covers Step 0 through Step 4 from the narrowed
viewport-priority plan:

1. Freeze the table virtualization rules.
2. Keep the Search table row model sparse.
3. Make hydration viewport-priority and cancel obsolete work.
4. Add a Search result-ID window path so visible windows can load from indexed
   exact result order.
5. Draw table rows with fixed bounded height and clipped text.

## Pre-Change Data

Baseline was collected before code changes on production database copy:

`/private/tmp/cueuseeker-bench/CueSeeker-baseline.sqlite`

Visible-window first-screen searches, limit 240:

| Query | Warmup | Cold open + first search | Returned | Known total |
| --- | ---: | ---: | ---: | ---: |
| `今日` | 102.65 ms | 33.44 ms | 240 | 240 |
| `大丈夫` | 92.28 ms | 5.91 ms | 240 | 240 |
| `の` | 16.38 ms | 5.54 ms | 240 | 240 |

Exact searches, limit 240:

| Query | Warmup | Cold open + first search | Exact total |
| --- | ---: | ---: | ---: |
| `今日` | 95.97 ms | 91.09 ms | 1346 |
| `大丈夫` | 6.45 ms | 7.18 ms | 290 |
| `の` | 1392.17 ms | 709.61 ms | 23168 |

Targeted baseline:

- `swift test --jobs 1 --filter TableSandbox` passed 11 tests.
- Full `swift test --jobs 1` was unavailable during baseline because Xcode
  process spawning temporarily failed.

## Changes

- Added a result-ID index cache in `SubtitleDatabase` after exact search
  completion.
- Added an indexed visible-window search path that loads only the requested
  result-ID slice instead of scanning sequentially through prior offsets.
- Changed the test Search hydration path to use indexed windows when available
  and to show placeholders when a requested window is not available yet.
- Changed `TableSandboxVisibleSearchHydrator` to focus only visible pages,
  debounce rapid viewport changes, cancel obsolete in-flight work, and stop
  eager small-result completion.
- Kept Search row models sparse and capped hydrated rows to bound memory.
- Capped displayed table text to six lines and clipped drawing inside fixed
  row rectangles.
- Changed virtual row height mapping to fixed row height so `y -> row` and
  `row -> y` stay O(1), including very large row counts.

## Post-Change Verification

Targeted tests:

- Passed: `swift test --jobs 1 --filter TableSandbox`
  - 13 Testing tests passed.
- Passed: `swift test --jobs 1 --filter searchExactPageCachesResultIDIndexForVisibleWindows`
  - 1 Testing test passed.
- Passed: `swift test --jobs 1 --filter SubtitleTable`
  - 11 Testing tests passed.
- Passed: `swift test --jobs 1`
  - 7 XCTest tests passed.
  - 229 Testing tests passed.

Post-change SearchBench on the same database copy, visible-window first-screen
searches, limit 240:

| Query | Warmup | Cold open + first search | Returned | Known total |
| --- | ---: | ---: | ---: | ---: |
| `今日` | 111.51 ms | 32.89 ms | 240 | 240 |
| `大丈夫` | 77.86 ms | 4.73 ms | 240 | 240 |
| `の` | 11.76 ms | 4.63 ms | 240 | 240 |

Post-change exact searches, limit 240:

| Query | Warmup | Cold open + first search | Exact total |
| --- | ---: | ---: | ---: |
| `今日` | 109.07 ms | 89.94 ms | 1346 |
| `大丈夫` | 6.29 ms | 5.66 ms | 290 |
| `の` | 1298.08 ms | 724.25 ms | 23168 |

## Outcome

The automated checks support the intended direction:

- First-screen Search performance stayed in the baseline range.
- Exact Search performance stayed in the baseline range.
- The table model and renderer no longer require materializing all result rows
  to represent the scrollbar.
- Fast scroll hydration now prioritizes the current viewport and cancels stale
  viewport work.
- Large row-count scroll math is fixed-height O(1).

Human end-to-end acceptance is still required for the subjective scrollbar drag
feel in the macOS app.
