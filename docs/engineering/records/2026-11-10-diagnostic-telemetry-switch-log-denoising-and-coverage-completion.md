# Diagnostic Telemetry Switch, Log Denoising And Coverage Completion

Human-owned documents:

- `docs/human/requirements/20261110-Engineering-Diagnostic Telemetry Switch Log Denoising And Coverage Completion.md`
- `docs/human/design/system/Logging.md`

## Why

1. **Support Engineering-Level Deep Diagnostic Collection in Release Builds**:
   - Diagnostic telemetry (`DEBUG`-level interaction latency, playback interval summaries, and open/seek breakdowns) previously relied on `#if DEBUG` compile-time stripping, preventing Release builds from collecting deep diagnostic telemetry when needed for troubleshooting user-reported issues.
2. **Eliminate Log Spam, False-Positive Stalls, and Duplicate/Opaque Entries**:
   - Static image rendering (`playback.static_image.render`), 1-second periodic playback heartbeats (`playback.diagnostics.heartbeat`), and per-frame slow frame warnings flooded logs.
   - Main-thread stall monitoring (`AppPerformanceProbe` / `DebugInteractionLatencyProbe`) treated `exit -> entry` RunLoop idle gaps as multi-second stalls and used an overly sensitive `32ms` threshold.
   - Opening the cover summary description popover logged twice due to synchronous re-evaluation during text-selection clearing, and dialog open telemetry logged raw `UUID` strings for confirmation/session dialogs.
3. **Improve Release User Experience and Close 4 Diagnostic Blind Spots**:
   - Raw user search queries and prefilled subtitle text appeared in Release logs.
   - High-value technical diagnostics (video color state/tone-mapping, WebDAV 302 resolution latency, memory pressure relief, main-thread stalls `>= 200ms`) and 4 key blind spots (startup hardware environment, Gate 2 hardware decode fallback warnings, native open/first-frame/seek stage breakdowns, and per-card Anki export failure reasons) were missing from Release logs.

## What Changed

1. **Engineering-Level Diagnostic Telemetry Switch (`AppLogger.swift`, `DebugInteractionLatencyProbe.swift`, `SFXHDRColorPipeline.m`, `PlaybackPlayer.swift`)**:
   - Added `AppDiagnosticTelemetryCollectionMode` (`.debugOnly`, `.debugAndRelease`) with single code-level switch `AppDiagnosticTelemetryCollectionMode.current`.
   - Replaced `#if DEBUG` compile-time stripping in `DebugInteractionLatencyProbe` and `CNativePlayback` telemetry with runtime checks against `AppLogger.isDiagnosticTelemetryEnabled()`.
2. **Log Denoising & Deduplication (`SFXHDRColorPipeline.m`, `SFXNativePlaybackSession.m`, `SFXNativePlaybackSession+AudioAndDecode.m`, `AppPerformanceProbe.swift`, `DebugInteractionLatencyProbe.swift`, `CoverSummaryCard.swift`, `ContentView.swift`, `SettingsView.swift`, `PlaybackPlayer.swift`, `AppCoordinator*.swift`)**:
   - Replaced per-image `playback.static_image.render` logs with `playback.static_image.slow_render` warnings emitted only when decode + render takes `>= 200ms`.
   - Excluded `exit -> entry` RunLoop idle gaps from main-thread stall detection and raised the stall threshold from `32ms` to `200ms`.
   - Removed 1-second `periodic` playback heartbeats (`playback.diagnostics.heartbeat`), emitting interval summaries only on `pause`, `seek`, and `stop` when frames were processed, and rate-limited `playback.diagnostics.slow_frame` to once per `5s`.
   - Suppressed `< 100ms` routine menu open and menu item action logs in Release builds (emitting `.warn` with `slow_menu=true` when `>= 100ms`), deduplicated in-flight `recordMenuGateOpen` calls so `coverSummaryDescriptionPopover` logs once, normalized dialog IDs to human-readable names, and removed redundant low-level logs (`Player decode mode updated`, `Player opening media`, `Evaluated in-session seek eligibility`).
3. **Release Query Redaction & High-Value Diagnostics Promotion (`AppLogger.swift`, `SearchStore+Execution.swift`, `ExcerptStore+Execution.swift`, `AppCoordinator+PlaybackCommandPanel.swift`, `AppCoordinator+URLScheme.swift`, `WebDAVSupport.swift`, `AppMemoryPressureRelief.swift`)**:
   - Added `AppLogger.queryLogField` to log `query_len` / `prefilled_query_len` in Release builds while preserving raw `query` / `prefilled_query` in Debug builds.
   - Promoted `playback.stream.color_state`, `WebDAV playable URL resolved`, and `Memory pressure relief triggered` to `.info`, and `Main thread stall detected` (`>= 200ms`) to `.warn`.
4. **Diagnostic Blind Spot Completion (`AppDelegate.swift`, `SFXNativePlaybackSession.m`, `SFXNativePlaybackSession+AudioAndDecode.m`, `PlaybackPlayer.swift`, `AnkiPackageExporter.swift`)**:
   - Added `arch`, `chip`, `memory_gb`, `main_display_hdr`, and `max_edr_headroom` to `App launched`.
   - Emitted `playback.hardware_decode.fallback` warnings across all Gate 2 runtime fallback paths (`open_init`, `first_packet`, `first_frame_pixel_buffer`).
   - Bridged `playback.diagnostics.open_prepare` and `playback.diagnostics.first_frame` (alongside `playback.diagnostics.seek`) into `AppLogger` (`.warn` when slow, `.debug` otherwise).
   - Logged per-card `Anki card export failed` warnings with `card_index`, `stage` (`validation`, `audio_extraction`, `frame_screenshot`, `file_write`), `file`, `start_ms`, `end_ms`, and `reason`.

## Verification

- Automated tests:
  - `swift test --package-path apps/macos-native --filter "AppLoggerTests|DebugInteractionLatencyProbeTests|WorkbenchDialogLayerTests|AnkiPackageExporterTests"`
