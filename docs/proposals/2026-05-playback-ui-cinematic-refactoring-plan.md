# Player Cinematic UI/UX Refactoring Master Plan (YouTube-Style)

Status: Accepted for current Swift-first UI stage; remaining visual polish deferred
Author: Antigravity & User

## Background

As part of the ongoing refactoring of the video player interface into a YouTube-style cinematic layout, several high-fidelity details require alignment. To avoid fragmented patches, this master plan consolidates all phases of the playback UI refinement—from bottom control bars and theme token definitions to interactive overlay menus, sliding sliders, feedback HUDs, and right-side overlay sidebars.

This document serves as the authoritative, unified roadmap for the entire playback UI cinematic refactoring.

Current acceptance: the owner accepted the native SwiftUI/AppKit result on
2026-05-24 as complete for the current UI stage. The branch may be merged after
documentation sync. Remaining visual details are future polish, not blockers
for this phase.

---

## Master Roadmap & Phases

### 🟩 Phase 1: Player Bottom Controls Bar (YouTube-Style)

#### Phase 1.1: Shared Theme System & Adaptive Contrast (Iterated & Refined)
- **Goals**: Establish a dedicated cinema-like high-contrast dark environment, discarding system light/dark variations.
- **Adaptive Contrast Principle (Translucent Black Fills)**:
  - Transition all base background containers (capsules and circles) from translucent *white* to translucent *black*.
  - **On White Backgrounds**: Black translucent capsules mix to render sleek, distinct grey boundaries (e.g. `opacity(0.30)` results in `#B2B2B2` grey), protecting visibility.
  - **On Black Backgrounds**: Translucent black bases blend completely into the dark video background (`#000000`), letting high-contrast white text and icons float framelessly.
- **Key Deliverables (10 Consolidated Design Tokens)**:
  - `PlaybackTheme.cinematicBacking`: Premium semi-translucent pure black surface backing (`Color.black.opacity(0.55)`) for settings card popovers.
  - `PlaybackTheme.capsuleFill`: Standard base background fill (`Color.black.opacity(0.30)`) for standalone buttons, grouped capsules, time display capsule, and speed button.
  - `PlaybackTheme.capsuleHoverFill`: Inner concentric hover highlight overlay (`Color.white.opacity(0.16)`).
  - `PlaybackTheme.scrubberTrackBackground`: Background track of the timeline scrubber (`Color.black.opacity(0.60)`). Darker than other bases to ensure visibility for the thin `3px`/`6px` line.
  - `PlaybackTheme.scrubberHoverTrack`: Hover highlight track portion (`Color.white.opacity(0.35)`).
  - `PlaybackTheme.menuItemHighlight`: Unified background highlight (`Color.white.opacity(0.12)`) for selected, hovered, and pressed speed menu items.
  - `PlaybackTheme.progressRed`: YouTube signature red for active progress track and scrubber thumb (`Color.red`).
  - `PlaybackTheme.textPrimary`: High-contrast primary texts, white icons (`Color.white.opacity(0.94)`).
  - `PlaybackTheme.textSecondary`: Medium-contrast secondary text, volume percentages (`Color.white.opacity(0.62)`).
  - `PlaybackTheme.textTertiary`: Low-contrast disabled states, separators, and popover boundaries (`Color.white.opacity(0.34)`).
- **PlaybackCinematicBacking**: Concentric double-layer backing component supporting circles and capsules with a persistent translucent black base (`PlaybackTheme.capsuleFill`) and a concentric inner highlight overlay (`PlaybackTheme.capsuleHoverFill` scaled to `0.85`–`0.96` horizontally) to globally unify hover/pressed visual states.

