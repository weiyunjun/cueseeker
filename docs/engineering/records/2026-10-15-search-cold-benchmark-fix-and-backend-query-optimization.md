# Search Cold Benchmark Fix and Backend Query Optimization

- **Date**: 2026-10-15
- **Requirement**: `docs/human/requirements/20261015-Performance-Search Cold Benchmark Fix And Backend Query Optimization.md`
- **Schema Version**: `54 -> 55`

## 1. True-Cold Benchmark Fix (`SearchBench --headless-cold`)

### Root Causes of Prior Warm-Cache Leakage
1. `SQLiteDatabase.configureConnection` enabled `PRAGMA mmap_size = 268435456` (256 MB `mmap`). On macOS XNU, `fcntl(fd, F_NOCACHE, 1)` only applies to `read`/`pread` syscalls and is ignored by virtual memory `mmap` page faults.
2. On macOS XNU, `F_NOCACHE` only prevents newly read pages from entering the Unified Buffer Cache (UBC); it does not evict or bypass pages already resident in UBC for an existing `vnode`.

### Fix
1. `SQLiteDatabase(..., directIO: true)` applies `F_NOCACHE=1` and `F_RDAHEAD=0` on the SQLite file descriptor immediately after `sqlite3_open_v2` (before any `PRAGMA` reads page 1) and sets `PRAGMA mmap_size = 0`.
2. `SearchBench --headless-cold` creates a fresh temporary database file per query (`makeUncachedDatabaseSnapshot`), setting `fcntl(dstFd, F_NOCACHE, 1)` before writing any bytes so the new `vnode` starts with zero pages in XNU UBC, and reports **5-round Average (平均值)** alongside `Raw` per-round arrays across both End-to-End and Pure Backend (DB Query vs. MainActor Commit) tables.

---

## 2. Plan A + Plan B Backend & State Commit Optimizations

1. **Schema 55 Covering Index (`idx_subtitle_cue_lines_fts_covering`) & File Metadata Preloading**:
   - Added `fts_rowid` and `language_mask` (`en=1, ja=2, zh=4, zh-Hans=8, zh-Hant=16, unknown=32`) to `subtitle_cue_lines` and created `idx_subtitle_cue_lines_fts_covering ON subtitle_cue_lines(fts_rowid, display_order, event_index, id, cue_group_id, start_ms, end_ms, language_mask, content)`.
   - Preloaded file-level metadata (`subtitle_files`, `subtitle_video_matches`, `video_files`, `library_watch_states`, `subtitle_search_order_rows`) once per search in `searchFileRanks`.
   - Replaced per-batch 6-table joins (`searchCandidates`), `subtitle_cue_lines` table lookups (`cueLineRecords`), and `subtitle_cue_line_languages` queries (`CueLineLanguages.languages`) with a single sequential index-only scan (`searchCoveringCueLines`) over `idx_subtitle_cue_lines_fts_covering`.
2. **In-Memory CPU & State Commit Optimizations**:
   - `SearchQueryPlanner.matches`: Added UTF-8 fast path skipping `NSString` bridging when fullwidth space (`0xE3 0x80 0x80`) is absent and using contiguous UTF-8 byte scanning.
   - `SubtitleCueTimeRangeDisplay.text`: Replaced `String(format: "%02d:%02d:%02d", ...)` with a 100-entry precomputed two-digit lookup table.
   - `CueFacetSnapshot`: Replaced `Dictionary(grouping:)` temporary array allocations with single-pass counting and added an O(1) slice fast path in `filteredCueIDs` when `filter.isEmpty`.
   - `SearchStore+Execution`: Replaced `self.searchResults.count` (which triggered a 76,817-element array materialization on `MainActor` during performance logging) with `self.loadedSearchResultCueIDs.count`, and pre-reserved dictionary capacities in `CueContentStore.install`.

---

## 3. True-Cold Benchmark Comparison (5 Rounds Average, 1.0 GB DB, Scope `/Volumes/Seagate/影视`)

### Pre-Optimization Baseline (Commit `f111db1`)

