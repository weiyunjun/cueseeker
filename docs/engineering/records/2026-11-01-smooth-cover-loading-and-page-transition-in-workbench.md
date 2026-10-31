# Smooth Cover Loading And Page Transition In Workbench

Human-owned documents:

- `docs/human/requirements/20261101-UI-Smooth Cover Loading And Page Transition In Workbench.md`
- `docs/human/design/ui/UI Design Rules.md`
- `docs/human/design/ui/UI Components - Domain.md`
- `docs/human/design/ui/UI Layouts - Workbench.md`
- `docs/human/design/ui/UI Layouts - Playback.md`
- `docs/human/design/ui/UI Tokens.md`

## Why

1. **Eliminate Multi-Frame Intermediate Flash During Cover Route Transitions across Workbench, Playback Overlay, and Command Panel**:
   - Switching to `Recent`, `Library` (Level 1 overview or Level 2 folder detail), `Excerpt` overview in Workbench, or switching to `Video Playlist` in Playback Overlay / `Recent Videos` & `Recent Excerpt Lists` in Command Panel previously mounted the destination view immediately before local SQLite hydration and first-screen cover decoding had finished.
   - Because local NVMe SSD reads and image decoding take only ~5–15ms, immediately rendering a transient `WorkbenchSpinner`, `"0 lists 0 cues"`, `"0 videos"`, premature empty hints, or an un-decoded card grid caused the screen to flash through 3–4 visual states within a single frame interval.
2. **Eliminate Per-Card Layer Tearing & Restore Silent Transparent Loading**:
   - Commit `4bd269b` had regressed `LibraryCachedCoverImage` and `ExcerptListCoverView` from `Color.clear` back to `Rectangle().fill(WorkbenchRedesignColors.libraryCoverPlaceholderBg)`.
   - In addition, `LibraryCoverWithProgress`, `LibraryCoverWithBadge`, and `ExcerptListCard` drew the bottom-left duration/count badge (`LibraryCoverBadge`) and bottom progress bar (`progressTrack`) on Frame 1 before the underlying cover bitmap finished decoding, causing foreground overlays to float over an empty/gray box and the cover bitmap to pop in behind them a few milliseconds later.

## What Changed

1. **Cover Image Pipeline (`LibraryCoverImagePipeline.swift`)**:
   - Preserved the existing `16 MiB` (`64` images) cost limit and `maxConcurrentDecodes = 4` boundary without modification.
   - Added thread-safe failed-key tracking (`hasFailedDecode(for:)`, `isReadyForPresentation(for:)`) and `prewarm(keys:)` (bounded to `firstScreenPrewarmLimit = 20` unique keys) so page transitions can await first-screen cover readiness before presenting the destination surface.
2. **Atomic Cover Layer (`LibraryCoverViews.swift`, `ExcerptListCoverView.swift`, `ExcerptListCardGrid.swift`)**:
   - Restored `Color.clear` when a cover with a valid key is still decoding (`key != nil && !isDecodeFailed`).
   - Bound cover overlays (`LibraryCoverBadge` and `progressTrack`) into `LibraryCachedCoverImage` and `ExcerptListCoverView` so that during loading neither the gray box nor the badge/progress overlay is drawn; when decoding finishes (or falls back on missing/corrupt files), the cover and its overlays appear atomically in the same frame.
3. **Workbench, Playback Overlay, and Command Panel Page Transitions (`WorkbenchWorkspaceView.swift`, `WorkbenchRecentView.swift`, `WorkbenchLibraryView.swift`, `ExcerptListOverviewView.swift`, `PlaybackLibrarySessionStore.swift`, `PlaybackLibraryOverlay.swift`, `PlaybackSubtitleFocusOverlay.swift`, `AppCoordinator+PlaybackCommandPanel.swift`, `PlaybackCommandPanel.swift`)**:
   - Added `WorkbenchPresentedSurface` and `AppCoordinator` readiness/preparation helpers (`isWorkbenchSurfaceReadyForPresentation(_:)` and `prepareWorkbenchSurfaceForPresentation(_:)`), `PlaybackLibrarySessionStore` readiness/preparation (`isReadyForPresentation`, `prepareForPresentation()`), and Command Panel page readiness/preparation (`isPlaybackCommandPanelPageReadyForPresentation(_:)`, `preparePlaybackCommandPanelPageForPresentation(_:)`).
   - When switching to a cover-bearing surface whose data and first-screen covers are already ready in memory, the view switches synchronously on Frame 1 (`0ms`).
   - When switching to an uncached surface, the container view holds the outgoing surface while hydrating the store and prewarming the first-screen covers in the background, then commits the complete target surface in a single frame.
   - Removed transient `WorkbenchSpinner` and premature empty/zero-count states during initial local hydration in `WorkbenchRecentView`, `WorkbenchLibraryView`, `ExcerptListOverviewView`, `PlaybackLibraryOverlay`, and `PlaybackCommandPanelRecentCards`, and replaced unconditional `reloadExcerptListOverview()` calls on appearance/navigation with `loadExcerptListOverviewIfNeeded()`.

## Verification

- Automated tests:
  - `swift test --filter LibraryCoverImagePipeline`
  - `swift test --filter WorkbenchInvalidationTests`
  - `swift test --filter PlaybackLibraryOverlayTests`
  - `swift test --filter RecentPlaybackSessionRegressionTests`
  - `swift test --filter ExcerptPresentationTests`
  - `swift test --filter WorkbenchAccessibilityStep4Tests`
  - `swift test --filter CueGroupRefreshScopeIntegrationTests`