#### Phase 1.2: Bottom Controls Refinement & Unified Navigation (Iterated & Refined - Commit 772a9c5)
- **Goals**: Achieve absolute horizontal symmetry, unify button sizes to `40x40`, refine hover feedback, bind unified navigation shortcuts, and resolve popover event dismiss collisions.
- **Visual Specifications**:
  - **Transport Button Dimensions**: Establish `40x40` (symbol size `18`) as the standard size for all controls (Play/Pause, Fullscreen, Mute, Shiori, Copy, CC, Sidebar).
  - **Capsule Backing Layouts**: Left Group (Previous/Next) and Right Group (Shiori/Copy/CC/Sidebar) share height `40` capsule panels backed by `PlaybackTheme.capsuleFill`. Individual bases are disabled, rendering a custom concentric hover circle on active button focus.
  - **Unified Height Axis**: Align all bottom bar elements centered perfectly on a unified height of `40`.
  - **Concentric Hover Circle**: Standalone transport buttons render a persistent base of `PlaybackTheme.capsuleFill` in normal state, overlaying a concentric inner `0.85` scale `PlaybackTheme.capsuleHoverFill` highlight ring on hover.
  - **Speed Control Capsule Button**: Retain its original **54x40 capsule shape** and **12pt semibold font** with monospaced digits. Render a persistent `PlaybackTheme.capsuleFill` background, and overlay-add an inner `PlaybackTheme.capsuleHoverFill` capsule scaled to `x: 0.88, y: 0.85` under hover/press states. It manages dynamic foreground colors based on `isEnabled` availability and does not implement white background inversion.
  - **Speed Popup Menu**: Rebuilt with `PlaybackTheme.cinematicBacking` and a subtle `0.5` stroke border of `PlaybackTheme.textTertiary.opacity(0.3)`.

#### Phase 1.3: Volume Slider Inline Hover Expansion & Time Capsule Refinement (Completed & Verified)
- **Goals**: Implement a fluid inline horizontal volume slider that dynamically expands into a single cohesive capsule, and format the playback time display as a matching control capsule.
- **Specifications**:
  - **Time Capsule Design**: Format the playback time display (current / duration) in a cohesive, height-40 capsule backed by `PlaybackTheme.capsuleFill`. Both current time and duration are styled in high-contrast `PlaybackTheme.textPrimary` to ensure excellent readability. On mouse hover, apply a smooth highlight background transition to `PlaybackTheme.capsuleHoverFill`, matching standard control capsules.
  - **Dynamic Volume Capsule**: Integrate the volume button, the slider, and the percentage text into a single continuous container. On hovering anywhere within the volume control area:
    - The container background smoothly expands its width from `40` (a standalone circle) to `160` (a unified capsule) via a `RoundedRectangle(cornerRadius: 20)` width animation.
    - To match YouTube-style visual dynamics, hovering anywhere on the capsule highlights the entire background to `PlaybackTheme.capsuleHoverFill`, rather than keeping it at `capsuleFill`.
    - This horizontal expansion dynamically pushes the adjacent Time Capsule to the right in the layout flow.
    - Within this expanded capsule, the standalone circular button base is disabled, rendering the icon, the slider, and the volume percentage text seamlessly together on the highlighted translucent black backing.
  - **Slider & Text Styling**:
    - The volume track uses translucent white (`Color.white.opacity(0.16)`), with the active progress track filled in high-contrast solid white (`Color.white`).
    - The slider thumb renders a high-fidelity solid white circle.
    - The volume percentage displays inline next to the slider as a monospaced digit label `Text` with `PlaybackTheme.textPrimary` color for optimal legibility.
    - Drag gestures map smoothly to `viewModel.volume` mutations.

