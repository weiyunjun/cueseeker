# 2026-10-23 Subtitle Reel Smooth Rendering And Frame Synchronization

## Requirement Reference
- `docs/human/requirements/20261023-Engineering-Subtitle Reel Smooth Rendering And Frame Synchronization.md`

## Summary of Changes
1. **Per-Item Text Geometry & Metadata Plan Caching (`PlaybackVisualLineStackLayout.swift`, `PlaybackCueResult.swift`, `PlaybackPlaylistReelAdapter.swift`, `PlaybackVirtualReelContracts.swift`)**:
   - Added `GeometrySignature` and segment character range tracking to `PlaybackVisualLineStackLayout.prepare(segments:width:)`. When segment texts, fonts, line heights, and width are unchanged, color changes update only `.foregroundColor` attributes in `NSTextStorage` and return the cached `PlaybackVisualLineStackPlan` without re-running `ensureLayout`, `enumerateLineFragments`, or CoreText glyph path bounds (`CTLineGetBoundsWithOptions`).
   - Added a bounded 128-entry LRU cache to `PlaybackCueMetadataLayout.makePlan(metadata:width:)` to avoid repeated per-frame string width measurements.
   - Added bounded per-item layout caches (`PlaybackCueResultLayout` in `PlaybackCueResultReelAdapter`, `PlaybackSubtitleFocusNativeTextLayout` in `PlaybackSubtitleFocusCueReelAdapter`) and removed redundant `viewportHeight` key duplication from `PlaybackSubtitleFocusCueMeasurementCache`.
2. **Steady-State Row Bitmap Reuse (`PlaybackSubtitleFocusReelDocumentView.swift`)**:
   - Added a 32-entry LRU `rowBitmapCache` (`CGImage`) in `PlaybackSubtitleFocusReelDocumentView.draw(_:)` for rows in a steady color state (`selectedTextRange == nil` and `selectionProgress` at `0` or `1`). Unchanging rows during scrolling blit their cached Retina bitmap directly to the updated vertical placement rect, while actively fading rows (`0 < selectionProgress < 1`) draw using their cached layout plan.
3. **Display VSync Synchronization & Immediate First-Frame Kickoff (`PlaybackSubtitleFocusWheelAccumulator.swift`, `PlaybackSubtitleFocusReelDocumentView.swift`, `PlaybackSubtitleFocusReel.swift`)**:
   - Updated `PlaybackSubtitleFocusReelPositionAnimator` and `PlaybackSubtitleFocusReelDocumentView` to drive scroll and focus transitions via `NSView.displayLink(target:selector:)` (`CADisplayLink`, 60–120Hz, `.common` RunLoop mode) on macOS 14+ when attached to a visible window, with zero-tolerance `120Hz` `Timer` fallback when off-window.
   - Updated live-window navigation starts (`retarget` and `beginNavigationSelection`) to immediately advance and invalidate the initial frame on the same RunLoop turn, eliminating first-frame startup latency.

## Verification
- Added `subtitleFocusScrollAndFadeReusePreparedLayoutsAndStaticRowBitmaps` in `PlaybackSubtitleFocusLayoutTests.swift` and `playbackCueResultReelAdapterReusesPreparedGeometryAcrossColorFadeFrames` in `PlaybackPlaylistReelAdapterTests.swift`.
- Ran `swift test --package-path apps/macos-native --filter "PlaybackSubtitleFocusLayoutTests|PlaybackCueResultLayoutTests|PlaybackPlaylistReelAdapterTests|PlaybackSearchOverlayTests|PlaybackSubtitleFocusKeyboardActionTests"` (all 123 tests passed).