#### 1. End-to-End Full Chain Cold Benchmark (5 Rounds Average, incl. 100ms Debounce)
| Query | Total Results | Files | 1st Screen Avg | 1st Screen Raw (ms) | Full Complete Avg | Full Complete Raw (ms) |
| --- | ---: | ---: | ---: | --- | ---: | --- |
| `大丈夫` | 1462 | 498 | **241.18 ms** | 235.16, 240.25, 203.62, 283.54, 243.34 | **665.22 ms** | 601.00, 660.54, 650.20, 737.14, 677.21 |
| `今日` | 2300 | 497 | **228.23 ms** | 217.89, 248.10, 204.80, 242.76, 227.60 | **764.79 ms** | 825.58, 748.37, 781.76, 783.40, 684.84 |
| `の` | 76817 | 637 | **135.59 ms** | 127.99, 141.34, 133.82, 125.35, 149.43 | **2276.84 ms** | 1969.57, 1896.03, 2006.39, 3755.54, 1756.65 |

#### 2. Pure Backend Breakdown (5 Rounds Average, excl. Debounce)
| Query | Backend 1st Screen Avg | Backend 1st Raw (ms) | Pure Backend Full Avg | DB Query Avg | MainActor Commit Avg | Pure Backend Full Raw (ms) |
| --- | ---: | --- | ---: | ---: | ---: | --- |
| `大丈夫` | **136.80 ms** | 130.29, 135.24, 101.50, 178.66, 138.31 | **560.84 ms** | 559.87 ms | 0.96 ms | 496.13, 555.53, 548.08, 632.27, 572.18 |
| `今日` | **124.97 ms** | 114.45, 143.09, 99.78, 141.62, 125.94 | **661.53 ms** | 660.10 ms | 1.43 ms | 722.14, 643.35, 676.73, 682.26, 583.18 |
| `の` | **32.01 ms** | 22.98, 36.85, 31.32, 20.59, 48.30 | **2173.26 ms** | 2101.39 ms | 71.86 ms | 1864.56, 1791.53, 1903.89, 3650.79, 1655.51 |

### Post-Optimization Results (Schema 55)

#### 1. End-to-End Full Chain Cold Benchmark (5 Rounds Average, incl. 100ms Debounce)
| Query | Total Results | Files | 1st Screen Avg | 1st Screen Raw (ms) | Full Complete Avg | Full Complete Raw (ms) |
| --- | ---: | ---: | ---: | --- | ---: | --- |
| `大丈夫` | 1462 | 498 | **128.29 ms** (-46.8%) | 124.60, 130.96, 137.75, 121.16, 126.98 | **158.43 ms** (-76.2%) | 155.43, 161.34, 166.80, 151.25, 157.32 |
| `今日` | 2300 | 497 | **138.91 ms** (-39.1%) | 126.67, 137.31, 121.94, 120.95, 187.69 | **187.28 ms** (-75.5%) | 162.70, 173.45, 158.17, 156.56, 285.54 |
| `の` | 76817 | 637 | **129.64 ms** (-4.4%) | 140.08, 131.81, 127.52, 123.63, 125.15 | **653.14 ms** (-71.3%) | 772.43, 645.81, 614.25, 620.91, 612.32 |

#### 2. Pure Backend Breakdown (5 Rounds Average, excl. Debounce)
| Query | Backend 1st Screen Avg | Backend 1st Raw (ms) | Pure Backend Full Avg | DB Query Avg | MainActor Commit Avg | Pure Backend Full Raw (ms) |
| --- | ---: | --- | ---: | ---: | ---: | --- |
| `大丈夫` | **24.56 ms** (-82.0%) | 23.43, 26.34, 34.93, 16.14, 21.96 | **54.69 ms** (-90.2%) | 54.08 ms (-90.3%) | 0.62 ms (-35.4%) | 54.26, 56.72, 63.97, 46.22, 52.30 |
| `今日` | **34.60 ms** (-72.3%) | 22.26, 33.01, 17.62, 17.45, 82.67 | **82.97 ms** (-87.5%) | 82.03 ms (-87.6%) | 0.94 ms (-34.3%) | 58.28, 69.14, 53.85, 53.06, 180.52 |
| `の` | **25.89 ms** (-19.1%) | 38.38, 28.46, 22.50, 20.00, 20.12 | **549.40 ms** (-74.7%) | 503.00 ms (-76.1%) | 46.40 ms (-35.4%) | 670.73, 542.46, 509.24, 517.28, 507.29 |
