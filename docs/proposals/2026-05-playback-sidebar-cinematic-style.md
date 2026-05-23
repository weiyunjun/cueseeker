# Proposal: Playback Sidebar Cinematic Reconstruction (Phase 3)

Status: Draft
Date: 2026-05-24
Topic: Playback Sidebar Cinematic Style & Positioning

---

## 1. Goal Description

This proposal details **Phase 3** of the native macOS playback UI modifications for CueSeeker. The goal is to reconstruct the position, scrolling ergonomics, and visual aesthetics of the playback overlay sidebar (Search Results & Subtitles) to create a cohesive, high-contrast, pure-black theater cinematic experience that matches the existing playback speed popup menu styling.

---

## 2. Proposed UI/UX Specifications

### 2.1 Positioning and Geometry

- **Alignment**: Align the sidebar to the **right side** of the video stage instead of centering it.
- **Top Inset**: Decrease the top inset from `64px` to `46px` (`PlaybackChromeMetrics.videoTopBarHeight`). This places the sidebar's top edge **exactly adjacent to the bottom edge of the top bar**.
- **Bottom Inset**: Retain the bottom inset of `104px` to prevent overlap with the bottom playback timeline chrome.
- **Right Margin**: A clean **`20px` gap** from the right edge of the screen.
- **Width**: Reduce the width by **`120px`**, shifting the maximum width from `420px` to **`300px`** (or full-width with a `20px` margin on both sides if the window is narrower than `340px`).
- **Ergonomics**: right-aligned placement using `size.width - 20 - panelWidth / 2`.

### 2.2 Cinematic Styling & Colors

- **Backdrop**: Remove system light/dark variation. Use the pure cinematic backing **`PlaybackTheme.cinematicBacking`** (`Color.black.opacity(0.55)`) with a refined border of `PlaybackTheme.textTertiary.opacity(0.3)` and shadow `.black.opacity(0.42)`.
- **Typography**: Force all texts (primary, secondary, metadata timestamps, and ranks) to use high-contrast and medium-contrast **white colors**:
  - Primary text / cues: `Color.white.opacity(0.94)`
  - Ranks / timestamps: `Color.white.opacity(0.55)` (or `Color.white` when selected)
- **Selection Highlight**: Selected rows in the Search Results and Subtitles lists will discard the yellow accent border and solid background. They will use the **`PlaybackTheme.menuItemHighlight`** (`Color.white.opacity(0.12)`) as both their hover and selection background, matching the speed preset menu exactly.

### 2.3 Options Tab (Segmented Controls) Background Specs

To prevent the controls from blending into the dark semi-transparent sidebar background (`Color.black.opacity(0.55)`), we use **frosted-white opacity** for the container base. This ensures it stands out clearly, while using a **deeper (darker) charcoal** for the selected tab to create a premium, high-visibility contrast:

- **Base Container Background**: A subtle, elegant frosted-white pill using **`Color.white.opacity(0.08)`**. Against the `0.55` dark backing, this yields a gorgeous, highly visible mid-gray base.
- **Selected Tab Background**: A deep, rich charcoal black using **`Color.black.opacity(0.50)`** (or **`Color.black.opacity(0.60)`**). Over the frosted container, this active tab stands out with a stark, premium "cut-out/sunken" physical appearance.

### 2.4 Keyword Highlight Background (Temporary Neutralization)

To keep styling clean and unified, we will keep the highlight structure intact in code but make the visual style **identical to normal text** by setting the highlight background to transparent. This preserves the highlighting class structure for future refinement:

- **Keyword Highlight Background**: **`Color.clear`** (keeps standard white text rendering without background blocks).

### 2.5 Scrollbar Track & Line Cleanups

To completely eradicate the vertical scroller track background lines and any ugly white/gray background stripes (caused by macOS drawing non-overlay scrollbar tracks in dark mode), we implement a **custom transparent scrollbar track subclass** combined with native introspection:

