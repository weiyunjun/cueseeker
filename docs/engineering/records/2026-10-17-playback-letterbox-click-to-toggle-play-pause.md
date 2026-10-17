# Implementation Record: Playback Letterbox Click To Toggle Play Pause

- **Date**: 2026-10-17
- **Requirement**: `docs/human/requirements/20261017-UI-Playback Letterbox Click To Toggle Play Pause.md`
- **Design References**:
  - `docs/human/design/ui/UI Layouts - Playback.md`
  - `docs/human/design/ui/UI Interaction Rules.md`

## Summary of Changes

1. **Playback Stage Full-Width & Letterbox/Pillarbox Tap Region (`PlaybackTheme.swift`, `PlaybackVideoStage.swift`, `PlaybackView.swift`, `SearchView.swift`)**:
   - Added `PlaybackChromeMetrics.bottomControlRegionHeight` (`82px`, covering the `18px` progress scrubber hit area, `52px` controls row, and `12px` bottom padding) and `PlaybackChromeMetrics.stageTapInteractiveRect(stageSize:isPlayerUIVisible:)`.
   - Moved the play/pause single-click gesture from the aspect-fitted `PlaybackVideoView` (`PlaybackView.swift`) to `PlaybackVideoStage.swift` across `stageTapInteractiveRect(stageSize:isPlayerUIVisible:)`:
     - When `isPlayerUIVisible == true`, the stage tap area spans `100%` of the stage width from the bottom of the `54px` top bar (`--height-app-topbar`) down to the top edge of the `18px` progress scrubber hit area (`stageSize.height - 82px`), covering the video surface, top/bottom Letterbox black bars, left/right Pillarbox black bars, and the `16px` `--padding-player-progress-top` strip above the progress scrubber hit area.
     - When `isPlayerUIVisible == false`, the stage tap area spans `100% × 100%` of the window without waking the Player UI or pointer on a pure click (preserving `UI Interaction Rules.md` §10.3–10.4).
   - Made `PlaybackRenderHostView` (`PlaybackView.swift`) pass through AppKit `hitTest(_:)` (`return nil`) and disabled hit-testing on `playbackSurface` in `PlaybackVideoStage.swift` so the underlying `NSView` never intercepts clicks over the top bar or bottom control bar when vertical videos extend behind them.

2. **Bottom Control Bar Hit-Blocking Boundary & Hidden Top Bar Pass-Through (`PlaybackChromeView.swift`, `TitlebarBackgroundView.swift`, `LiquidGlassVideoTopBar.swift`)**:
   - In `PlaybackChromeView.chromeSurface`, moved `.padding(.top, PlaybackChromeMetrics.progressTopPadding)` (`16px`) outside the hit-blocking `.background(Color.clear.contentShape(Rectangle()).onTapGesture {})` so only the `82px` region from the top of the progress scrubber hit area to the bottom of the window blocks stage play/pause taps.
   - Added `allowsHitTesting` to `TitlebarBackgroundView` / `DraggableNSView` and wired it to `@Environment(\.isPlayerUIVisible)` in `LiquidGlassVideoTopBar` so the AppKit `DraggableNSView` returns `nil` from `hitTest(_:)` when the Player UI is hidden, allowing clicks in the top `54px` to toggle play/pause while hidden.

## Verification

- Verified `PlaybackChromeVisibilityModelTests` (`swift test --package-path apps/macos-native --filter "PlaybackChromeVisibilityModelTests|PlaybackMoreMenuTests|PlaybackStoreTests"`), covering `stageTapInteractiveRect` boundaries (visible vs. hidden Player UI, letterbox/pillarbox/scrubber/topbar coordinates) and `DraggableNSView` hit-testing pass-through when hidden.
- Result matched requirement acceptance criteria.
