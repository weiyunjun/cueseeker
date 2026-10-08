# AV1 Hardware Capability Detection And Software Fallback

Human-owned documents:

- `docs/human/requirements/20261009-Bug-AV1 Hardware Capability Detection And Software Fallback.md`
- `docs/product/06_playback_requirements.md`

## Why

1. **AV1 Playback on Non-Supporting Hardware (e.g. M1 Apple Silicon)**:
   - Apple Silicon M1/M2 chips lack a hardware AV1 decoder. FFmpeg statically advertises VideoToolbox capabilities for AV1, which previously caused the native player to attempt hardware initialization without proper runtime validation, leading to decode failures and playback stalls.
2. **Two-Gate Capability Detection Architecture**:
   - **Gate 1 (Metadata Pre-routing)**: Pre-routes playback to software decoding using index-time metadata stored in the database if the hardware is known to not support hardware decoding for that codec.
   - **Gate 2 (Runtime Fallback)**: Real-time bitstream-level hardware capability check using `VTIsHardwareDecodeSupported` before configuring VideoToolbox. If hardware decoding is unavailable or fails, dynamically falls back to software decoding (e.g. `libdav1d` for AV1).
3. **Immediate Decoder Setting Effect**:
   - Align `Hardware` and `Auto` modes to prioritize hardware decoding and automatically fall back to software.
   - When switching decoder settings in Preferences (`Hardware`, `Software`, `Auto`), subsequent cue playback or item switching immediately adopts the new decoder by invalidating `canSeekInOpenVideo` when the session's active decode mode mismatches the target mode.

## What changed

1. **Hardware Capability Detection in Native Core (`CNativePlayback`)**:
   - In `SFXNativePlaybackPlayer.m` and `SFXNativePlaybackPlayer.h`, implemented `SFXIsHardwareDecodeSupported` and `SFXIsHardwareDecodeSupportedForCodecName` wrapping `VTIsHardwareDecodeSupported`.
   - Exposed `+isHardwareDecodeSupportedForCodecName:` and `@property activeDecodeMode` on `SFXNativePlaybackPlayer`.
   - In `prepareHardwareVideoWithError:`, checked `SFXIsHardwareDecodeSupported` and returned a descriptive error (`"Hardware decode is not supported by current device for <codec>."`) upon failure.
   - Unified `Hardware` and `Auto` mode handling in `prepareVideoWithError:` so both attempt hardware decoding first and smoothly fall back to software decoding (`libdav1d`).
2. **Gate 1 Pre-routing and Database Support (`CueSeekerCore`, `CueSeekerPlayback`, `CueSeekerApp`)**:
   - Added `videoCodec(forVideoPath:)` on `LibraryDatabase` to query indexed video codec metadata.
   - Added `PlaybackHardwareCapabilities.isHardwareDecodeSupported(forCodec:)` and `activeDecodeMode` on `PlaybackPlayer`.
   - In `AppCoordinator+Playback.swift`, implemented `resolveInitialDecodeMode(forVideoPath:)` and `prepareDecodeModeForPlayback(videoPath:)` to pre-route unsupported codecs directly to software decoding.
   - In `AppCoordinator+PlaybackAudioTrack.swift`, enhanced `canSeekInOpenVideo(for:)` to check `player.activeDecodeMode == player.decodeMode`, ensuring modified settings or routed decoders trigger a full session reopen on the next playback item.
3. **Structured Playback Diagnostics Logging**:
   - Logged video path, codec, user setting mode, target mode, active pipeline, and fallback reasons across `AppCoordinator.play`, Gate 1, Gate 2, `prepareVideoWithError:`, and `canSeekInOpenVideo`.
4. **Unit Tests**:
   - Added `videoCodecForVideoPathReturnsIndexedCodec` in `LibraryDatabaseTests.swift`.
   - Added `playbackHardwareCapabilitiesDetectsCodecs` and verified `activeDecodeMode` in `PlaybackRequestTests.swift`.

## Verification

- `swift build --package-path apps/macos-native`: succeeded.
- `swift test --package-path apps/macos-native --filter PlaybackRequestTests`: passed (41/41 tests passed).
- `swift test --package-path apps/macos-native --filter CueSeekerPlaybackTests`: passed (83/83 tests passed).
- `swift test --package-path apps/macos-native --filter LibraryDatabaseTests`: passed.
- `swift test --package-path apps/macos-native --filter CueSeekerCoreTests`: passed (325/325 tests passed).
