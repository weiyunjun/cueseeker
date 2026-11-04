# Cover Grid Switching Latency And Memory Telemetry

Human-owned documents:

- `docs/human/requirements/20261105-Performance-Cover Grid Switching Latency And Memory Telemetry.md`
- `docs/human/design/ui/UI Design Rules.md`
- `docs/human/design/ui/UI Interaction Rules.md`
- `docs/human/design/ui/UI Components - Domain.md`
- `docs/human/design/ui/UI Layouts - Workbench.md`
- `docs/human/design/ui/UI Layouts - Playback.md`
- `docs/human/design/workbench/Recent and Library.md`

## Why

- Existing debug interaction latency logs captured navigation, cover prewarm, and dialog timing breakdowns, but did not report Activity Monitor physical memory footprint (`phys_footprint`), per-action memory deltas, peak memory footprint, or actual `LibraryCoverImagePipeline` memory cache occupancy (MB and item count).
- Before tuning cover cache capacity, snapshot reuse, and first-frame grid rendering, baseline memory and cover-cache telemetry is needed during E2E debug runs.

## What Changed

1. **Synchronous Cover Memory Cache Usage Snapshot (`LibraryCoverImagePipeline.swift`)**:
   - Added thread-safe `usageSnapshot` (`totalCostBytes` and `count`) on `LibraryCoverImageMemoryCache` and exposed `nonisolated var memoryCacheUsageSnapshot` on `LibraryCoverImagePipeline` for lock-safe synchronous sampling.
2. **Debug-Only Process Footprint & Cover Cache Telemetry (`DebugInteractionLatencyProbe.swift`)**:
   - Sampled Mach `TASK_VM_INFO` `phys_footprint` (`currentPhysicalFootprintBytes()`) at operation start and completion under `#if DEBUG` (`AppBuildConfiguration.current == .debug`).
   - Appended `memory_mb`, `memory_delta_mb`, `peak_memory_mb`, `cover_cache_mb`, and `cover_cache_count` to navigation completion logs (`completeImmediateNavigation`, `completeNavigationOnNextFrame`) and dialog completion logs (`completeDialogOpenIfNeeded`, `recordDialogInternalTransition`).
3. **Unit Tests (`DebugInteractionLatencyProbeTests.swift`)**:
   - Verified that workbench navigation, overlay immediate transition, dialog open, and dialog internal transition debug logs include valid formatted `memory_mb`, signed `memory_delta_mb`, `peak_memory_mb`, `cover_cache_mb`, and `cover_cache_count` fields.

## Verification

- Automated tests:
  - `swift test --package-path apps/macos-native --filter DebugInteractionLatencyProbeTests`
