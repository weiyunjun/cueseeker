# Keyboard & Controller Accessibility (Step 4: Player Stage, Playback Overlay, and Command Panel)

- **Date**: 2026-11-01
- **Requirement**: `docs/human/requirements/20261031-UI-Keyboard And Controller Accessibility Across Workbench Dialogs Settings And Playback.md`
- **Scope**: Step 4 (`L-07` `Player Stage`, `L-08` `Playback Overlay`, `L-09` `Command Panel`)

## Summary

1. **`Player Stage` (`L-07`) Accessibility & Chrome Visibility (`PlaybackChromeVisibilityModel`, `PlaybackStore`, `LiquidGlassVideoTopBar`, `PlaybackCueQueueControlBar`, `PlaybackChromeView`, `PlaybackVolumeControl`)**:
   - Extended `PlaybackChromeVisibilityModel` with `setAccessibilityFocused(_:)` and `setMenuOpen(_:)`: entering Accessibility focus wakes and holds `Player UI` visible without unhiding a hidden pointer in fullscreen, and clearing Accessibility focus re-evaluates visibility against the live pointer/window state.
   - Wired the Player UI focus ring (`isPlayerChrome: true`, `rgba(255, 255, 255, 0.72)`) across `LiquidGlassVideoTopBar` (`Return Button`, `Command Panel`, `Task`, `Settings`), `PlaybackCueQueueControlBar` (`Auto-Pause`, `Auto-Switch`, `-`, `+`), and `PlaybackChromeView` (`Play / Pause`, `Previous`, `Next`, `Mute`, `Playback Overlay`, `Repeat`, `Copy Screenshot`, `Subtitles Menu`, `Playback Speed`, `More`, `Fullscreen`), including disabled buttons in traversal (no-op on activation) and keeping `Volume Slider` collapsed when `Mute` receives the focus ring.
2. **`Playback Overlay` (`L-08`) Accessibility (`PlaybackSubtitleFocusOverlay`, `PlaybackCueFooter`, `PlaybackLibrarySessionStore`, `LibraryMediaCards`)**:
   - Wired standard theme focus rings (`--accent-focus-ring`) across `PlaybackOverlayTopBar` (`Return Button`, `Current` / `Playlist` tabs, `Collage` button, `Command Panel`, `Task`, `Settings`), `Video Playlist` cards (`Video Card` body and `More` button), and `PlaybackCueFooter` action buttons across `Current`, `Subtitle Playlist`, `Video Playlist`, and `Editing Collage`.
   - Replaced the legacy `Tab` / `Shift+Tab` and controller `L1` / `R1` overlay module-cycling shortcut with unified Accessibility focus traversal (supporting auto-repeat and wrap-around). Activating a tab or `Collage` button switches the sub-view while keeping the focus ring on that control.
   - Coordinated `Select` and the focus ring in `Video Playlist`: traversing to a `Video Card` or its `More` button syncs `Select`; arrow keys only move `Select` (and sync the focus ring to the target card body) when the focus ring is inside the card grid.
3. **`Command Panel` (`L-09`) Accessibility (`PlaybackCommandPanel`, `ExcerptListCardGrid`, `LibraryMediaCards`)**:
   - Wired standard theme focus rings across `Root` (`Search Field`, `Clear Button`, `Option Rows`, `Cue Footer` `Open` button), `Recent Excerpt Lists` & `Recent Videos` (`Back Button`, cards & `More` buttons, `Cue Footer` `Open` button), and `Search Results` (`Back Button`, `Filter Button`, `Sort Button`, `Cue Footer` action buttons).
   - Coordinated `Select` and the focus ring in `Root` option rows and `Recent Excerpt Lists` / `Recent Videos` card grids so arrow keys only move `Select` when the focus ring is inside that `Select` region (or before Accessibility focus is entered), and `Space` / `Return` / `✕` always activates the element holding the focus ring.
4. **Verification**:
   - Updated `PlaybackSubtitleFocusKeyboardActionTests` and added `WorkbenchAccessibilityStep4Tests` covering `Player Stage`, `Playback Overlay`, and `Command Panel` keyboard and controller Accessibility traversal, activation, `Select` coordination, and `Player UI` visibility rules.
