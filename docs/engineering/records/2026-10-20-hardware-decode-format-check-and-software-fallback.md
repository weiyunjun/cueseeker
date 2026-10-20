# Hardware Decode Format Check And Software Fallback

Human-owned documents:

- `docs/human/requirements/20261020-Bug-Hardware Decode Format Check And Software Fallback.md`
- `docs/human/design/playback/Playback Core.md`
- `docs/human/design/playback/Playback Edge Cases.md`

## Why

1. **Open-Time Codec-Only Check Missed Unsupported Bit Depths & Chroma Formats**:
   - Previously, `prepareHardwareVideoWithError:` only checked broad codec support via `VTIsHardwareDecodeSupported` (e.g., HEVC, VP9, AV1, H.264).
   - For videos with unsupported bit depths (e.g., **HEVC 12-bit / Main 12**, **VP9 12-bit**, **AV1 12-bit**, **H.264 12-bit**), unsupported chroma subsampling (e.g., **VP9 / AV1 4:2:2 / 4:4:4 / RGB / monochrome**), or non-8-bit-4:2:0 **H.264** (`Hi10P`, `4:2:2`, `4:4:4`, `RGB`), `prepareHardwareVideoWithError:` opened the decoder and locked `_usingHardwareDecode = YES`.
   - On M3/M4+ chips (where `VTIsHardwareDecodeSupported(kCMVideoCodecType_AV1)` returns true), opening an AV1 12-bit or 4:2:2/4:4:4 stream selected FFmpeg's hardware-only `av1` parser instead of `libdav1d`, which then failed with `ENOSYS` on every packet.
2. **First-Frame Silent Software Downgrade Dropped Every Decoded Frame**:
   - When FFmpeg's `ff_get_format` silently downgraded a session to software decoding on the first packet (`_videoFrame->format != AV_PIX_FMT_VIDEOTOOLBOX`), `handleVideoPacket:` checked `else if (!_usingHardwareDecode)` and dropped every decoded software frame because `_usingHardwareDecode` remained `YES`.
   - Because zero video frames were ever submitted, `didPresentVideoFrameAtMilliseconds:` never fired, leaving `pendingPresentation` uncommitted — resulting in audio playing against a black screen with a frozen/unscrubbable timeline.

## What changed

1. **Open-Time Pixel Format, Bit Depth, Chroma Subsampling & Profile Validation (`CNativePlayback`, `CueSeekerPlayback`)**:
   - In `SFXIsHardwareDecodeSupported`, ensured `VTRegisterSupplementalVideoDecoderIfAvailable(codecType)` (and `VTRegisterProfessionalVideoWorkflowVideoDecoders()` for ProRes) is invoked before querying `VTIsHardwareDecodeSupported(codecType)`, so VP9 8-bit/10-bit 4:2:0 hardware support is accurately reported from process launch.
   - Added `SFXIsHardwareDecodeSupportedForCodecAndPixelFormat` and `SFXIsHardwareDecodeSupportedForParameters` in `SFXNativePlaybackPlayer.m`, checking both `VTIsHardwareDecodeSupported` (distinguishing M1/M2 vs M3/M4+ for AV1) and stream pixel format / bit depth / chroma subsampling / profile:
     - Rejects any >10-bit or 9-bit format across HEVC, VP9, AV1, and H.264 (e.g., 12-bit `yuv420p12le`, `yuv422p12le`, `yuv444p12le`) and routes directly to software decoding at open time.
     - Rejects RGB and non-3-component formats for HEVC, and rejects non-4:2:0 formats (`4:2:2`, `4:4:4`, monochrome) for VP9 and AV1 (ensuring M3/M4+ routes high-chroma/12-bit AV1 directly to `libdav1d`).
     - Rejects non-8-bit-4:2:0 formats (`10-bit`, `4:2:2`, `4:4:4`, `RGB`) for H.264.
   - Exposed `+isHardwareDecodeSupportedForCodecName:pixelFormatName:` on `SFXNativePlaybackPlayer` and `PlaybackHardwareCapabilities.isHardwareDecodeSupported(forCodec:pixelFormat:)`.
2. **First-Packet & First-Frame Runtime Software Fallback (`CNativePlayback`)**:
   - In `handleVideoPacket:`, if `avcodec_send_packet` fails on the initial packet while in hardware mode, automatically resets the hardware decoder context, opens the software video decoder (`libdav1d` / `hevc` / `vp9` / `h264`), and retries the packet in-place.
   - In `handleVideoPacket:`, if a decoder opened in hardware mode outputs a software `AVFrame` (e.g., silent `ff_get_format` fallback), transitions the session to software rendering (`_usingHardwareDecode = NO`) and submits the converted `CVPixelBuffer` instead of dropping the frame.
3. **Tests (`CueSeekerPlaybackTests`)**:
   - Added `nativePlaybackHardwareDecodeFormatCheckMatrix` and `nativePlaybackFallsBackToSoftwareAndPresentsFramesForHEVC12BitAndVP9HighChroma` in `NativePlaybackMediaTimelineTests.swift`.

## Verification

- `swift test --package-path apps/macos-native --filter "nativePlaybackHardwareDecodeFormatCheckMatrix|nativePlaybackFallsBackToSoftwareAndPresentsFramesForHEVC12BitAndVP9HighChroma"`
