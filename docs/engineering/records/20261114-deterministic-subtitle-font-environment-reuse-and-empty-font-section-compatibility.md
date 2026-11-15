# 2026-11-14 Deterministic ASS Subtitle Font Environment Reuse and Empty `[Fonts]` Section Compatibility

- **Covering Requirement**: `docs/human/requirements/20261114-Engineering-Deterministic Subtitle Font Environment Reuse And Empty Font Section Compatibility.md`
- **Requirement Commit**: `3ddc931`
- **Target Branch**: `main`

## 1. Summary of Changes

1. **Serialize ASS subtitle renderer worker teardown and creation (`SourceFaithfulASSSubtitleOverlayView.swift`)**:
   - Each `SourceFaithfulASSSubtitleOverlayView` instance now holds a shared serial `DispatchQueue` (`workerQueue`), injecting it into newly created `SourceFaithfulASSRendererWorker(queue: workerQueue)` instances during initialization and on every `replaceRendererWorker()`.
   - Preserves the semantics of creating a fresh `SourceFaithfulASSRendererWorker` instance on each `replaceRendererWorker()` (keeping `rendererWorkerIdentityForTesting` assertions intact), while synchronously calling `previousWorker.invalidate()` before constructing the new worker to enqueue `previousWorker.clearState()`. Invalidated workers immediately skip loading and rendering at queue task entry so `session?.close()` returns the pooled engine strictly before the new session checks out from the pool, eliminating concurrent race cold-builds during cross-episode track switches or rapid consecutive jumps.

2. **Invalidate pooled engines on system font changes (`SFXASSRenderer.h/.m`, `ASSFontAliasResolver.swift`)**:
   - Added `+ (void)invalidateFontEnvironmentPool;` to `SFXASSRenderer` and introduced generation counter `gSFXASSEnginePoolGeneration` in the global engine pool. Invalidation increments the generation, destroys all idle `(ASS_Library *, ASS_Renderer *)` instances in the pool, and resets `gSFXASSHasCompletedWarmup = NO`.
   - `SFXASSRendererSession` records the borrowed `_enginePoolGeneration` on checkout and returns the engine to the pool only when the generation still matches `gSFXASSEnginePoolGeneration` and capacity remains; stale sessions continue rendering normally for their lifetime and destroy old-generation engines on close without polluting the refreshed pool. Concurrent warmup and non-warmup creation paths also verify the captured generation before updating completion flags or returning engines to the pool.
   - Extracted shared helper `SFXApplyASSRendererFrameSize` to unify positive `Int32` clamping across `SFXCreateASSEngineContext`, `SFXCheckoutASSEngineContext` (pooled reuse), and `updateFrameWidth:frameHeight:`.
   - Distinguished shared instance `ASSFontAliasResolver.shared` (`invalidatesSharedRendererPool = true`) from isolated test instances `ASSFontAliasResolver(observeSystemFontChanges:)` (`invalidatesSharedRendererPool = false`), so runtime `kCTFontManagerRegisteredFontsChangedNotification` events or shared environment refreshes invoke `SFXASSRenderer.invalidateFontEnvironmentPool()` without allowing isolated unit tests to clear the global pool, using `environmentGeneration` to prevent concurrent notifications during a scan from clearing pending refresh state.

3. **Empty `[Fonts]` placeholder section compatibility in full-file fallback path (`SFXASSRenderer.m`)**:
   - Rewrote `SFXBytesContainEmbeddedFontsSection` to align with `ASSEventOffsetIndex` section parsing: skips optional UTF-8 BOM, enters `[Fonts]`, exits on any subsequent `[...]` section header, and returns `YES` only when `[Fonts]` contains at least one trimmed non-empty embedded font data line that does not start with `;` or `!:`. Empty `[Fonts]` placeholder sections (including whitespace-only or comment-only lines) return `NO` and reuse the shared pool normally.

4. **Automated regression test additions and tightened assertions**:
   - Tightened cross-episode reuse assertion `engineCountAfterEp2 <= 2` in `PlaybackVerticalSyncAndIndexedASSTests.swift` to strict `PlaybackPlayer.assEngineInitializationCountForTesting == 1` (covering manual track switches and switching back to episode 1).
   - Added rapid unawaited 5-episode `player.open(...)` jump reuse tests, unindexed full-file fallback tests for empty `[Fonts]` placeholder reuse vs. non-empty embedded font isolation (without polluting the shared pool), and system font change notification tests verifying graceful teardown of active sessions, exact `+1` new-generation pool rebuild, and continued cross-episode reuse afterward.
   - Added direct unit tests in `CASSRenderingProbeTests.swift` covering empty `[Fonts]` placeholder parsing, embedded font isolation, and `SFXASSRenderer.invalidateFontEnvironmentPool()` generation retirement.

## 2. Modified Files

- `apps/macos-native/Sources/CueSeekerPlayback/SourceFaithfulASSSubtitleOverlayView.swift`
- `apps/macos-native/Sources/CASSRendering/include/SFXASSRenderer.h`
- `apps/macos-native/Sources/CASSRendering/SFXASSRenderer.m`
- `apps/macos-native/Sources/CueSeekerPlayback/ASSFontAliasResolver.swift`
- `apps/macos-native/Tests/CueSeekerPlaybackTests/PlaybackVerticalSyncAndIndexedASSTests.swift`
- `apps/macos-native/Tests/CASSRenderingTests/CASSRenderingProbeTests.swift`

## 3. Verification

- `swift build --package-path apps/macos-native` — Build complete (`0` failures).
- `swift test --package-path apps/macos-native --no-parallel --filter "CueSeekerPlaybackTests|CASSRenderingTests|PlaybackRequestTests|PlaybackVerticalSyncAndIndexedASSTests"` — `141` tests executed and passed (`10` XCTest in `CASSRenderingProbeTests` + `131` Swift Testing in `CueSeekerPlaybackTests`, including `PlaybackRequestTests` and `PlaybackVerticalSyncAndIndexedASSTests`), `0` failures, `0` skipped.