#### Phase 1.4: Progress Scrubber Hover Tooltip & Tracks (Completed & Verified)
- **Goals**: Refine timeline scrubbing with visual previews and dynamic location metrics, and purify the player bottom bar.
- **Specifications**:
  - **Transparent Bottom Bar Layout**: The black background gradient from the player's bottom controls bar is completely removed, rendering all premium button circles/capsules floating natively transparent over the video stage to maximize widescreen legibility.
  - **Red Active Progress & Thumb**: The current playback progress track and the scrubbing thumb are styled using YouTube signature red (`PlaybackTheme.progressRed`), providing a high-contrast focal indicator.
  - **Proportional Base Track Backing**: The scrubber base background track uses `PlaybackTheme.scrubberTrackBackground` (`Color.black.opacity(0.60)`) to remain perfectly visible over white scenes.
  - **Three-Segment Scrubber Visuals**: Layer the scrubber tracks in a ZStack:
    - Base track (full width) is `PlaybackTheme.scrubberTrackBackground`.
    - Hover track (0 to cursor position) uses `PlaybackTheme.scrubberHoverTrack` (`Color.white.opacity(0.35)`), appearing only when hovered. It overlays the dark base track to create a bright white/grey highlight segment only between the current playhead and the cursor.
    - Active progress track (0 to current playhead) is `PlaybackTheme.progressRed` (`Color.red`), naturally overlaying the hover track.
  - **Scrubber Thickness Expansion**: The scrubber track dynamically expands from a vertical height of `3` to `6` on mouse hover to provide satisfying tactile feedback.
  - **Dynamic Self-Sizing Tooltip Capsule**: When hovering the progress scrubber, a floating timestamp tooltip appears directly above the cursor position. To prevent truncation of hours or minutes, the tooltip's width dynamically self-sizes based on the string length (using a horizontal padding of `8`). Its backing is a height `22` capsule powered by `PlaybackCinematicBacking` with `isHovered: false`.
  - **Snappy Zero-Lag Tracking**: The horizontal position of the tooltip tracks the cursor coordinates with zero lag and absolutely no easing or spring animation.
  - **Snappy Visibility Toggle**: The tooltip appears and disappears instantly upon entering/exiting the progress bar.
  - **Boundary Clamping**: Apply horizontal clamping based on the dynamic tooltip width (`tooltipWidth`) to prevent the tooltip from shifting outside the left/right viewport boundaries.
  - **Gesture Safety**: Set `.allowsHitTesting(false)` on the tooltip to guarantee it does not intercept hover or drag gestures.
  - **Speed Menu Consistency**: Ensure selected, hovered, and pressed speed items in the speed settings popup share `PlaybackTheme.menuItemHighlight` (`Color.white.opacity(0.12)`) for absolute consistency.
  - **Speed Menu Popover Vertical Clamping**: Position the speed menu card so that its bottom edge sits tightly above the progress bar with a clean `2pt` gap when hovered, preventing any visual overlap or click interference when hovering the scrubber. Clamp the center Y position to at most `proxy.size.height - PlaybackChromeMetrics.height + 20 - menuHeight / 2`.
  - **Active Dragging Tooltip Tracking**: When actively dragging the progress scrubber (`dragTime != nil`), prioritize the drag gesture's horizontal coordinate (`filledWidth`) and time value (`dragTime`) over continuous hover variables to prevent the tooltip from lagging at the pre-drag hover location.

#### Phase 1.5: Timeline Scrubbing Playback Alignment (Implemented & Accepted)
- **Goals**: Align Timeline drag behavior with YouTube/Movist-style
  scrubbing while preserving the native playback backend's bounded read-ahead
  model. Phase 1.5 fixes the behavior gap discovered after Phase 1.4: dragging
  the scrubber must be a modal playback interaction, not a local-only slider
  preview followed by one seek on release. Full-size keyframe preview and
  progress-hover thumbnails remain research directions, but they are deferred
  from the current UI restructure until their memory, latency, and
  decoder-lifecycle tradeoffs justify the added complexity.
- **User-facing contract**:
  - Mouse down in the Timeline Zone enters a modal timeline-scrubbing state
    immediately. The scrubber jumps to the pressed position without waiting for
    mouse release.
  - The red progress track, thumb, tooltip, and visible playback time label
    follow every drag update. The white hover-ahead segment is hidden while
    scrubbing because the current scrub position is already the active
    position.
  - Playback is paused while the mouse is held down. The playback clock and
    audio do not advance during scrubbing.
  - During the drag, the video surface remains on the frame that was visible
    when scrubbing began. The drag path does not update keyframes, generate
    thumbnails, perform realtime seeks, or otherwise change the video image
    before mouse release.
  - Dragging ends on mouse release. The app then performs a real seek to the
    final requested timestamp and resumes playback only if playback was active
    before scrubbing started.
  - Click seeks and the final seek after timeline dragging preserve the
    playback state from before the seek interaction. If the resulting state is
    paused, the video surface still updates to the destination frame.
