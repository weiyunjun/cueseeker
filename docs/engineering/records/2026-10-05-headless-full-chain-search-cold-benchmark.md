# Headless full chain search cold benchmark

Human-owned documents:

- `docs/human/requirements/20261005-Engineering-Headless Full Chain Search Cold Benchmark.md`

## Why

1. Historical search benchmarks in `SearchBench` measured isolated database queries (`searchPage`) without folder scoping (`under: nil`) and without executing the MainActor state commit pipeline.
2. In the real macOS native app, search latency perceived by the user involves the complete end-to-end pipeline:
   - User input debounce (100ms).
   - Library folder scoping (`selectedFolders`).
   - SQLite FTS5 multi-batch streaming and progress yielding.
   - MainActor `SearchStore` first page rendering readiness (`T_first`).
   - `CueContentStore` row text installation across all results.
   - `searchRankByCueID` dictionary indexing.
   - Complete `CueFacetSnapshot` distribution calculation across all matching cues (e.g. 76,817 cues).
   - `TableSandboxRowModelStore` snapshot publishing and table scroll dimension layout simulation.
3. Furthermore, repeated runs in naive benchmarks were distorted by in-process or OS buffer cache hits. A standardized protocol was required to isolate database connections and evict operating system page cache between runs to accurately capture true cold search performance without launching the App GUI.

## What changed

- **SearchBench Headless Full-Chain Cold Benchmark (`--headless-cold`)**:
  - Implemented `--headless-cold` in `apps/macos-native/Sources/SearchBench/main.swift`.
  - Automatically resolves active library scope from `UserDefaults(suiteName: "com.cueseeker.shared")` (`selectedFolderPaths`).
  - Added simulated input debounce (100ms).
  - Integrated streaming 100-row progress yield capturing exact first screen readiness (`T_first`).
  - Implemented complete MainActor state commit and data structure assembly:
    - `CueContentStore.install` for all returned results.
    - `searchRankByCueID` dictionary indexing.
    - Full `CueFacetSnapshot.filteredCueIDs(using:limit:)` facet distribution calculation.
    - `TableSandboxRowModelStore` snapshot assembly and table height layout recomputation.
  - Added `evictFilePageCache` utilizing macOS `madvise(..., MADV_DONTNEED)` before each sample run to ensure genuine cold-cache isolation without requiring root permissions.
- **Engineering Testing Rules**:
  - Updated `docs/engineering/06_testing_rules.md` (Section 9: Search Optimization Gates) with the Headless Full-Chain Cold Benchmark protocol, command, and measured baseline.

Files:

- `apps/macos-native/Sources/SearchBench/main.swift`
- `docs/engineering/06_testing_rules.md`
- `docs/engineering/records/2026-10-05-headless-full-chain-search-cold-benchmark.md`

## Verification

### Automated Tests
- `swift test --package-path apps/macos-native --filter SearchStoreTests`: 27/27 passed.
- `swift test --package-path apps/macos-native --filter CueSeekerCoreTests`: 324/324 passed.

### Benchmark Execution (Release Mode)
Command:
```bash
swift run --package-path apps/macos-native -c release SearchBench "$HOME/Library/Application Support/CueSeeker/CueSeeker.sqlite" --headless-cold
```

Target: `/Users/weiyunjun/Library/Application Support/CueSeeker/CueSeeker.sqlite` (Schema 54, 76,817 matches for `の`, Library Scope: `/Volumes/Seagate/影视`).

#### Measured Baseline (5 Runs)

| Query | Total Results | Files | 1st Screen Median | 1st Screen Raw (5 runs, ms) | Full Results Median | Full Results Raw (5 runs, ms) |
| :--- | ---: | ---: | ---: | --- | ---: | --- |
| `大丈夫` | 1,462 | 498 | **112.43 ms** | 235.24, 107.99, 112.88, 111.26, 112.43 | **143.03 ms** | 830.35, 138.24, 143.03, 141.41, 149.46 |
| `今日` | 2,300 | 497 | **113.22 ms** | 169.73, 113.22, 113.28, 110.98, 112.60 | **155.79 ms** | 575.54, 154.82, 155.79, 157.96, 152.16 |
| `の` | 76,817 | 637 | **116.44 ms** | 130.73, 113.17, 118.42, 115.71, 116.44 | **1238.35 ms** | 2949.98, 1238.35, 1256.44, 1235.18, 1235.73 |
