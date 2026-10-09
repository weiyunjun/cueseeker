# Remove Cover Skeleton Screen And Simplify Loading

Human-owned documents:

- `docs/human/requirements/20261009-UI-Remove Cover Skeleton And Simplify Loading.md`
- `docs/human/design/UI Design System.md`
- `docs/human/design/UI Application Rules.md`

## Why

1. **Eliminate Skeleton Flicker in Pure Offline Desktop Environment**:
   - The previously introduced Skeleton Screen with Shimmer produced noticeable flicker and strobing during frequent desktop interactions, especially when re-sorting or switching views in Library.
   - On Apple Silicon Macs with fast NVMe SSDs and local SQLite databases, local cover decoding completes in 2–5ms without network latency. An artificial skeleton placeholder state (and its associated crossfade) interrupts instant rendering and introduces a jarring gray flash.
   - Adhering to Occam's razor and native desktop software standards (e.g., macOS Finder, Photos, Apple Music), the shimmering skeleton was removed in favor of direct zero-frame cache rendering and quiet neutral container loading.

2. **Zero-Latency In-Memory Rendering**:
   - The async actor pipeline previously forced a 1-frame runloop yield even when an image was already decoded and present in memory, which caused SwiftUI views to temporarily display the placeholder before transitioning.
   - Adding a thread-safe synchronous cache peek (`cachedImage(for:)`) allows views to read already-cached images during initial view evaluation in frame 0, completely eliminating sorting and re-rendering flicker.

## What changed

1. **Cover Image Pipeline**:
   - In `LibraryCoverImagePipeline.swift`, extracted in-memory decoded image storage and deterministic LRU cache management into `LibraryCoverImageMemoryCache` protected by an internal lock.
   - Exposed `nonisolated func cachedImage(for key: LibraryCoverImageKey) -> CGImage?` to allow synchronous cache access from the main thread during SwiftUI view evaluation.
2. **Cover Views**:
   - In `LibraryCachedCoverImage` (`WorkbenchTestLibraryView.swift`) and `ExcerptListCoverView.swift`:
     - Synchronously checked the in-memory cache for `currentImage`.
     - When cached, render `LibraryCoverFillImage` immediately without transitions or async hops.
     - When loading an uncached valid cover, maintain the card layout with `Color.clear` (matching surface background without shimmer, animations, or temporary icons).
     - Render `defaultCover` (static placeholder background + video/bookmark icon) only when `coverPath` is absent or decoding explicitly fails.
     - Removed `CoverSkeletonShimmerView`, `delayTask`, `isShimmerVisible`, and crossfade animations.
3. **Dead Code & Token Cleanup**:
   - Deleted `CoverSkeletonShimmerView.swift`.
   - Removed `skeletonBase` and `skeletonHighlight` tokens from `WorkbenchRedesignTokens.swift`.
   - Removed `redesignShimmerMotionDuration` and `redesignCoverAntiFlickerDelayNanoseconds` from `WorkbenchControls.swift`.
   - Removed obsolete `coverSkeletonShimmerTokensMatchDesignSpecification` test from `WorkbenchControlMetricsTests.swift`.
4. **Unit Verification**:
   - Added synchronous `cachedImage(for:)` assertions in `LibraryCoverImagePipelineTests.swift`.

## Verification

- Automated tests:
  - `swift test --filter LibraryCoverImagePipelineTests`: 11/11 passed.
  - `swift test --filter WorkbenchControlMetricsTests`: 12/12 passed.
  - `swift test --filter LibraryCover`: 35/35 passed.
