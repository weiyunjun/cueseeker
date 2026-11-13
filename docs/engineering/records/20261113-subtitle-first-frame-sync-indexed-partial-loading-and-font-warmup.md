# Subtitle First-Frame Sync, Indexed ASS Partial Loading, and Background Font Warmup Implementation Record

- Date: 2026-11-13
- Related Requirement: `docs/human/requirements/20261113-Bug-Subtitle First Frame Sync Indexed Partial Loading And Font Warmup.md`
- Scope: Synchronized audio-video-subtitle first-frame presentation ("vertical sync") in `CNativePlayback` and `CueSeekerPlayback`, read-only indexed `ASS/SSA` partial window loading with unindexed/invalidated full-file fallback, and single-flight launch-time subtitle font warmup with cross-episode engine reuse.

## Changes Made

- **Native First-Frame Presentation Gate (`CNativePlayback`)**:
  - Added `defersFirstFramePresentationCommit`, `commitPreparedPresentationForGeneration:`, and delegate callback `didPrepareFirstVideoFrameAtMilliseconds:videoWidth:videoHeight:presentationGeneration:` on `SFXNativePlaybackPlayer` / `SFXNativePlaybackSession`.
  - When deferred presentation commit is enabled, the native session decodes the target video first frame and primes initial audio buffers (including short `< 80ms` segment handling) while retaining the previous video frame on screen and holding audio playback start until `PlaybackPlayer` commits the prepared generation on the main thread.

- **Audio-Video-Subtitle Vertical Sync, Repeat `2ms` Alignment & Error vs. Timeout Separation (`PlaybackPlayer.swift`, `SourceFaithfulASSSubtitleOverlayView.swift`, `SRTSubtitleOverlayView.swift`, `PlaybackSubtitleFirstFrameTelemetry.swift`)**:
  - Added staged/deferred layer presentation modes to both `SourceFaithfulASSSubtitleOverlayView` (`ASS/SSA`) and `SRTSubtitleOverlayView` (`SRT`), preserving the previous video frame and previous subtitle layer contents across new-video opens, same-video seeks/cue switches, and manual subtitle track switches (`loadSubtitleSource`) with zero blank/black flashes, then committing video + subtitle + audio start together in a single `CATransaction`.
  - Preserved `PlaybackSeekTimestampAlignment` `2ms` `Repeat` alignment (`0 <= target - presented <= 2ms`) and retargeted staged subtitles to the actual aligned first-frame timestamp and resolved `videoSize` before releasing the gate.
  - Strictly separated direct subtitle read/decode failures (which immediately release the presentation gate, clear subtitles, and report `didFailToLoadSubtitleSource` for the top-left red `playback.error.subtitle_load_failed` banner) from post-video-ready `1000ms` preparation timeouts (timed strictly from video first-frame readiness, releasing video/audio silently without any error banner, clearing stale previous subtitles, and displaying the new subtitle once background preparation finishes while emitting `async_pending` / `lag_ms > 0` telemetry).
  - Preserved zero subtitle wait when `subtitleSource == nil` or `subtitlesVisible == false`.

- **Read-Only Indexed `ASS/SSA` Partial Window Loading & Fallback (`SourceFaithfulASSSubtitleOverlayView.swift`, `SFXASSRenderer.h/.m`, `PlaybackSubtitleDatabase.swift`, `ASSEventOffsetIndex.swift`, `WebDAVSupport.swift`, `AppCoordinator+Playback.swift`)**:
  - Added `initWithASSHeader:sourceIdentifier:frameWidth:frameHeight:windowEventLinesProvider:error:` in `SFXASSRenderer` so indexed `ASS/SSA` sessions initialize `libass` directly from `index.headerText` (with font alias rewrite) and slice only overlapping `Dialogue:` lines for the active `5s` window via `ASSEventOffsetIndex.overlappingEvents(in:)` + `readAndDecodeEventLines(...)`, preserving `ReadOrder` across multi-language and style-grouped lines without scanning or decoding the full file.
  - Added bounded in-memory `ValidatedASSOffsetIndexMemoryCache` keyed by media path + cache scope and live file size/mtime fingerprint checks on both session open and `5s` window reloads, supporting both local and cached remote (`WebDAV`/`SMB`/`FTP`/`NFS`) subtitles via `WebDAVSubtitleCache.ensureSubtitleAvailable(for:)` without unnecessary full-file `Data` loads on open.
  - Seamlessly falls back to full-file sequential loading whenever a subtitle is unindexed, marked `ineligible` (such as embedded `[Fonts]`), or externally modified before or during playback, with strictly zero SQLite writes during playback.

- **Launch-Time Single-Flight Font Warmup & Cross-Episode Engine Reuse (`ASSFontAliasResolver.swift`, `SFXASSRenderer.h/.m`, `PlaybackPlayer.swift`, `AppDelegate.swift`)**:
  - Added single-flight `NSCondition`-synchronized `ASSFontAliasResolver.warmUp()` with session-level in-memory table caching invalidated on `kCTFontManagerRegisteredFontsChangedNotification`, alongside `+[SFXASSRenderer warmUpFontEnvironment]` backed by a 2-slot `(ASS_Library *, ASS_Renderer *)` CoreText font provider pool (isolating embedded-font scripts so custom attachments never pollute pooled instances) and reusing `_library`/`_renderer` across `5s` window reloads without `mkstemp` temp files.
  - Triggered `PlaybackPlayer.warmUpSubtitleEnvironmentInBackground()` asynchronously in `AppDelegate.applicationDidFinishLaunching` without blocking UI launch; immediate playback shares the in-flight warmup rather than duplicating font scans.

- **Automated Tests (`PlaybackVerticalSyncAndIndexedASSTests.swift`, `PlaybackSubtitleFirstFrameTelemetryTests.swift`, `PlaybackStoreTests.swift`)**:
  - Added end-to-end headless muted (`setVolume(0)`) tests covering `ASS`/`SRT` first-frame vertical sync, blank-interval transitions, cross-format manual track switches, `Repeat` `2ms` alignment, direct read/permission/corrupt-encoding failure vs. post-video-ready timeout recovery, rapid switch cancellation, local + cached remote indexed `ASS` partial byte slicing, memory index reuse, unindexed/`[Fonts]`/pre-play & mid-play external edit fallback, strict zero-SQLite-write verification, single-flight concurrent font warmup, cross-episode engine reuse, and `AppCoordinator` subtitle error banner routing.

## Verification

- `swift build --package-path apps/macos-native` — Build complete (0 errors).
- `swift test --package-path apps/macos-native --no-parallel --filter "CueSeekerPlaybackTests|CASSRenderingTests|ASSEventOffsetIndexTests|PlaybackPresentationTransitionTests|PlaybackStoreTests"` — 152 tests passed (8 XCTest + 144 Swift Testing), 0 failures.
- `swift test --package-path apps/macos-native --no-parallel --filter "WebDAVSupportTests|PlaybackMoreMenuTests|PlaybackLibraryChangeTests|AppLoggerTests"` — All passed, 0 failures.
