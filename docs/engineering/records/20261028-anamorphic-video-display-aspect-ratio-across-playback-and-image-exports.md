# 2026-10-28 Anamorphic Video Display Aspect Ratio Across Playback And Image Exports

## Requirement Reference
- `docs/human/requirements/20261028-Bug-Anamorphic Video Display Aspect Ratio Across Playback And Image Exports.md`
- `docs/human/design/playback/Playback Core.md`
- `docs/human/design/workbench/Library and File.md`
- `docs/human/design/workbench/Excerpt and Export.md`

## Summary of Changes
1. **Native Playback Display Aspect Ratio & Pixel Aspect Ratio Attachments (`SFXNativePlaybackPlayer.h`, `SFXNativePlaybackInternal.h`, `SFXVideoToolboxSupport.m`, `SFXNativePlaybackView.m`, `SFXNativePlaybackSession.m`, `SFXNativePlaybackSession+AudioAndDecode.m`, `SFXNativePlaybackPlayer.m`, `PlaybackPlayer.swift`)**:
   - Added `SFXVideoSampleAspectRatio`, `SFXDisplayVideoWidthForDimensionsAndSAR`, `SFXDisplayVideoWidthForPixelBuffer`, and `SFXApplyPixelAspectRatioAttachment` using FFmpeg's `av_guess_sample_aspect_ratio`.
   - Attached `kCVImageBufferPixelAspectRatioKey` to both hardware-decoded and software-decoded `CVPixelBuffer` frames, removing any stale bitstream attachment when the resolved sample aspect ratio is `1:1`.
   - Passed the decoded frame's `AVRational` sample aspect ratio directly into `sampleBufferForPixelBuffer:presentationTime:sampleAspectRatio:` to invalidate `_cachedVideoFormatDescription` when SAR changes without copying `CVPixelBuffer` attachments on the render path.
   - Updated `SFXNativePlaybackSession.videoWidth` / `videoHeight` and `SFXNativePlaybackFrameSnapshot.width` to report the display dimensions in a thread-safe manner from synchronized session state, and updated `PlaybackPlayer.commitPendingPresentation` to refresh the subtitle render container's `videoSize`.
2. **Covers, Scrubbing Thumbnails, Screenshots, Collage, and Anki Image Exports (`SFXKeyframeScrubPreviewDecoder.m`, `SFXMediaMetadataInspector.m`, `LibraryCoverIndexer.swift`, `PlaybackCurrentFrameScreenshot.swift`, `SubtitleScreenshotExporter.swift`, `AnkiPackageExporter.swift`)**:
   - Updated in-process keyframe scrub preview decoding (`SFXKeyframeScrubPreviewDecoder`) and cover frame sampling (`SFXMediaMetadataInspector`) to scale output frames to display dimensions (`displayWidth × height`), while preserving raw storage dimensions in `SFXMediaMetadataInspector.metadataAtMediaPath:`.
   - Updated `PlaybackCurrentFrameScreenshotRenderer` to reuse `SFXDisplayVideoWidthForPixelBuffer` and scale to display width in a single pass during `CIImage` to `CGImage` conversion.
   - Added `scale='max(1,round(iw*sar))':ih,setsar=1` to FFmpeg video filters in `LibraryCoverIndexer`, `SubtitleScreenshotExporter`, and `AnkiPackageExporter`.

## Verification
- Added and updated unit tests in `NativePlaybackMediaTimelineTests.swift`, `PlaybackCurrentFrameScreenshotTests.swift`, and `SubtitleScreenshotExporterTests.swift`.
- Ran `swift test --package-path apps/macos-native --no-parallel --filter "SubtitleScreenshotExporterTests|PlaybackCurrentFrameScreenshotTests|NativePlaybackMediaTimelineTests|NativePlaybackPresentationTransitionTests|LibraryCoverIndexerTests|AnkiPackageExporterTests"`.
- Outcome matched expectations.