- **Modal interaction rules**:
  - While timeline scrubbing is active, all non-Timeline playback shortcuts are
    disabled.
  - While timeline scrubbing is active, non-Timeline bottom-player controls do
    not enter hover, pressed, or active states; their click actions and menu
    open/close actions are suppressed until scrubbing ends.
  - Timeline scrubbing must not fall through to video-surface play/pause
    toggling.
- **Read-ahead and render rules**:
  - Normal playback read-ahead is suspended or frozen while timeline scrubbing
    is active. The 10-second / 64 MB session-scoped compressed-packet queue
    must not keep advancing from the old playback position during a drag.
  - Timeline dragging must not perform keyframe preview, thumbnail generation,
    or realtime seek work while the mouse is held down, so it must not write
    scrub-preview requests into the normal packet queue.
  - When scrubbing ends, the final seek position decides whether an existing
    playback session/read-ahead queue can be retained or must be discarded and
    rebuilt. The current native seek implementation already behaves like the
    rebuild case because it replaces the session.
  - Future thumbnail or full-size keyframe-preview work must be validated
    separately before acceptance, including memory growth, first-image latency,
    sustained drag cadence, decoder/context lifetime, and whether the preview
    should be cached, generated on demand, or skipped.
- **Implementation steps**:
  1. **1.5.1 Documentation and acceptance rules**: land this Phase 1.5
     contract in proposal, product, engineering, testing, and changelog docs.
  2. **1.5.2 Modal interaction gate**: add shared `isTimelineScrubbing` state
     and suppress playback shortcuts, non-Timeline hover/press/click, and menu
     interactions while it is active.
  3. **1.5.3 Shared scrub time display**: lift scrub time out of the local
     scrubber view so the scrubber, tooltip, and playback time label follow the
     drag target immediately.
  4. **1.5.4 Frozen-surface drag and final seek**: keep the video surface
     unchanged while dragging, pause playback during the drag, and commit one
     final seek on release while restoring the prior playback state.
  5. **1.5.5 Verification**: verify shortcut/button suppression, immediate
     timeline/time updates, frozen video during active drag, final precise seek,
     paused-destination frame rendering, playback-state restoration, and
     read-ahead isolation.

---

### 🟦 Phase 2: Cinematic Feedback HUD & Animations (Implemented & Accepted)

- **Goals**: Deliver high-fidelity, satisfying micro-animations for on-stage playback feedback.
- **Specifications**:
  - Center-stage play/pause HUD fades and scales with elastic spring animations when triggered via the spacebar or clicking the video stage.
  - Fast-forward/rewind keyboard feedback (e.g. `J` / `L` or arrow keys) displays an accumulating jump indicator (e.g. `+10s`, `+20s`) within a single, stable HUD overlay to prevent visual clutter.
  - Transition animations between library items or search results utilize slide-in/out visual frames where hardware permits.

---

### 🟪 Phase 3: Sidebar to Right-Side Overlay (Implemented & Accepted)

- **Goals**: Migrate the active panel from a middle-center squeezing block into an elegant, right-side floating overlay.
- **Specifications**:
  - The right-side sidebar overlays the video stage instead of squeezing the aspect-ratio geometry, preserving pure widescreen scaling.
  - The sidebar panel uses `PlaybackTheme.cinematicBacking` with a fine border and right-aligned floating geometry.
  - Active search results and subtitles tabs inside the sidebar remain responsive to page-up/down events.
  - The native sidebar scrollbar keeps a narrow fixed-width light thumb when visible while the track/gutter remains transparent.

---

## Verification & Safety Rules

- **Zero Regression Principle**: `swift build` and `swift test` (95/95) must compile and pass cleanly on every phase transition.
- **BypassSandbox Guidelines**: When sandbox restrictions prevent compiler system library loading during local runs, `BypassSandbox: true` must be selectively used for compilation/test execution only.
- **Git Commit Discipline**: Every completed phase or milestone must be immediately committed to Git. Blind git adding is forbidden; all commits require precise file-level staging and checking workspace cleanliness beforehand.
