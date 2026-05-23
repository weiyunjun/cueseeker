# Player Cinematic UI/UX Refactoring Master Plan (YouTube-Style)

Status: Proposal
Author: Antigravity & User

## Background

As part of the ongoing refactoring of the video player interface into a YouTube-style cinematic layout, several high-fidelity details require alignment. To avoid fragmented patches, this master plan consolidates all phases of the playback UI refinement—from bottom control bars and theme token definitions to interactive overlay menus, sliding sliders, feedback HUDs, and right-side overlay sidebars.

This document serves as the authoritative, unified roadmap for the entire playback UI cinematic refactoring.

---

## Master Roadmap & Phases

### 🟩 Phase 1: Player Bottom Controls Bar (YouTube-Style)

#### Phase 1.1: Shared Theme System (Completed & Verified)
- **Goals**: Establish a dedicated cinema-like high-contrast dark environment, discarding system light/dark variations.
- **Key Deliverables**:
  - `PlaybackTheme.cinematicBacking`: Premium semi-translucent pure black surface backing (`Color.black.opacity(0.50)`).
  - `PlaybackTheme.capsuleFill` & `capsuleHoverFill`: Standardised translucent white fills (`0.08` and `0.16` opacity).
  - High-contrast typography colors (`textPrimary` at `0.94`, `textSecondary` at `0.62`, `textTertiary` at `0.34`).
  - Progress bar colors (`progressRed` as signature YouTube red, `scrubberTrackBackground` at `0.16`).

#### Phase 1.2: Bottom Controls Refinement & Unified Navigation (Completed & Verified - Commit 772a9c5)
- **Goals**: Achieve absolute horizontal symmetry, unify button sizes to `40x40`, refine hover feedback, bind unified navigation shortcuts, and resolve popover event dismiss collisions.
- **Visual Specifications**:
  - **Transport Button Dimensions**: Establish `40x40` (symbol size `18`) as the standard size for all controls (Play/Pause, Fullscreen, Mute, Shiori, Copy, CC, Sidebar).
  - **Capsule Backing Layouts**: Left Group (Previous/Next) and Right Group (Shiori/Copy/CC/Sidebar) share height `40` capsule panels backed by `Color.white.opacity(0.10)`. Individual bases are disabled, rendering a custom concentric hover circle on active button focus.
  - **Unified Height Axis**: Align all bottom bar elements centered perfectly on a unified height of `40`.
  - **Concentric Hover Circle**: Standalone transport buttons render a persistent base of `Color.white.opacity(0.10)` in normal state, overlaying a concentric inner `0.85` scale `Color.white.opacity(0.18)` highlight ring on hover.
  - **Speed Control Capsule Button**: Retain its original **54x40 capsule shape** and **12pt semibold font** with monospaced digits. Strip its ad-hoc glassmorphism (remove毛玻璃, outer borders, and shadow). Render a persistent `Color.white.opacity(0.10)` background, and overlay-add an inner `Color.white.opacity(0.18)` capsule scaled to `x: 0.88, y: 0.85` under hover/press states. It manages dynamic foreground colors based on `isEnabled` availability (`0.96` when enabled, `0.34` when disabled) and does not implement white background inversion.
  - **Speed Popup Menu**: Rebuilt with `PlaybackTheme.cinematicBacking` and a subtle `0.5` stroke border of `Color.white.opacity(0.10)`.
- **Navigation & Shortcuts Refinement**:
  - All adjacent navigation requests (via buttons or `A`/`D` keys) dynamically route based on the active playback context:
    - **Search Mode (`.search`)**: Navigates search result rows via `openAdjacentSearchResult(_:)`.
    - **Library Mode (`.library`)**: Navigates library items via `openPreviousLibraryVideo()` / `openNextLibraryVideo()`.
    - **Shiori Mode (`.shiori`)**: Resolves adjacent bookmarks relative to selection.
  - **Adjacent Navigation HUD**: Smooth transition chevron HUD overlay animations ("Previous Library Video", "Next Bookmark", etc.) matching Search feedback.
