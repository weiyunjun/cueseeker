# 2026-10-22 Split Oversized Playback Reel Player And Subtitle Renderer Files

## Requirement Reference
- `docs/human/requirements/20261022-Engineering-Split Oversized Playback Reel Player And Subtitle Renderer Files.md`

## Summary of Changes
1. **Sub-step 3A — Split `PlaybackSubtitleFocusReel.swift` (4,305 Lines) into 5 Focused Files**:
   - `PlaybackVirtualReelContracts.swift` (686 lines): `PlaybackVirtualReelItemExtent`, `PlaybackVirtualReelSnapshot`, `PlaybackVirtualReelSelectionCommit`, `PlaybackTextSelectionHit`, `PlaybackVirtualReelContentAdapter`, `PlaybackVirtualReelLayout`, `PlaybackSubtitleFocusCueMeasurementCache`, `PlaybackSubtitleFocusCueReelAdapter`, `PlaybackSubtitleFocusNativeScrollbarMetrics`.
   - `PlaybackSubtitleFocusWheelAccumulator.swift` (332 lines): `PlaybackSubtitleFocusScrollSettleDirective`, `PlaybackSubtitleFocusScrollSample`, `PlaybackSubtitleFocusNativeWheelState`, `PlaybackSubtitleFocusReelPositionAnimator`.
   - `PlaybackVisualLineStackLayout.swift` (748 lines): `PlaybackVisualLineStackSegment`, `PlaybackVisualLineStackLine`, `PlaybackVisualLineStackPlan`, `PlaybackVisualLineStackLayout`, `PlaybackSubtitleFocusCueTextMeasurer`, `PlaybackSubtitleFocusNativeTextLayout`.
   - `PlaybackSubtitleFocusReelDocumentView.swift` (1,001 lines): `PlaybackCueTimelineRowLayout`, `PlaybackCueTimelineLayout`, `PlaybackCollageCheckboxDrawing`, `PlaybackSubtitleFocusReelDocumentView`, `PlaybackSelectedTextMenu`.
   - `PlaybackSubtitleFocusReel.swift` (1,547 lines): `PlaybackSubtitleFocusReelRepresentable`, `PlaybackSubtitleFocusReelContainerView`, `PlaybackSubtitleFocusNativeScrollView`, `PlaybackSubtitleFocusNativeScrollbarView`.
2. **Sub-step 3B — Split `SFXNativePlaybackPlayer.m` (5,895 Lines) into Modular Objective-C Units**:
   - `SFXNativePlaybackInternal.h` (548 lines): Internal shared types, helper prototypes, and class extensions.
   - `SFXVideoToolboxSupport.m` (693 lines): FFmpeg input opener, VideoToolbox hardware decode capability probing, media timeline PTS math, and `CMSampleBufferRef` wrapping.
   - `SFXKeyframeScrubPreviewDecoder.m` (252 lines): Keyframe-only timeline scrub preview decoder.
   - `SFXNativePlaybackView.m` (96 lines): `SFXNativePlaybackView` and `SFXNativePlaybackFrameSnapshot`.
   - `SFXNativePlaybackSession.m` (2,153 lines): Session lifecycle, segment boundary state, media preparation, transport controls, packet read-ahead queue, demux loop, and seek state machine.
   - `SFXNativePlaybackSession+AudioAndDecode.m` (1,581 lines): Video/audio decode loop, starvation watchdog, software scaler, A/V clock pacing, `AVSampleBufferDisplayLayer` submission, and audio resampler/scheduling.
   - `SFXNativePlaybackPlayer.m` (804 lines): Player coordinator, generation gating, scrub preview queue, and automatic software session recycle.
3. **Sub-step 3C — Split `SRTSubtitleRenderer.swift` (1,404 Lines) and Replaced Legacy String-Property Player API**:
   - `SRTSubtitleInlineText.swift` (332 lines): `SRTFontCache` and `SRTInlineText` HTML/ASS inline tag parser, entity decoder, and per-character Unicode font fallback helpers.
   - `SRTSubtitleOverlayView.swift` (384 lines): `SRTSubtitleOverlayView` AppKit view and `CALayer` subtitle overlay host.
   - `SRTSubtitleRenderer.swift` (695 lines): SRT layout/measurement models and `SRTSubtitleRenderer` CoreText layout and bitmap compositor.
   - Replaced legacy `libmpv` string-property polling (`getDoubleProperty`, `setDoubleProperty`, `player(_:didChangeProperty:value:)`, `PlaybackPropertyValue`, `PlaybackError.nativePropertyUnsupported`) between `PlaybackPlayer` and `PlaybackViewModel` with explicit typed methods (`currentTimePosition()`, `duration()`, `volume()`, `setVolume(_:)`, `playbackSpeed()`, `setPlaybackSpeed(_:)`, `videoAspectRatio()`, `isPausedState()`, `isSubtitleTrackEnabled()`) and typed `PlaybackPlayerDelegate` callbacks.

## Verification
- Verified `swift build --package-path apps/macos-native` and `PlaybackSubtitleFocusLayoutTests` / `PlaybackSubtitleFocusSessionStoreTests` / `PlaybackPlaylistReelAdapterTests` / `PlaybackCueResultLayoutTests` / `PlaybackCollage` / `CueSeekerPlaybackTests` / `PlaybackSegmentCompletionTests` / `PlaybackNormalShortcutTests` / `PlaybackPresentationTransitionTests` / `RecentPlaybackSessionRegressionTests` / `PlaybackLibraryChangeTests` unit test suites compile cleanly with 0 errors and pass.
