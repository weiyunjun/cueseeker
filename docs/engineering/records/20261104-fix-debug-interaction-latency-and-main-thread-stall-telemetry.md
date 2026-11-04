# Fix Debug Interaction Latency And Main Thread Stall Telemetry

Human-owned documents:

- `docs/human/requirements/20261104-Bug-Fix Debug Interaction Latency And Main Thread Stall Telemetry.md`
- `docs/human/design/ui/UI Interaction Rules.md`
- `docs/human/design/ui/UI Layouts - Workbench.md`
- `docs/human/design/ui/UI Layouts - Playback.md`
- `docs/human/design/playback/Controller.md`
- `docs/human/design/playback/Command Panel.md`

## Why

1. **Missing Navigation Completion Logs & Stale Origin Pollution**:
   - In `WorkbenchWorkspaceView`, `PlaybackOverlay`, and `PlaybackCommandPanel`, synchronous/cached surface readiness caused `body` evaluation to update `lastPresentedSurface` / `lastPresentedModule` / `lastPresentedPage` to the target surface before `.onAppear` or `.onChange` ran, making the transition check evaluate to `false` and skipping `recordNavigationPreparation`.
   - Unconsumed pending navigation sessions also remained in `DebugInteractionLatencyProbe` and polluted subsequent immediate close transitions (e.g., logging `from=closed to=closed` when dismissing the overlay).
2. **Playback Chrome Menu Timing Inversion & Cross-Open Stale Timestamps**:
   - `PlaybackChromeMoreMenuOverlay` and `PlaybackChromeSubtitleMenuOverlay` mounted `MenuGateClientView` (consuming `activeMenuContext`) before `.onAppear` ran `measuredLayout` (which wrote `activeMenuContext`), and `PlaybackChromeSpeedMenuOverlay` wrote `activeMenuContext` on every SwiftUI `body` re-evaluation while the menu was already open. This left unconsumed timestamps in global state that were consumed seconds or tens of seconds later by the next menu open.
3. **False Main-Thread Stall Alerts on Idle RunLoop Wakeup (`beforeWaiting -> entry`)**:
   - `AppPerformanceProbe` only excluded `beforeWaiting -> afterWaiting`, causing `beforeWaiting -> entry` idle sleep durations (up to 45.5s of user inactivity) to be logged as main-thread stalls.

## What Changed

1. **Navigation Completion Telemetry & Pending Session Hygiene (`WorkbenchWorkspaceView.swift`, `PlaybackSubtitleFocusOverlay.swift`, `PlaybackCommandPanel.swift`, `AppCoordinator+PlaybackSubtitleFocus.swift`, `AppCoordinator+PlaybackCommandPanel.swift`, `DebugInteractionLatencyProbe.swift`)**:
   - Separated recorded transition tracking (`lastRecordedSurface`, `lastRecordedModule`, `lastRecordedPage`) from view-holding state (`lastPresented*`) and checked `DebugInteractionLatencyProbe.hasPendingNavigation(domain:)` so synchronous and cache-hit transitions always emit completion logs.
   - Updated `DebugInteractionLatencyProbe.completeImmediateNavigation` to only inherit `fromSurface` / `trigger` / `startedAt` from a pending session when its `toSurface` matches, and cleared pending sessions on forced dismissal/invalidation.
2. **Playback Chrome Menu Telemetry Ordering & Cleanup (`PlaybackChromeMoreMenu.swift`, `PlaybackChromeSpeedMenu.swift`, `AppCoordinator+PlaybackAudioTrack.swift`, `AppCoordinator+PlaybackSubtitle.swift`, `MenuGate.swift`, `DebugInteractionLatencyProbe.swift`)**:
   - Recorded initial click timestamps in `togglePlaybackMoreMenu()` and `togglePlaybackSubtitleMenu()`, gated `MenuGateClientView` behind `layout != nil` in `PlaybackChromeMoreMenuOverlay` and `PlaybackChromeSubtitleMenuOverlay` so layout measurement completes before `MenuGate.open`, restricted `measuredLayout` telemetry to initial open (`layout == nil`), restricted `PlaybackChromeSpeedMenuOverlay` trigger context recording to when `.playerSpeedMenu` is not yet open, and cleared `activeMenuContext` when `MenuGate` closes.
3. **Exclude All `beforeWaiting -> *` Idle Sleep Wakeups (`AppPerformanceProbe.swift`, `DebugInteractionLatencyProbe.swift`)**:
   - Excluded any RunLoop transition whose previous activity is `beforeWaiting` (`previous.previous != "beforeWaiting"` and `!phase.hasPrefix("beforeWaiting->")`) from main-thread stall alerts.

## Verification

- Automated tests:
  - `swift test --package-path apps/macos-native --filter "DebugInteractionLatencyProbeTests|PlaybackMoreMenuTests"`