- **Popover Click Collision Safety**:
  - Embed `GeometryReader` on `speedControl`'s background to capture its `.global` (window-relative) frame in `speedButtonFrame`.
  - Refactor `installSpeedMenuDismissMonitor` to capture and convert `event.locationInWindow` to SwiftUI coordinate system (flipping Y-axis using window height), and check if the click point falls inside `speedButtonFrame`.
  - If inside, the Event Monitor ignores it so that the button's native action block toggles the menu (from `true` to `false`) smoothly; if outside, the Event Monitor normalizes it to `false` without triggering button actions. This completely eliminates the race condition where the menu instantly closes and re-opens on double click/re-click.

#### Phase 1.3: Volume Slider Inline Hover Expansion & Time Capsule Refinement (Planned)
- **Goals**: Implement a fluid inline horizontal volume slider that dynamically expands into a single cohesive capsule, and format the playback time display as a matching control capsule.
- **Specifications**:
  - **Time Capsule Design**: Format the playback time display (current / duration) in a cohesive, height-40 capsule backed by `Color.white.opacity(0.10)` (`PlaybackTheme.capsuleFill`). On mouse hover, apply a smooth highlight background transition to `Color.white.opacity(0.16)` (`PlaybackTheme.capsuleHoverFill`), matching standard control capsules.
  - **Dynamic Volume Capsule**: Integrate the volume button and the slider into a single continuous container. On hovering anywhere within the volume control area:
    - The container background smoothly expands its width from `40` (a standalone circle) to `136` (a unified capsule) via a `RoundedRectangle(cornerRadius: 20)` width animation.
    - This horizontal expansion dynamically pushes the adjacent Time Capsule to the right in the layout flow.
    - Within this expanded capsule, the standalone circular button border/base is disabled, rendering the icon and the slider seamlessly together on the continuous gray backing.
  - **Slider Elements & Styling**:
    - The volume track uses `PlaybackTheme.scrubberTrackBackground` (`Color.white.opacity(0.16)`), with the active progress track filled in high-contrast solid white (`Color.white`).
    - The slider thumb renders a high-fidelity solid white circle.
    - Drag gestures map smoothly to `viewModel.volume` mutations, fading the slider elements and percentages inline using `.opacity(isHovered ? 1 : 0)` during transitions.

#### Phase 1.4: Progress Scrubber Hover Tooltip & Tracks (Planned)
- **Goals**: Refine timeline scrubbing with visual previews and dynamic location metrics.
- **Specifications**:
  - The progress scrubber expands in vertical thickness on mouse hover.
  - Render a floating cinematic tooltip overlay displaying the exact timestamp matching the hovered track coordinate.
  - Prepare a thumbnail preview slot inside the tooltip for frame-by-frame scrubbing visual alignment.

---

### 🟦 Phase 2: Cinematic Feedback HUD & Animations (Planned)

- **Goals**: Deliver high-fidelity, satisfying micro-animations for on-stage playback feedback.
- **Specifications**:
  - Center-stage play/pause HUD fades and scales with elastic spring animations when triggered via the spacebar or clicking the video stage.
  - Fast-forward/rewind keyboard feedback (e.g. `J` / `L` or arrow keys) displays an accumulating jump indicator (e.g. `+10s`, `+20s`) within a single, stable HUD overlay to prevent visual clutter.
  - Transition animations between library items or search results utilize slide-in/out visual frames where hardware permits.

---

### 🟪 Phase 3: Sidebar to Right-Side Overlay (Planned)

- **Goals**: Migrate the active panel from a middle-center squeezing block into an elegant, right-side sliding drawer.
- **Specifications**:
  - The right-side sidebar overlays the video stage instead of squeezing the aspect-ratio geometry, preserving pure widescreen scaling.
  - The sidebar panel uses `PlaybackTheme.cinematicBacking` with a fine border, sliding in from the right edge on toggle with a `.spring` animation.
  - Active search results and subtitles tabs inside the sidebar remain responsive to page-up/down events.

---

## Verification & Safety Rules

- **Zero Regression Principle**: `swift build` and `swift test` (95/95) must compile and pass cleanly on every phase transition.
- **BypassSandbox Guidelines**: When sandbox restrictions prevent compiler system library loading during local runs, `BypassSandbox: true` must be selectively used for compilation/test execution only.
- **Git Commit Discipline**: Every completed phase or milestone must be immediately committed to Git. Blind git adding is forbidden; all commits require precise file-level staging and checking workspace cleanliness beforehand.
