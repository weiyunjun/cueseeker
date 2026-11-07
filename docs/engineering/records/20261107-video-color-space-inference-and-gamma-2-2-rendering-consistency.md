# Video Color Space Inference and Gamma 2.2 Rendering Consistency

## Summary

- Requirement: `docs/human/requirements/20261107-Bug-Video Color Space Inference And Gamma 2.2 Rendering Consistency.md`
- Design: `docs/human/design/playback/Playback Core.md`
- Unified video color space, primaries, transfer function, and range resolution across hardware and software playback (`SFXVideoToolboxSupport.m`, `SFXNativePlaybackInternal.h`, `SFXNativePlaybackSession+AudioAndDecode.m`):
  - Added `SFXResolveVideoColorSpace`, `SFXResolveVideoColorPrimaries`, `SFXResolveVideoColorTransfer`, and `SFXResolveVideoIsFullRange`: preserves explicit stream/frame metadata when present, and infers `BT.709` for untagged HD (`width > 1280 || height > 576`) and `BT.601` (`SMPTE-C` / `EBU 3213` by frame rate) for untagged SD with limited range as the YUV default.
  - Added `SFXApplyColorSpaceAttachments` and applied it to both VideoToolbox hardware-decoded `CVPixelBuffer` frames and software-decoded `CVPixelBuffer` frames, tagging SDR content with `kCVImageBufferTransferFunction_sRGB` (Gamma 2.2) alongside the resolved matrix and primaries while preserving `PQ` / `HLG` / `Linear` transfer curves for HDR content.
  - Added `SFXConfigureSwsContextColorSpace` to configure `libswscale` (`sws_setColorspaceDetails`) with the resolved color matrix and source/destination range before `sws_scale`.
- Aligned screenshot, collage, timeline scrub thumbnail, and library cover color space handling (`SFXKeyframeScrubPreviewDecoder.m`, `SFXMediaMetadataInspector.m`, `SubtitleScreenshotExporter.swift`, `LibraryCoverIndexer.swift`, `AnkiPackageExporter.swift`):
  - Configured `libswscale` contexts in `SFXKeyframeThumbnailDecoder` and `SFXMediaMetadataInspector` (`SFXCreateCoverCandidateFrame`) via `SFXConfigureSwsContextColorSpace`.
  - Exposed `inferredColorMatrix` on `SFXMediaContainerProbe` (`"bt709"` for untagged HD streams) and `SFXFFmpegPixelAspectRatioScaleFilterWithColorMatrix` so FFmpeg CLI frame extraction in `SubtitleScreenshotExporter`, `LibraryCoverIndexer`, and `AnkiPackageExporter` applies `:in_color_matrix=bt709` instead of defaulting to `bt601`, and standardized `SubtitleScreenshotExporter` bitmap contexts and decoded frame images on `CGColorSpace.sRGB`.

## Verification

- `swift test --package-path apps/macos-native --filter "SubtitleScreenshotExporterTests|PlaybackCurrentFrameScreenshotTests"`
