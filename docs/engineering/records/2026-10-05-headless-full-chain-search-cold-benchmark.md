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
  - Replaced ineffective page eviction with Direct I/O (`fcntl(testFd, F_NOCACHE, 1)` and `fcntl(testFd, F_RDAHEAD, 0)`) on open SQLite file descriptors to reliably bypass the macOS Unified Buffer Cache without requiring root permissions.
  - Reorganized benchmark execution into 5 interleaved round-robin cycles across the 3 queries (`大丈夫` -> `今日` -> `の`), completely eliminating warm-cache bias and distortion across repeated runs.
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

#### Measured Baseline (5 Rounds Round-Robin)

| Query | Total Results | Files | 1st Screen Median | 1st Screen Raw (5 rounds, ms) | Full Results Median | Full Results Raw (5 rounds, ms) |
| :--- | ---: | ---: | ---: | --- | ---: | --- |
| `大丈夫` | 1,462 | 498 | **179.27 ms** | 205.50, 175.94, 172.28, 179.27, 180.06 | **253.84 ms** | 333.39, 248.66, 251.61, 253.84, 257.93 |
| `今日` | 2,300 | 497 | **179.55 ms** | 193.75, 179.55, 177.69, 179.83, 177.48 | **283.86 ms** | 330.88, 283.86, 283.58, 284.79, 282.32 |
| `の` | 76,817 | 637 | **115.99 ms** | 114.64, 115.99, 111.91, 120.70, 117.68 | **2116.15 ms** | 2142.75, 2030.33, 2047.58, 2116.15, 2229.50 |
