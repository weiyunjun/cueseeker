# Animated Subtitle Staged Slot Micro-Offset Same-Frame Presentation

- Date: 2026-11-14
- Related Requirement: `docs/human/requirements/20261114-Engineering-Animated Subtitle Staged Slot Micro Offset Same Frame Presentation.md`
- Scope: `CASSRendering`, `CueSeekerPlayback`, `CASSRenderingTests`, `CueSeekerPlaybackTests`

## Changes Made

- **Exposed unchanged active-event-set window bounds from `CASSRendering`**:
  - Added readonly `activeEventSetFromMilliseconds` and `activeEventSetUntilMilliseconds` properties to `SFXASSCroppedRenderOutput` in `SFXASSRenderer.h` and `SFXASSRenderer.m`.
  - Replaced `SFXComputeASSUnchangedWindow` with single-pass `SFXComputeASSRenderWindows` to simultaneously compute `unchanged` (still narrowing to `t ..< t + 1` for animated events so steady playback keeps frame-accurate animation) and `activeEventSet` (keeping the full `[from, until)` interval bounded by active events' `Start`/`End`, nearest future `Start`, and nearest past `End`).
  - Clamped both windows via `SFXClampASSWindowToRange` when `_usesWindowedEvents == YES`, and cached `_lastActiveEventSetFromMilliseconds` / `_lastActiveEventSetUntilMilliseconds` on `SFXASSRendererSession` (reset on frame resize, window reload, and `renderFrameAtTimestampMilliseconds:`) so `changed == NO` fast hits carry matching active-set boundaries.
- **Tolerated single-frame micro-offsets on deferred ASS presentation with silent background refinement**:
  - Updated `ASSRenderedFrame` and `SourceFaithfulASSSubtitleOverlayView` (`SourceFaithfulASSSubtitleOverlayView.swift`) to track `renderedActiveSetRangeMilliseconds` (cleared alongside `renderedValidRangeMilliseconds` on state clears, in-place resizes, and forced renders) and define `firstFrameMicroOffsetToleranceMilliseconds = 50`.
  - Added `canReuseStagedFrameForMicroOffset(atMilliseconds:)` gated to deferred presentation (`defersLayerPresentation && isRendererReady && !loadFailedForCurrentSource && failureMessage == nil`) requiring `abs(target - t_staged) <= 50` AND `renderedActiveSetRangeMilliseconds.contains(target)`.
  - Handled **Timing A** (`t_staged` completes before `retargetDeferredPresentation`: update `currentTimeMilliseconds` without dispatching a pre-gate render so `isPreparedForPresentation` immediately succeeds) and **Timing B** (`retargetDeferredPresentation` queues `pendingTimestampMilliseconds` while `t_staged` is in flight: upon `t_staged` completion, clear `pendingTimestampMilliseconds`, retain `renderedTimestampMilliseconds == t_staged` and `currentTimeMilliseconds == t_actual`, mark `stagedReadyAt`, and fire `onPreparedFrameReady?()` immediately without blocking the vertical-sync gate).
  - Updated `flushDeferredLayerPresentation(isSynchronousCommit:committedAt:)` to present the staged `.sparse` frame and complete `pendingTelemetryRender` synchronously (`lag_ms == 0`) first, then dispatch a background `requestRender()` when `renderedTimestampMilliseconds != currentTimeMilliseconds` (and outside `renderedValidRangeMilliseconds`) for silent in-place layer refinement without clearing visible content or duplicating telemetry.
  - Updated `commitPreservedPresentation` to call `requestRender(force: true)` when `videoSize` and `currentTimeMilliseconds` are unchanged yet current cache does not cover `safeMilliseconds`.
- **Added automated unit and E2E tests**:
  - Added active-event-set window tests (`testActiveEventSetWindowPreservesBoundariesForAnimatedAndOverlappingEvents`, `testActiveEventSetWindowClampsToLoadedWindowAndPreservesCacheHit`) in `apps/macos-native/Tests/CASSRenderingTests/CASSRenderingProbeTests.swift`.
  - Added overlay and `PlaybackPlayer` E2E tests (`animatedASSSubtitleOverlayMicroOffsetTimingAAndTimingBAndRefinement`, `animatedASSSubtitleOverlayRejectsCrossBoundaryOverThresholdAndResolutionChange`, `e2ePlaybackPlayerAnimatedASSSubtitleMicroOffsetSyncCommitAndRefinement`, `e2ePlaybackPlayerRejectsCrossBoundaryAndOverThresholdWhilePreservingRepeat2msAlignment`) in `apps/macos-native/Tests/CueSeekerPlaybackTests/PlaybackVerticalSyncAndIndexedASSTests.swift`.

## Verification

- `swift build --package-path apps/macos-native` passed.
- `swift test --package-path apps/macos-native --no-parallel --filter "CASSRenderingTests|CueSeekerPlaybackTests"` passed with 0 failures (`CASSRenderingProbeTests`: 12 passed; `CueSeekerPlaybackTests` Swift Testing: 135 passed).
- `swift test --package-path apps/macos-native --no-parallel --filter PlaybackPresentationTransitionTests` passed with 0 failures (`9 passed`).
