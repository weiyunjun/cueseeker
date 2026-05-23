# Proposal: Playback Feedback HUD & Icons Refinement (Cinematic Phase 2)

Status: Proposal
Author: Antigravity & User

## 1. Goal

Refine the playback feedback HUD animations and control icons to conform with a unified cinematic, premium design system.

Specifically, we want to:
1. **Unify HUD size & visual style**: Transform all feedback overlays into self-sizing, **60px height capsule-shaped overlays** with horizontal layouts (icon on left, text on right).
2. **Apply consistent icons for toggleable states**: Represent ON/OFF states **solely through icon changes** (filled `.fill` / solid vs outline variants) for subtitles and side panel buttons on the bottom bar, and match them exactly in the feedback animations. Remove the heavy high-contrast white circular background in selected state.
   - For subtitles, use `"captions.bubble.fill"` (ON) and `"captions.bubble"` (OFF).
   - For side panel, use a beautiful custom-designed **`PlaybackSidebarIconView`**:
     - Closed state (OFF): Outlined rounded rectangle (`lineWidth: 2.0`) with a vertical divider line (`lineWidth: 2.0`) spanning from top-to-bottom (`y: 0` to `y: height`) at exactly `68%` of the width.
     - Open state (ON): Keep the outlined rounded rectangle and divider, and **fill the right-side chamber (the sidebar portion, trailing 32%) solid white**.
3. **Align overlay background style**: Set the feedback HUD background fill, stroke border, and shadow to match the speed menu popover's standard overlay backing exactly:
   - Fill: **`PlaybackTheme.cinematicBacking`** (`Color.black.opacity(0.55)`).
   - Stroke: **`PlaybackTheme.textTertiary.opacity(0.3)`** (width `0.5`).
   - Shadow: **`color: .black.opacity(0.42), radius: 24, y: 12`**.
   - Preserve `.ultraThinMaterial` background blur to maintain a premium translucent floating effect.
4. **Refine side feedback positioning**: Position the side HUDs (previous/next results, rewind/forward seeking) closer to the screen edges, reducing the padding from 56px to **exactly 25px**.
5. **Refine volume and speed feedback**:
   - Volume: HUD displays **only numerical percentage** (e.g. `"85%"` or `"100%"`), omitting the word `"Volume"`. Displays `"Muted"` when muted.
   - Volume Icon: HUD uses `"speaker.wave.3.fill"` for volume increase and `"speaker.wave.1.fill"` for volume decrease. The default bottom-bar volume button icon is simplified to `"speaker.wave.2.fill"`, only switching to `"speaker.slash.fill"` when muted.
   - Speed: HUD uses `"speedometer"` to represent speed changes clearly.
6. **Refine copy button**: Replace the custom `PlaybackCopyGlyph` with the standard SF Symbol **`"doc.on.doc"`** for both bottom controls and feedback HUD to ensure perfect proportions and weight alignment.
7. **Shiori Removal flow simplification**: Enable direct Shiori bookmark removal **without any NSAlert secondary confirmation dialog**, applying the deletion instantly in the database and rendering the `"Shiori Removed"` HUD feedback animation.
8. **Preserve existing interaction rules**: Absolutely preserve continuous fast forward/rewind numerical accumulation, debouncing, and fade timing logic.

---

## 2. Proposed Changes

### 2.1 Component Changes

#### [MODIFY] [PlaybackFeedbackOverlay.swift](file:///Users/weiyunjun/Documents/Code/CueSeeker/apps/macos-native/Sources/CueSeekerApp/Playback/PlaybackFeedbackOverlay.swift)
- Restructure the body to use a unified `LiquidGlassFeedbackHUD` helper component for all feedback states.
- Set height to **`60`**, corner radius to **`30`** (perfect Capsule), and vertical padding to 0.
- Apply **`20pt` Semibold** for feedback text and **`30`** for icon font size.
- Set spacing inside `HStack` to **`16`**.
- Configure asymmetrical side layout:
  - Left-side HUD (Rewind / Previous): Icon on the left, Text on the right.
  - Right-side HUD (Forward / Next): Text on the left, Icon on the right.
- Set horizontal padding on side panels to **`25`** from screen boundaries.
- Set background fill to `PlaybackTheme.cinematicBacking`, stroke border to `PlaybackTheme.textTertiary.opacity(0.3)` with width `0.5`, shadow to `.black.opacity(0.42), radius: 24, y: 12`.
- Update `.copy` to use `"doc.on.doc"`.
- Support `.sidebar(let isOpen)` using the new `PlaybackSidebarIconView`.

#### [MODIFY] [PlaybackViewModel.swift](file:///Users/weiyunjun/Documents/Code/CueSeeker/apps/macos-native/Sources/CueSeekerApp/Playback/PlaybackViewModel.swift)
- Update `PlaybackFeedbackIcon` enum to add `.sidebar(isOpen: Bool)`.
- Change `showVolumeFeedback` to accept an `isIncrease: Bool?` parameter:
  - If `volume <= 0`: `"speaker.slash.fill"`, text `"Muted"`.
  - If `isIncrease == true`: `"speaker.wave.3.fill"`, text `"\((Int(volume.rounded())))%"`.
  - If `isIncrease == false`: `"speaker.wave.1.fill"`, text `"\((Int(volume.rounded())))%"`.
  - Else: `"speaker.wave.2.fill"`, text `"\((Int(volume.rounded())))%"`.
- Pass `isIncrease` from `setVolume` and `adjustVolume`.
- Change `showSpeedFeedback` to use `"speedometer"` as its icon.
- Change `showSidebarFeedback(isVisible: Bool)` to trigger `.sidebar(isOpen: isVisible)` icon and text `"Sidebar On"` or `"Sidebar Off"`.

#### [MODIFY] [PlaybackChromeView.swift](file:///Users/weiyunjun/Documents/Code/CueSeeker/apps/macos-native/Sources/CueSeekerApp/Playback/Chrome/PlaybackChromeView.swift)
- Update subtitles and sidebar buttons to remove active white circular background highlight selection state.
  - Set `isSelected` to `false` on their `PlaybackChromeIconButton` calls so they don't render white circle backgrounds.
  - Subtitle button toggles between `"captions.bubble.fill"` (ON) and `"captions.bubble"` (OFF).
  - Sidebar button uses `.sidebar(isOpen: controls.isSidePanelVisible)` icon.

#### [MODIFY] [PlaybackChromeIconButton.swift](file:///Users/weiyunjun/Documents/Code/CueSeeker/apps/macos-native/Sources/CueSeekerApp/Playback/Chrome/PlaybackChromeIconButton.swift)
- Update `PlaybackChromeIcon` enum to add `.sidebar(isOpen: Bool)`.
- Map `.copy` to system image `"doc.on.doc"`.
- Map `.sidebar(let isOpen)` to render `PlaybackSidebarIconView(isOpen: isOpen, size: size)`.
- Define `PlaybackSidebarIconView` helper component with `lineWidth: 2.0` and trailing 32% fill when `isOpen == true`.

#### [MODIFY] [AppCoordinator+Shiori.swift](file:///Users/weiyunjun/Documents/Code/CueSeeker/apps/macos-native/Sources/CueSeekerApp/App/AppCoordinator+Shiori.swift)
- Remove `confirmShioriRemoval()` modal confirm check inside `toggleCurrentShiori()`, executing removal instantly and triggering the `"Shiori Removed"` HUD feedback.
- Remove `confirmShioriRemoval()` helper method.

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
- Visual inspection of 60px high capsule feedback.
- Confirm volume/speed feedback icons and sidebar/subtitles toggle visual consistency.