1. **Header Hairline**: Completely **remove the horizontal line** below the `xxx results` text in `PlaybackSidebarShell.swift`.
2. **Transparent Scroller Track Subclass**: Implement a transparent native `NSScroller` subclass in Swift to bypass slot drawing:
   ```swift
   class PlaybackTransparentScroller: NSScroller {
       override func drawKnobSlot(in slotRect: NSRect, highlight flag: Bool) {
           // Do nothing to draw a completely transparent track background
       }
   }
   ```
3. **Scrollbar Introspection**: Introspect the `NSScrollView` in the result/subtitle views to:
   - Apply the custom transparent scroller: `scrollView.verticalScroller = PlaybackTransparentScroller()`
   - Hide the scroller track and background borders: `scrollView.borderType = .noBorder`, `scrollView.drawsBackground = false`.
   - Force the scrollbar style to modern overlay: `scrollView.scrollerStyle = .overlay`.
   - Force the scrollbar scroller to draw a clean **white/light gray knob** by setting `scrollView.appearance = NSAppearance(named: .darkAqua)`.

### 2.6 Subtitles Row Selection Opacity

The active subtitle row selection highlight background is adjusted to be **softer and more transparent** to improve visual balance in the subtitles list:

- **Subtitle Row Selected Background**: **`Color.white.opacity(0.06)`** (instead of the previous `0.12` menuItemHighlight).

---

## 3. Proposed Code Modifications

The proposed implementation involves changes to the following components:

### 1. `PlaybackPage`
#### [MODIFY] [PlaybackPage.swift](file:///Users/weiyunjun/Documents/Code/CueSeeker/apps/macos-native/Sources/CueSeekerApp/Playback/PlaybackPage.swift)
- Shrink the maximum width value: change `maxWidth` calculation to use **`300px`** instead of `PlaybackOverlayPanelMetrics.maxWidth` (420px).
- Modify the `.position` call of `overlayPanel` to right-align the panel using the new width.

### 2. `PlaybackSidebar`
#### [MODIFY] [PlaybackSidebarShell.swift](file:///Users/weiyunjun/Documents/Code/CueSeeker/apps/macos-native/Sources/CueSeekerApp/Playback/Sidebar/PlaybackSidebarShell.swift)
- Change `PlaybackOverlayPanelMetrics.maxWidth` to **`300px`**.
- Define `PlaybackTransparentScroller` at the bottom of the file.
- Update `ScrollViewIntrospector` vertical scroller assignment:
  ```swift
  scrollView.verticalScroller = PlaybackTransparentScroller()
  ```

#### [MODIFY] [PlaybackSidebarResultRow.swift](file:///Users/weiyunjun/Documents/Code/CueSeeker/apps/macos-native/Sources/CueSeekerApp/Playback/Sidebar/PlaybackSidebarResultRow.swift)
- Change the keyword highlighting background color parameter from `Color.blue.opacity(...)` to **`Color.clear`** to temporarily match normal text styling while keeping the logic fully in place.

#### [MODIFY] [PlaybackSubtitlesList.swift](file:///Users/weiyunjun/Documents/Code/CueSeeker/apps/macos-native/Sources/CueSeekerApp/Playback/Sidebar/PlaybackSubtitlesList.swift)
- Update `ScrollViewIntrospector` inside the subtitle list to use `PlaybackTransparentScroller()`.
- Update `PlaybackSidebarSubtitleRow`'s `rowBackground` computed property: if selected, use **`Color.white.opacity(0.06)`** instead of `PlaybackTheme.menuItemHighlight`.

---

## 4. Verification Plan

### Manual Verification
1. **Width Check**: Verify the sidebar is visibly narrower (`300px` instead of `420px`) and sits exactly `20px` from the right edge.
2. **Scrollbar Elegance**: Confirm the scrollbar knob displays a clean, elegant white pill shape, and that its vertical track background is **100% transparent** with absolutely no vertical white stripes or track borders.
3. **Keyword Highlights**: Confirm query matching keywords are displayed exactly like normal text (no background blocks), but the highlight logic in code remains untouched.
4. **Subtitles Highlight**: Confirm selected subtitle row background uses a soft, highly transparent white background (`Color.white.opacity(0.06)`).
