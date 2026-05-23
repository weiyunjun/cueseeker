# Player Bottom Controls and Unified Navigation Refinement

> [!NOTE]
> This proposal has been **superseded** by the unified master plan: [2026-05-playback-ui-cinematic-refactoring-plan.md](file:///Users/weiyunjun/Documents/Code/CueSeeker/docs/proposals/2026-05-playback-ui-cinematic-refactoring-plan.md). It is retained here for historical context.

Status: Superseded

## Background

As part of the ongoing refactoring of the video player interface on the `ui/restructure` branch into a YouTube-style cinematic layout, several high-fidelity details require alignment. Specifically, the button hover states, button grouping semantics, keyboard shortcuts, and overlay menus need to conform to a cohesive, high-contrast, premium, dark-theater experience.

This proposal represents **Phase 1.2** of the bottom player controls refinement.

## Goals

- Implement precise YouTube-style button hover dynamics (persistent base circular background under normal state, concentric smaller highlight circle under hover state).
- Group related playback bottom controls into unified capsule-like gray background panels (Previous/Next group, Action buttons group) to enhance clean visual hierarchy.
- **Unify Bottom Control Button Sizes and Vertical Alignment**:
  - Establish `40x40` (with icon symbol size of `18`) as the universal standard size for all bottom control bar buttons.
  - Align all buttons (Play/Pause, Previous, Next, Shiori, Copy, CC, Sidebar, Fullscreen, Mute) and their container capsules perfectly centered horizontally on a unified height of `40`.
- Refactor the playback keyboard shortcuts for `A` and `D` keys to align perfectly with the active playback source (`ActivePlaybackSource`), supporting search results navigation, library video navigation, and Shiori (bookmark) list navigation.
- **Add Adjacent Navigation Feedback for Library & Shiori**:
  - Implement smooth, satisfying chevron HUD overlay animations for Library adjacent transitions and Shiori bookmark adjacent transitions, ensuring visual consistency with Search navigation.
- Restructure the playback speed popup menu background to use the cinematic semi-translucent black theme and elegant fine borders.

## UI/UX Impact

### 1. Hover and Normal Button Dynamics
- **Normal State (No Hover)**: Standalone buttons (e.g. Play/Pause, Fullscreen) render on a persistent, semi-translucent circular gray base.
  - **Base color**: `Color.white.opacity(0.10)`
- **Hover State**: Hovering over any active button overlays a concentric, slightly smaller circle.
  - **Highlight color**: `Color.white.opacity(0.18)`
  - **Size scale**: `0.85` of the base button frame (leaving a clear, elegant outer ring of the base background visible).
  - **Transition**: Smooth transition `.easeInOut(duration: 0.15)` to avoid sudden flashes.

### 2. Grouped Capsule Layouts and Standard Sizing (40x40)
All bottom control elements are unified to a standard container height of `40` and size of `40x40` (using `.transport` kind, size `40`, symbol size `18`):
- **Play/Pause Button**: Adjusted from `.primaryTransport` (44) to `.transport` (40) to match other controls.
- **Navigation Group (Left Group)**: Includes Previous Video (`backward.end.fill`) and Next Video (`forward.end.fill`) buttons.
  - **Capsule backing**: `Capsule().fill(Color.white.opacity(0.10))`
  - **Capsule height**: `40`
  - **Inner buttons**: Standalone persistent gray circular bases are disabled (`hasPersistentBase: false`). When hovered, only the `0.85`-scale concentric highlight circle overlays centered on the hovered button.
- **Action Group (Right Group)**: Includes Bookmark/Shiori (`bookmark`), Copy Subtitle (`copy`), CC Subtitles (`captions.bubble`), and Sidebar (`list.bullet`) buttons.
  - **Capsule backing**: `Capsule().fill(Color.white.opacity(0.10))`
  - **Capsule height**: Increased from `32` to `40`.
  - **Inner buttons**: All updated from `.circle` (32) to `.transport` (40) with standalone bases disabled. If CC or Sidebar are active (`isSelected: true`), a full-size high-contrast white circular background (`Color.white`) fills behind them, with a dark icon foreground.
- **Speed Control Button**: Maintained as a **capsule shape** with a width of `54`, a height of `40` (aligning with the control bar container height), and a fixed font size of **12pt (weight: .semibold)** with monospaced digits, matching its original typography. To unify its visual style with the rest of the bottom bar, we stripped its ad-hoc glassmorphism (removed `.ultraThinMaterial`, outer stroke border, and shadow). It now uses a pure, persistent flat background of **`Color.white.opacity(0.10)`** in its normal state, matching standard buttons. In addition, it does not use the active selection solid-white state (no inverted styling when the speed menu is active), keeping a clean, stable translucent capsule background.
- **Fullscreen Button**: Updated from `.circle` (32) to `.transport` (40).
- **Mute Button / Volume Control**: Volume icon button updated to `.transport` (40) and the outer volume container height aligned to `40`.

This establishes absolute symmetry where every single element in the bottom control bar aligns perfectly on a `40` height axis.

### 3. Playback Speed Popup Menu
- The speed adjustment menu is updated to discard standard macOS gray backing in favor of the cinema theme.
- **Background**: `PlaybackTheme.cinematicBacking` (`Color.black.opacity(0.50)`), acting as the global token for all semi-translucent cinematic backings (including future sidebars and overlays) without backdrop blur, allowing underlying video frames to remain perfectly sharp.
- **Border**: Thin border `Color.white.opacity(0.10)`.

## Navigation & Keyboard Shortcut Refinement

All adjacent navigation queries (both through bottom controls bar buttons and `A`/`D` keyboard keys) route strictly according to the active playback context (`activePlaybackSource`):

### 1. Search Mode (`.search`)
- **Key A / Previous Button**: Invokes `openAdjacentSearchResult(.previous)` if `canOpenPreviousSearchResult` is true.
- **Key D / Next Button**: Invokes `openAdjacentSearchResult(.next)` if `canOpenNextSearchResult` is true.
- Displays Search transition HUD feedback ("Previous Result" / "Next Result").

### 2. Library Mode (`.library`)
- **Key A / Previous Button**: Invokes `openPreviousLibraryVideo()` if `canOpenPreviousLibraryVideo` is true.
- **Key D / Next Button**: Invokes `openNextLibraryVideo()` if `canOpenNextLibraryVideo` is true.
- **HUD Animation Feedback**: Displays Library transition HUD feedback ("Previous Library Video" / "Next Library Video").

### 3. Shiori Mode (`.shiori`)
- **Key A / Previous Button**: Resolves the previous saved bookmark from `shiori.shioris` relative to `shiori.selectedShiori` and opens it.
- **Key D / Next Button**: Resolves the next saved bookmark from `shiori.shioris` relative to `shiori.selectedShiori` and opens it.
- **HUD Animation Feedback**: Displays Shiori transition HUD feedback ("Previous Bookmark" / "Next Bookmark").

## Technical Implementation Details

### 1. File Modifications

#### [PlaybackTheme.swift](file:///Users/weiyunjun/Documents/Code/CueSeeker/apps/macos-native/Sources/CueSeekerApp/Playback/PlaybackTheme.swift)
- Ensure all color tokens like `cinematicBacking` and opacity norms are well-integrated.

#### [PlaybackChromeIconButton.swift](file:///Users/weiyunjun/Documents/Code/CueSeeker/apps/macos-native/Sources/CueSeekerApp/Playback/Chrome/PlaybackChromeIconButton.swift)
- (Reverted) No `.text` case or custom Text rendering changes will be introduced in this file to keep circular icon button semantics perfectly pristine.

#### [PlaybackChromeView.swift](file:///Users/weiyunjun/Documents/Code/CueSeeker/apps/macos-native/Sources/CueSeekerApp/Playback/Chrome/PlaybackChromeView.swift)
- Replace standalone button structures with grouped capsule layouts (`HStack` containing button sub-arrays, backed by `Capsule`).
- Unify all standard icon buttons (including Fullscreen) to `.transport` kind (40x40). Update Right Group capsule frame height to `40`.
- Bind Previous and Next buttons to unified navigation: `canGoPrevious`/`goPrevious()` and `canGoNext`/`goNext()`.
- Refactor the **Speed Control Button** using standard SwiftUI `Button` with a redesigned **`PlaybackChromeCapsuleButtonStyle`**:
  - Keep its original **54x40 capsule shape** and fixed **12pt semibold font** with monospaced digits.
  - Remove all legacy `.ultraThinMaterial` backings, outer borders, and shadows.
  - Implement a **concentric capsule overlay hover effect** to match standard circular button dynamics: it renders a persistent `Color.white.opacity(0.10)` background capsule under normal state, and overlay-adds an inner `Color.white.opacity(0.18)` capsule scaled to `x: 0.88, y: 0.85` under hover/press states, ensuring unified micro-animation pacing.
  - Manage **dynamic foreground colors** based on `isEnabled` availability status (`0.96` opacity when enabled, `0.34` opacity when disabled) to align with global button hierarchy.
  - Ensure the style does NOT implement any selected/active high-contrast inversion (no solid white backgrounds when the menu is active), keeping a clean translucent cinematic style.
- **Solve Speed Popover Click Collision**: 
  - Add `@State private var speedButtonFrame: CGRect = .zero` to track the button bounds in window space.
  - Bind `GeometryReader` on `speedControl`'s background to dynamically monitor its `.global` (window-relative) frame.
  - Refactor `installSpeedMenuDismissMonitor` to capture and convert `event.locationInWindow` to SwiftUI coordinate system (flipping Y-axis using window height), and check if the click point falls inside `speedButtonFrame`.
  - If inside, the Event Monitor ignores it so that the button's native action block toggles the menu (from `true` to `false`) smoothly; if outside, the Event Monitor normalizes it to `false` without triggering button actions. This completely eliminates the race condition where the menu instantly closes and re-opens on double click/re-click.

#### [PlaybackVolumeControl.swift](file:///Users/weiyunjun/Documents/Code/CueSeeker/apps/macos-native/Sources/CueSeekerApp/Playback/Chrome/PlaybackVolumeControl.swift)
- Update Mute icon button to use `.transport` kind (40).
- Update container height to `40`.

#### [PlaybackViewModel.swift](file:///Users/weiyunjun/Documents/Code/CueSeeker/apps/macos-native/Sources/CueSeekerApp/Playback/PlaybackViewModel.swift)
- Implement `showLibraryNavigationFeedback(direction: SearchResultNavigationDirection, hasResult: Bool)` and `showShioriNavigationFeedback(direction: SearchResultNavigationDirection, hasResult: Bool)` methods to display custom chevrons and texts in the HUD.

#### [AppCoordinator.swift](file:///Users/weiyunjun/Documents/Code/CueSeeker/apps/macos-native/Sources/CueSeekerApp/App/AppCoordinator.swift)
- Implement unified navigation:
  - `canGoPrevious: Bool` & `goPrevious()`
  - `canGoNext: Bool` & `goNext()`
- Bind these calls dynamically to current `.search`, `.library`, or `.shiori` modes.
- Implement Shiori adjacent page navigation: `canOpenPreviousShiori`, `canOpenNextShiori`, `openPreviousShiori()`, and `openNextShiori()`.

#### [AppCoordinator+Playback.swift](file:///Users/weiyunjun/Documents/Code/CueSeeker/apps/macos-native/Sources/CueSeekerApp/App/AppCoordinator+Playback.swift)
- Re-bind keyCode `0` (Key A) and `2` (Key D) under `handlePlaybackKeyDown` to call unified `goPrevious()` and `goNext()`.

#### [AppCoordinator+Library.swift](file:///Users/weiyunjun/Documents/Code/CueSeeker/apps/macos-native/Sources/CueSeekerApp/App/AppCoordinator+Library.swift)
- Call `showLibraryNavigationFeedback` inside `openPreviousLibraryVideo()` and `openNextLibraryVideo()`.

#### [AppCoordinator+Shiori.swift](file:///Users/weiyunjun/Documents/Code/CueSeeker/apps/macos-native/Sources/CueSeekerApp/App/AppCoordinator+Shiori.swift)
- Call `showShioriNavigationFeedback` inside `openPreviousShiori()` and `openNextShiori()`.

#### [PlaybackChromeSpeedMenu.swift](file:///Users/weiyunjun/Documents/Code/CueSeeker/apps/macos-native/Sources/CueSeekerApp/Playback/Chrome/PlaybackChromeSpeedMenu.swift)
- Update popup styling to use `PlaybackTheme.cinematicBacking` and a subtle white border.

## Verification Plan

### Automated Tests
- Run `swift build` and `swift test` to confirm compilation is completely clean and zero regressions are introduced.

### Manual Verification
1. **Vertical Alignment**: Verify that all control elements in the bottom bar are centered on the same visual height axis, all utilizing `40` as their standard container and button height.
2. **Button Hover**: Hover a standalone button to verify the concentric smaller highlight circle.
3. **Capsule Styling**: Verify grouped buttons share single capsule backings without individual bases.
4. **Active State**: Toggle CC or Sidebar active to verify solid white circle with dark icon.
5. **Unified Navigation**: Confirm Prev/Next bottom bar buttons navigate search results in search mode, library videos in library mode, and bookmarks in shiori mode.
6. **Keyboard Hotkeys**: Confirm A/D key presses behave identically to bottom bar buttons.
7. **Library/Shiori HUD Overlay**: Navigate adjacent records in Library or Shiori mode and verify that the chevron HUD overlay animations display correctly ("Previous Library Video", "Previous Bookmark", etc.).
8. **Speed Menu**: Verify the playback speed dropdown displays a semi-translucent black overlay with subtle boundaries.
