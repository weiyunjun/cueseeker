# Proposal: Playback Feedback HUD & Icons Refinement (Cinematic Phase 2)

Status: Proposal
Author: Antigravity & User

## 1. Goal

Refine the playback feedback HUD animations and control icons to conform with a unified cinematic, premium design system.

Specifically, we want to:
1. **Unify HUD size & visual style**: Transform all feedback overlays into large, self-sizing, **80px height capsule-shaped overlays** with horizontal layouts (icon on left, text on right).
2. **Apply consistent icons for toggleable states**: Represent ON/OFF states **solely through icon changes** (filled `.fill` vs outline variants) for subtitles and side panel buttons on the bottom bar, and match them exactly in the feedback animations. Remove the heavy high-contrast white circular background in selected state.
3. **Refine side feedback positioning**: Position the side HUDs (previous/next results, rewind/forward seeking) closer to the screen edges, reducing the padding from 56px to **exactly 25px**.
4. **Refine volume and speed feedback**:
   - Use `"speaker.wave.3.fill"` for volume increase and `"speaker.wave.1.fill"` for volume decrease.
   - Set the default bottom-bar volume button icon to `"speaker.wave.2.fill"`, only switching to `"speaker.slash.fill"` when muted.
   - Use `"speedometer"` for playback speed feedback HUD to resolve collision with seeking chevrons.
5. **Preserve existing interaction rules**: Absolutely preserve continuous fast forward/rewind numerical accumulation, debouncing, and fade timing logic.

---

## 2. Proposed Changes

### 2.1 Component Changes

#### [MODIFY] [PlaybackFeedbackOverlay.swift](file:///Users/weiyunjun/Documents/Code/CueSeeker/apps/macos-native/Sources/CueSeekerApp/Playback/PlaybackFeedbackOverlay.swift)
- Restructure the body to use a unified `LiquidGlassFeedbackHUD` helper component for all feedback states.
- Set height to **`80`**, corner radius to **`40`** (perfect Capsule), and vertical padding to 0.
- Apply **`20pt` Semibold** for feedback text and **`30`** for icon font size.
- Set spacing inside `HStack` to **`16`**.
- Configure asymmetrical side layout:
  - Left-side HUD (Rewind / Previous): Icon on the left, Text on the right.
  - Right-side HUD (Forward / Next): Text on the left, Icon on the right.
- Set horizontal padding on side panels to **`25`** from screen boundaries.

#### [MODIFY] [PlaybackViewModel.swift](file:///Users/weiyunjun/Documents/Code/CueSeeker/apps/macos-native/Sources/CueSeekerApp/Playback/PlaybackViewModel.swift)
- Change `showVolumeFeedback` to accept an `isIncrease: Bool?` parameter:
  - If `volume <= 0`: `"speaker.slash.fill"`.
  - If `isIncrease == true`: `"speaker.wave.3.fill"`.
  - If `isIncrease == false`: `"speaker.wave.1.fill"`.
  - Else: `"speaker.wave.2.fill"`.
- Pass `isIncrease` from `setVolume` and `adjustVolume`.
- Change `showSpeedFeedback` to use `"speedometer"` as its icon.
- Add `showSidebarFeedback(isVisible: Bool)` which shows `"list.bullet.rectangle.fill"` (ON) or `"list.bullet.rectangle"` (OFF) with text `"Sidebar On"` or `"Sidebar Off"`.
- Update subtitles ON feedback icon to `"captions.bubble.fill"` and OFF to `"captions.bubble"`.

#### [MODIFY] [PlaybackChromeView.swift](file:///Users/weiyunjun/Documents/Code/CueSeeker/apps/macos-native/Sources/CueSeekerApp/Playback/Chrome/PlaybackChromeView.swift)
- Update subtitles and sidebar buttons to remove active white circular background highlight selection state.
  - Set `isSelected` to `false` on their `PlaybackChromeIconButton` calls so they don't render white circle backgrounds.
  - Subtitle button toggles between `"captions.bubble.fill"` (ON) and `"captions.bubble"` (OFF).
  - Sidebar button toggles between `"list.bullet.rectangle.fill"` (ON) and `"list.bullet.rectangle"` (OFF).

#### [MODIFY] [AppCoordinator+Playback.swift](file:///Users/weiyunjun/Documents/Code/CueSeeker/apps/macos-native/Sources/CueSeekerApp/App/AppCoordinator+Playback.swift)
- Call `playbackViewModel.showSidebarFeedback(isVisible: ...)` inside `togglePlaybackSidePanelFromUser()`.

#### [MODIFY] [PlaybackVolumeControl.swift](file:///Users/weiyunjun/Documents/Code/CueSeeker/apps/macos-native/Sources/CueSeekerApp/Playback/Chrome/PlaybackVolumeControl.swift)
- Simplify `volumeIcon` default calculation:
  - If `viewModel.volume <= 0`: `"speaker.slash.fill"`.
  - Else: `"speaker.wave.2.fill"`.

---

## 3. Verification Plan

### Automated Tests
- Run `swift build` and `swift test` inside `apps/macos-native` directory to verify compiling correctness.

### Manual Verification
- Visual inspection of 80px high capsule feedback.
- Confirm volume/speed feedback icons and sidebar/subtitles toggle visual consistency.
