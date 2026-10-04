# Cover Skeleton Screen With Shimmer

Human-owned documents:

- `docs/human/requirements/20261004-UI-Cover Skeleton Screen With Shimmer.md`
- `docs/human/design/UI Design System.md`
- `docs/human/design/UI Application Rules.md`

## Why

1. **Eliminate Static Placeholder Inconsistency**:
   - Previously, when card covers were loading or queued in the decode pipeline, cards fell back to a rigid grey rectangle containing a centered static icon (`libraryCoverPlaceholderBg` with `AppIconImage(.video)` or `.bookmarkSimple`).
   - When users resized or maximized the window, new rows of cards suddenly entered the viewport and queued in `LibraryCoverImagePipeline`, exposing an array of static placeholder icons that felt visually broken and unpolished.
   - Introducing a smooth Skeleton Screen with a flowing Shimmer animation provides a visual wireframe of the content being loaded, transforming perceived latency into an intentional, progressive presentation.

2. **Anti-Flicker Protection**:
   - For fast reads (in-memory cache or fast local disk I/O completing within 120ms), rendering a skeleton immediately creates an undesirable flash of placeholder before disappearing.
   - An anti-flicker delay threshold (120ms) suppresses the shimmer animation during fast loads, rendering the image directly without visible flash.
   - When decode exceeds 120ms, the shimmer smoothly fades in and crossfades out into the decoded image with a 0.20s ease-out curve.

## What changed

1. **Tokens**:
   - In `WorkbenchControls.swift`, added:
     - `redesignShimmerMotionDuration = 1.5`
     - `redesignCoverAntiFlickerDelayNanoseconds = 120_000_000` (120ms threshold)
     - `redesignCoverCrossfadeDuration = 0.20`
   - In `WorkbenchRedesignTokens.swift`, added:
     - `NS.skeletonBase` (Light `#E5E7EB`, Dark `#2E2E33`, aligned with `libraryCoverPlaceholderBg`)
     - `NS.skeletonHighlight` (Light `#FFFFFF` alpha 0.65, Dark `#FFFFFF` alpha 0.08)
     - SwiftUI colors `skeletonBase` and `skeletonHighlight`
2. **CoverSkeletonShimmerView**:
   - Created `CoverSkeletonShimmerView.swift` implementing a lightweight `TimelineView(.animation)` continuous sweep across the cover card width.
   - Automatically stops execution and stays a still base fill when `isShimmering` is false or when system `accessibilityReduceMotion` is enabled.
3. **LibraryCachedCoverImage & ExcerptListCoverView**:
   - Replaced static placeholder views with `CoverSkeletonShimmerView`.
   - Added anti-flicker delay timers to defer shimmer until loading exceeds the 120ms threshold.
   - Added smooth 0.20s ease-out crossfade transitions between the skeleton and the decoded image.
4. **Verification**:
   - In `WorkbenchControlMetricsTests.swift`, added `coverSkeletonShimmerTokensMatchDesignSpecification` asserting motion duration, delay nanoseconds, crossfade duration, and base color token bindings.

## Verification

- Automated tests:
  - `swift test --package-path apps/macos-native --filter WorkbenchControlMetricsTests`: 10/10 passed.
  - `swift test --package-path apps/macos-native --filter CoverSummaryCardTests`: 10/10 passed.
  - `swift test --package-path apps/macos-native --filter LibraryCoverImagePipelineTests`: 11/11 passed.
