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
- **Width**: Retain the standard maximum width of **`420px`** (or full-width with a `20px` margin on both sides if the window is narrower than `460px`).
- **Ergonomics**: Center-based placement is updated to right-aligned placement using `size.width - 20 - panelWidth / 2`.

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

### 2.4 Keyword Highlight Background

To maintain high contrast and clear readability when all text is forced to white, we need a saturated, high-contrast highlight background for query-matched keywords. We propose two options for the user:

- **Option A (Recommended - Sapphire Blue)**: A deep sapphire theme blue with opacity: `Color(red: 0/255, green: 102/255, blue: 204/255).opacity(0.50)`. It looks incredibly premium in dark modes and ensures perfect white text contrast.
- **Option B (Amber Gold)**: A warm, saturated deep amber: `Color(red: 230/255, green: 130/255, blue: 0/255).opacity(0.45)`.

### 2.5 Scrollbar and Line Cleanups

- **Header Hairline**: Completely **remove the horizontal line** below the `xxx results` text in `PlaybackSidebarShell.swift`.
- **Scrollbar Introspection**: Implement a native macOS `ScrollViewIntrospector` via `NSViewRepresentable` to:
  1. Hide the scroller track and background borders: `scrollView.borderType = .noBorder`, `scrollView.drawsBackground = false`.
  2. Force the scrollbar style to modern overlay: `scrollView.scrollerStyle = .overlay`.
  3. Force the scrollbar scroller to draw a clean **white/light gray knob** by setting `scrollView.appearance = NSAppearance(named: .darkAqua)`.

---

## 3. Proposed Code Modifications

The proposed implementation involves changes to the following components:

### 1. `PlaybackPage`
#### [MODIFY] [PlaybackPage.swift](file:///Users/weiyunjun/Documents/Code/CueSeeker/apps/macos-native/Sources/CueSeekerApp/Playback/PlaybackPage.swift)
- Modify the `.position` call of `overlayPanel` to right-align the panel:
  - `x` center coordinate: `size.width - 20 - panelWidth / 2`
  - `y` center coordinate: `46 + panelHeight / 2` (where top starts at `46` instead of `64`).
- Update `overlayPanel` styling parameters (background, border, shadow) to directly use `PlaybackTheme` cinematic tokens.

### 2. `PlaybackSidebar`
#### [MODIFY] [PlaybackSidebarShell.swift](file:///Users/weiyunjun/Documents/Code/CueSeeker/apps/macos-native/Sources/CueSeekerApp/Playback/Sidebar/PlaybackSidebarShell.swift)
- Remove the `.overlay` containing the bottom `headerHairlineColor` under the header.
- Create and attach a `ScrollViewIntrospector` to the search results `ScrollView`.
- Re-style the segment control ("Search Results" vs "Subtitles") to use the chosen container background and the contrasting deeper active tab background, forcing all button text to white/gray.

#### [MODIFY] [PlaybackSidebarResultRow.swift](file:///Users/weiyunjun/Documents/Code/CueSeeker/apps/macos-native/Sources/CueSeekerApp/Playback/Sidebar/PlaybackSidebarResultRow.swift)
- Force text colors (`lineColor`, `metaColor`) to use pure white with appropriate opacities.
- Change the background and stroke of the selected row to use `PlaybackTheme.menuItemHighlight` (`Color.white.opacity(0.12)`).
- Update the keyword highlighting invocation to pass the custom dark highlight background color.

#### [MODIFY] [PlaybackSubtitlesList.swift](file:///Users/weiyunjun/Documents/Code/CueSeeker/apps/macos-native/Sources/CueSeekerApp/Playback/Sidebar/PlaybackSubtitlesList.swift)
- Create and attach `ScrollViewIntrospector` to the subtitles `ScrollView`.
- Update `PlaybackSidebarSubtitleRow` style to match the new cinematic specification: white text, `PlaybackTheme.menuItemHighlight` background for selected/hovered state.

### 3. `Search`
#### [MODIFY] [SearchView.swift](file:///Users/weiyunjun/Documents/Code/CueSeeker/apps/macos-native/Sources/CueSeekerApp/Search/SearchView.swift)
- Enhance `highlightedContent` helper to accept an optional `highlightBackgroundColor: Color? = nil` parameter to facilitate the sidebar's high-contrast white text keyword highlight background.

---

## 4. Code Cleanup Assessment

The following legacy tokens and properties will be safely removed:
1. **`PlaybackSidebarShell.swift`**:
   - `headerHairlineColor` (unused once header hairline is removed).
   - `segmentedContainerColor`, `segmentedActiveColor`, `segmentedActiveShadow` (replaced by unified cinematic variants).
2. **`PlaybackSidebarResultRow.swift`**:
   - `accentColor`, `selectedRingColor` (unneeded without yellow borders).
3. **`PlaybackPageView`**:
   - `overlayPanelBackground`, `overlayPanelBorder`, `overlayPanelShadow` (redundant with cinematic `PlaybackTheme` parameters).

---

## 5. Verification Plan

### Manual Verification
1. **Positioning Check**: Verify the sidebar is positioned exactly `20px` from the right edge and starts precisely at the bottom boundary of the top menu bar (`y: 46`).
2. **Visual Aesthetics**:
   - Verify all texts in both tabs are white.
   - Confirm selected rows have a clean, subtle semi-translucent white backdrop with no colored borders.
   - Confirm keyword highlights display high contrast with white text using the selected highlight color option.
3. **Scrollbar Elegance**:
   - Verify the line below `xxx results` is completely gone.
   - Confirm there are no vertical track line markers in the ScrollView.
   - Confirm the scrollbar knob displays a clean, elegant white pill shape.
