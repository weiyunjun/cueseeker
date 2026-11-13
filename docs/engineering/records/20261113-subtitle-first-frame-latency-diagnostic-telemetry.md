# Subtitle First-Frame Latency Diagnostic Telemetry Implementation Record

- Date: 2026-11-13
- Related Requirement: `docs/human/requirements/20261113-Engineering-Subtitle First Frame Latency Diagnostic Telemetry.md`
- Scope: Diagnostic telemetry instrumentation in `CueSeekerPlayback` (`PlaybackPlayer`, `SourceFaithfulASSSubtitleOverlayView`, `SRTSubtitleOverlayView`) with zero behavior or rendering schedule changes.

## Changes Made

- **Telemetry Core (`apps/macos-native/Sources/CueSeekerPlayback/PlaybackSubtitleFirstFrameTelemetry.swift`)**:
  - Defined `PlaybackSubtitleFirstFrameTrigger` (`new_video_open`, `same_video_seek`, `manual_subtitle_switch`) and `PlaybackSubtitleCommitSyncState` (`none`, `hidden`, `sync_ready`, `async_pending`).
  - Added thread-safe cancellable `PlaybackSubtitleFirstFrameAttempt` measuring non-overlapping `prep_ms` (`0` when reusing an already-ready source), `first_frame_ms` (from render start/prep completion to main-thread `CALayer` update), `lag_ms` (`0` when synchronously ready at video first-frame commit or on manual subtitle track switch), and `total_ms`.
  - Emits `"Subtitle first frame presented"` via `AppLogger.shared` under `.debug` (controlled by `AppDiagnosticTelemetryCollectionMode` / `AppBuildConfiguration`) and escalates to `.warn` when `lag_ms > 33.0` or `prep_ms + first_frame_ms >= 200.0`, while exposing in-memory test observers so unit tests incur zero disk log writes.

- **Overlay Main-Thread Presentation Endpoints (`SourceFaithfulASSSubtitleOverlayView.swift`, `SRTSubtitleOverlayView.swift`)**:
  - Wired ASS worker load + render completion (`apply(frame)` -> `CALayer` update) and SRT cue load/layout + image assignment (`imageLayer.contents`) so timing completes only after main-thread display layer updates finish.
  - Handled synchronous same-video seek reuse (`sync_ready`), in-flight render sequencing, source-load failures, and immediate cancellation on superseding switches, clearing source, or hiding subtitles without touching existing scheduling.

- **Player Presentation Commit & Switch Orchestration (`PlaybackPlayer.swift`)**:
  - Tagged `PendingPresentation` with `.newVideoOpen` vs `.sameVideoSeek` and included `subtitle_sync=...` in `"Playback presentation committed"` (`AppLogger.shared.info`) explicitly separating `none`, `hidden`, `sync_ready`, and `async_pending`.
  - Tracked `.manualSubtitleSwitch` in `loadSubtitleSource(_:)` and cancelled active telemetry attempts synchronously on `stop()`, `cancelPendingPresentation()`, superseding transitions, and `setSubtitlesVisible(false)`.

- **Automated Tests (`apps/macos-native/Tests/CueSeekerPlaybackTests/PlaybackSubtitleFirstFrameTelemetryTests.swift`)**:
  - Covered real ffmpeg-backed video open, same-video seek reuse/replace, manual subtitle track switching for both ASS and SRT paths, hidden/no-subtitle presentation commit states, rapid superseding switches and `stop()` cancellation, continuous playback tick silence, `WARN` escalation thresholds, `AppDiagnosticTelemetryCollectionMode` filtering, and zero disk log verification.

## Verification

- `swift build --package-path apps/macos-native` — Build complete (0 errors).
- `swift test --package-path apps/macos-native --no-parallel --filter "CueSeekerPlaybackTests|PlaybackPresentationTransitionTests|AppLoggerTests"` — 129 tests passed, 0 failures.
