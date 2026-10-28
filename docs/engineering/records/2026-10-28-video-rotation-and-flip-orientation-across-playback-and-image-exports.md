# Video Rotation And Flip Orientation Across Playback And Image Exports

## Requirement

- Requirement: `docs/human/requirements/20261028-Bug-Video Rotation And Flip Orientation Across Playback And Image Exports.md`
- Referenced Design Documents:
  - `docs/human/design/playback/Playback Core.md`
  - `docs/human/design/workbench/Library and File.md`
  - `docs/human/design/workbench/Excerpt and Export.md`
  - `docs/human/design/ui/UI Layouts - Workbench.md`

## Scope

Apply video stream and frame display-matrix orientation metadata (`AV_PKT_DATA_DISPLAYMATRIX` / `AV_FRAME_DATA_DISPLAYMATRIX`, covering 90°/180°/270° rotation and horizontal/vertical flips across all 8 orthogonal EXIF orientations) consistently across:

1. Playback video view (`AVSampleBufferDisplayLayer`), aspect ratio, and subtitle overlay alignment.
2. Current-frame screenshot in Playback (`PlaybackCurrentFrameScreenshotRenderer`).
3. Subtitle screenshot / Collage export (`SubtitleScreenshotExporter`) and Anki card screenshot export (`AnkiPackageExporter`), including videos that combine non-`1:1` SAR with 90°/270° rotation.
4. Timeline keyframe scrub preview thumbnails (`SFXKeyframeScrubPreviewDecoder`).
5. In-process and external FFmpeg fallback episode cover generation (`SFXMediaMetadataInspector` and `LibraryCoverIndexer`).
6. Episode File Detail resolution display (`SFXMediaMetadataInspector.metadataAtMediaPath:`), swapping storage width and height when the orientation rotates by 90° or 270°.

## Steps

1. **Orientation Resolution & Shared Helpers (`SFXVideoToolboxSupport.m`, `SFXNativePlaybackPlayer.h`, `SFXNativePlaybackInternal.h`)**:
   - Defined `SFXVideoOrientation` matching the 8 EXIF/CGImagePropertyOrientation values (`1`..`8`).
   - Implemented `SFXResolveVideoOrientationFromDisplayMatrix` and `SFXResolveVideoOrientation` (reading frame side data first, then stream `codecpar->coded_side_data`), `SFXVideoOrientationSwapsDimensions`, `SFXLayerAffineTransformForVideoOrientation`, `SFXUnrotatedDisplayVideoWidthForPixelBuffer`, `SFXGetDisplayVideoDimensionsForPixelBuffer`, and `SFXTransformRGB24DataForVideoOrientation`.
2. **Playback Session & Main-Thread Layer Layout (`SFXNativePlaybackSession.m`, `SFXNativePlaybackSession+AudioAndDecode.m`, `SFXNativePlaybackPlayer.m`, `SFXNativePlaybackView.m`)**:
   - Consolidated display dimension calculation in `SFXNativePlaybackSession` via `getDisplayVideoWidth:height:` (computing unrotated SAR-adjusted width first, then swapping width/height when `SFXVideoOrientationSwapsDimensions` is true).
   - Attached `kCGImagePropertyOrientation` to decoded hardware and software `CVPixelBuffer`s via `SFXApplyVideoOrientationAttachment`.
   - Updated `SFXNativePlaybackView.setVideoOrientation:` to dispatch layout updates strictly on the main thread, swapping `_displayLayer.bounds` width/height around `anchorPoint = (0.5, 0.5)` and applying `SFXLayerAffineTransformForVideoOrientation` before setting `_displayLayer.frame`.
3. **Current-Frame Screenshot (`PlaybackCurrentFrameScreenshot.swift`)**:
   - Scaled the `CIImage` to `SFXUnrotatedDisplayVideoWidthForPixelBuffer(pixelBuffer)` first, then applied `image.oriented(forExifOrientation: Int32(orientation.rawValue))` when `orientation != .up` so non-`1:1` SAR and 90°/270° rotation compose in the required order.
4. **Scrub Preview, Cover Generation & Metadata (`SFXKeyframeScrubPreviewDecoder.m`, `SFXMediaMetadataInspector.m`)**:
   - In `SFXKeyframeScrubPreviewDecoder`, scaled to unrotated SAR display width before rotating/flipping RGB24 pixels and swapping thumbnail dimensions.
   - In `SFXMediaMetadataInspector`, oriented the full-resolution candidate frame via `SFXTransformRGB24DataForVideoOrientation` and always scaled the `64×36` scoring frame from the already-oriented RGB buffer via a single code path.
   - Swapped `videoWidth` and `videoHeight` in `metadataAtMediaPath:` when `SFXVideoOrientationSwapsDimensions(orientation)` is true.
   - Added `swapsVideoDimensions` to `SFXMediaContainerProbe`.
5. **External FFmpeg Frame Extraction for Collage, Anki & Cover Fallback (`SubtitleScreenshotExporter.swift`, `AnkiPackageExporter.swift`, `LibraryCoverIndexer.swift`)**:
   - Because FFmpeg's automatic display-matrix rotation runs `transpose` before user `-vf` filters (which swaps `iw`/`ih` and inverts `sar`), selected `scale=iw:'max(1,round(ih/sar))':reset_sar=1` when `swapsVideoDimensions` is true and `scale='max(1,round(iw*sar))':ih:reset_sar=1` otherwise.

## Verification

- Added and ran unit tests in:
  - `PlaybackCurrentFrameScreenshotTests`: `displayMatrixOrientationMappingCoversAllEightOrthogonalOrientations` and `currentFrameScreenshotRendererAppliesRotationFlipAndAnamorphicSARTogether` (including `144×108` with `SAR 4:3` + 90° CW rotation -> `108×192`).
  - `NativePlaybackMediaTimelineTests`: `nativePlaybackCoversThumbnailsScreenshotsAndMetadataApplyRotationAndFlipMetadata` (verifying 90°/180° metadata dimensions, in-process cover orientation, hardware & software playback aspect ratio and layer bounds/frame, current-frame screenshot, and scrub thumbnail).
  - `SubtitleScreenshotExporterTests`: verified `-vf` scale filter selection for `swapsVideoDimensions` and verified bundled FFmpeg extraction of anamorphic `144×108` (`SAR 4:3`) + 90° rotated video produces `108×192`.
  - `AnkiPackageExporterTests`: verified `.apkg` screenshot extraction for anamorphic `144×108` (`SAR 4:3`) + 90° rotated video produces `108×192`.

## Outcome

All targeted unit tests passed and matched the requirement specifications and review criteria.

## Follow-ups

- User E2E verification on real rotated/flipped media files.
