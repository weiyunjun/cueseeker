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
- Switching across cover-grid pages (`Recent`, `Library` overview and folder detail, `Excerpt` overview, and `Command Panel -> Recent Videos` / `Recent Excerpt Lists`) suffered from three compounded bottlenecks:
  1. `LibraryCoverImagePipelineConfiguration.production` capped the cover memory cache at `16 MB` (`~28` decoded `512 × 288` RGBA covers), causing frequent LRU thrashing when switching between two 20-card grids or opening a multi-episode folder, while offscreen rows in large folders decoded covers immediately on page open.
  2. Opening `Command Panel -> Recent Videos` unconditionally reset `testRecentWatchingStatus` to `.loading` and blocked on a full SQLite query, and `prepareWorkbenchSurfaceForPresentation` / `preparePlaybackCommandPanelPageForPresentation` awaited background refresh tasks even when a resolved snapshot was already in memory.
  3. Every idle card in `LibraryOverviewGrid` mounted multiple `NSViewRepresentable` bridges (`WorkbenchAccessibilityScrollRevealProbe`, `MenuAnchorProbe`, per-card `NSEvent` right-click monitors, and hidden `WorkbenchIconButton` subviews), per-card `GeometryReader`s, eager localized menu-item arrays, and redundant `@State` updates on prewarmed covers.

## What Changed

1. **Debug-Only Process Footprint & Cover Cache Telemetry (`LibraryCoverImagePipeline.swift`, `DebugInteractionLatencyProbe.swift`)**:
   - Added thread-safe `usageSnapshot` (`totalCostBytes` and `count`) on `LibraryCoverImageMemoryCache` and exposed `nonisolated var memoryCacheUsageSnapshot` on `LibraryCoverImagePipeline`.
   - Sampled Mach `TASK_VM_INFO` `phys_footprint` (`currentPhysicalFootprintBytes()`) at operation start and completion under `#if DEBUG` (`AppBuildConfiguration.current == .debug`), appending `memory_mb`, `memory_delta_mb`, `peak_memory_mb`, `cover_cache_mb`, and `cover_cache_count` to navigation and dialog completion logs.
2. **Cover Memory Cache Capacity (`64MB` / `100` Covers), Memory Pressure Trimming & Viewport-Gated Decoding (`LibraryCoverImagePipeline.swift`, `LibraryOverviewComponents.swift`, `LibraryCoverViews.swift`)**:
   - Raised `LibraryCoverImagePipelineConfiguration.production` to `costLimitBytes: 64 * 1_024 * 1_024` (`64 MB`) and `countLimit: 100` (keeping `512 × 288` resolution and `maxConcurrentDecodes: 4`).
   - Added `trim(retainingMostRecentCount:)` and `handleMemoryPressure(isCritical:)` wired to a system `DispatchSourceMemoryPressure` monitor (`[.warning, .critical]`).
   - Added `LibraryGridViewportObserver` on `LibraryOverviewGrid` (when item count exceeds `firstScreenPrewarmLimit`) and `isLibraryCoverDecodeActive` environment propagation so offscreen rows do not start background cover decodes until scrolled near the viewport, and automatically cancel in-flight decodes when scrolled out of range.
3. **Snapshot Reuse Across Workbench & Command Panel (`LibraryStore+Execution.swift`, `AppCoordinator+Library.swift`, `AppCoordinator+PlaybackCommandPanel.swift`, `WorkbenchWorkspaceView.swift`)**:
   - Updated `presentPlaybackCommandPanelPage(.recentVideos)` to flush pending playback history presentations (`flushPendingLibraryPlaybackHistoryPresentations()`) and reuse the existing `testRecentWatchingItems` snapshot via `hydrateTestRecentWatchingAsync()` instead of resetting status to `.loading`.
   - Updated `prepareWorkbenchSurfaceForPresentation` and `preparePlaybackCommandPanelPageForPresentation` to only await database tasks when the target snapshot is not yet resolved.
   - Added `preservesExistingSnapshot` support to `refreshLibrary` and `refreshCompleteLibrary` (preserving unchanged folder details in `completeLibraryFolderDetailsByPath` during background/reappearance refreshes).
4. **First-Frame Card Grid Layout & Per-Card View Hierarchy Slimming (`WorkbenchAccessibility.swift`, `LibraryOverviewComponents.swift`, `LibraryCoverViews.swift`, `LibraryCardContextMenuHost.swift`, `LibraryMediaCards.swift`, `ExcerptListCardGrid.swift`, `PlaybackCommandPanel.swift`)**:
   - Mounted `WorkbenchAccessibilityScrollRevealProbe` inside `workbenchAccessibilityFocusRing` only when `isFocused` is `true`, and removed the duplicate probe on `LibraryCoverChooser`.
   - Mounted `WorkbenchIconButton`, `MenuAnchorProbe`, and the scroll-tracking `GeometryReader` inside `LibraryCoverMoreButton` only when `isVisible || isOpen || isFocused`.
   - Replaced per-card `GeometryReader` and per-card `NSEvent` local monitors in `LibraryCardContextMenuTriggerModifier` / `LibraryCardRightClickMonitor` with direct coordinate conversion via `LibraryCardMenuHostGeometry`, a single shared `LibraryCardRightClickEventDispatcher`, a conditional `GeometryReader` only on the active menu owner card, and lazy context-menu item closures.
   - Avoided redundant `@State` mutations in `LibraryCachedCoverImage.loadImage` when a cover is already present in `LibraryCoverImagePipeline.shared.cachedImage(for:)`, and stored `PlaybackCommandPanelRecentCards` item frames in a non-invalidating reference box when no keyboard scroll request is pending.

## Verification

- Automated tests:
  - `swift test --package-path apps/macos-native --filter "LibraryCoverImagePipelineTests|LibraryRouteSnapshotReuseTests|RecentPlaybackSessionRegressionTests|LibraryCardMenuPlacementTests|WorkbenchAccessibilityStep1Tests|WorkbenchAccessibilityStep4Tests|PlaybackLibraryOverlayTests|DebugInteractionLatencyProbeTests"`
