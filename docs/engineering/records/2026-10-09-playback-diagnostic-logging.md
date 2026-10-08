# Playback Diagnostic Logging

Human-owned documents:

- `docs/human/requirements/20261009-Bug-AV1 Hardware Capability Detection And Software Fallback.md`
- `docs/product/06_playback_requirements.md`

## Why

1. **Decoder Pipeline Diagnostics**:
   - To inspect and verify video decoding pipeline behavior on current hardware (such as M4 Apple Silicon) and prepare for fallback testing on M1 hardware, structured diagnostics logging is needed when triggering playback, switching decoder settings, opening new video sessions, or seeking within existing playback sessions.
2. **Settings Propagation Visibility**:
   - When users switch the Decoder option in Settings (`Hardware`, `Software`, `Auto`), logging ensures that state changes are observable across `SettingsStore`, `AppCoordinator`, `PlaybackPlayer`, and `SFXNativePlaybackPlayer`.

## What changed

1. **Expose Decoder Hardware State (`SFXNativePlaybackPlayer.h`, `SFXNativePlaybackPlayer.m`, `PlaybackPlayer.swift`)**:
   - Added `usingHardwareDecode` read-only property to `SFXNativePlaybackSession`, `SFXNativePlaybackPlayer`, and `PlaybackPlayer` to surface whether the currently active playback pipeline is running on VideoToolbox hardware decode or software decode.
2. **Playback Preparation & Session Logging (`SFXNativePlaybackPlayer.m`)**:
   - In `prepareVideoWithError:`, logged video path, codec name, requested decode mode setting (`Hardware`, `Software`, `Auto`), effective decoding pipeline (e.g. `Hardware (VideoToolbox, av1)` or `Software (libdav1d)`), and any fallback error message.
   - In `seekToMilliseconds:...`, logged in-session seek actions and current session pipeline mode.
   - In `setDecodeMode:`, logged decode mode transitions.
3. **Application & Player Level Logging (`PlaybackPlayer.swift`, `AppCoordinator.swift`, `AppCoordinator+Playback.swift`, `AppCoordinator+PlaybackAudioTrack.swift`)**:
   - In `PlaybackPlayer.open` and `PlaybackPlayer.seek`, logged requests with target path/timestamps and decoder configurations.
   - In `AppCoordinator.settings.$playbackDecodeMode`, logged preference updates.
   - In `AppCoordinator.play(_:)` and `canSeekInOpenVideo(for:)`, logged cue playback dispatch and whether an in-video seek or full session reopening is executed.

## Verification

- `swift build --product CueSeeker --package-path apps/macos-native`: succeeded.
- `swift test --package-path apps/macos-native --filter SettingsStorePlaybackTests`: passed (8/8 tests passed).
- `swift test --package-path apps/macos-native --filter PlaybackRequestTests`: passed (40/40 tests passed, verified `[Playback]` logs in test output).
