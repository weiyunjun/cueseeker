# Playback Feedback And Toast Separation And Redesign

## Summary

- Requirement: `docs/human/requirements/20261105-UI-Playback Feedback And Toast Separation And Redesign.md`
- Separated `Playback Feedback` (`C-09.5` / `L-07.4`) and `Toast` (`C-09.1` / `L-01.4`) by interface boundary:
  - Kept `Playback Feedback` strictly on the Player UI (video stage) for Play/Pause, Auto Pause, Seek, Volume/Mute, Speed, Subtitles toggle/switch, Fullscreen toggle, Playlist Previous/Next navigation and boundary/no-available prompts on the player stage, Screenshot copy, and `Loading`.
  - Routed all feedback triggered in `Playback Overlay` (`Current`, `Playlist`, `Collage`) and `Command Panel`—including cue/deep-link/selected-text copy, Collage copy/export outcomes, `Save to Excerpt` outcomes, `No Subtitle`, `Cue Not in Library`, and `No Available Results` when opening an invalid Recent Excerpt List in `Command Panel` while the panel stays open—through `ToastCenter` (`PlaybackToastRequest` / `ExcerptToastRequest`).
  - Removed the `Play` `Playback Feedback` when starting playback from `Playback Overlay` (`Current` or `Playlist`).
- Redesigned `Playback Feedback` in `PlaybackFeedbackOverlay.swift`, `PlaybackPage.swift`, `PlaybackTheme.swift`, and `PlaybackViewModel+Feedback.swift`:
  - Moved the HUD from the center of the video stage to the top-left corner (`top: 54px + 12px = 66px`, `leading: 24px`), stacked vertically in a `VStack(alignment: .leading, spacing: 12)` below `PlaybackErrorBanner` when both are visible.
  - Updated dimensions and tokens (`10px` corner radius, `14px` inline / `8px` block padding, `12px` icon-text spacing, `23px` icon/spinner, `18px / 26px` Medium `500` typography, flat `rgba(18, 18, 24, 0.66)` background without border/shadow/material, and `Motion: None` instant show/hide).
  - Unified `Loading` into the same capsule card with a `23px` spinner + localized `Loading` (`加载中` / `加載中`) text.
- Redesigned `Toast` in `Toast.swift`, `WorkbenchRedesignTokens.swift`, `WorkbenchControlMetrics.swift`, `PlaybackCueFooter.swift`, and `ContentView.swift`:
  - Updated `Toast` tokens and metrics (`260px` fixed width, `10px` corner radius, `14px` inline / `8px` block padding, `8px` icon-text gap, `16px` icon, `14px / 20px` Regular `400` text, `bgPopover` fill, `borderControl` stroke, `shadowPopover` shadow, and `textPrimary` icon/text color) while keeping `Tooltip` decoupled via `tooltipBg` and `tooltipBorder`.
  - Implemented the bottom-right 3-layer folded stack (`maximumVisibleCount = 3`, scale step `0.05` anchored at `.top`, vertical offset `-9px` per layer, `100%` opacity, behind layers matching frontmost card height with hidden internal content, and `18px` / `360ms` cubic-bezier `(0.22, 1, 0.36, 1)` upward entrance animation without consecutive-trigger deduplication).
  - Positioned `ToastStackView` at the bottom-right of the active surface (`24px` right / `24px` bottom in Workbench; `32px` right / `12px` above `PlaybackCueFooter` in Playback Overlay; `20px` inside right edge / `12px` above `PlaybackCueFooter` in Command Panel).

## Verification

- `swift test --package-path apps/macos-native --filter "ToastTests|PlaybackPresentationTransitionTests|PlaybackSubtitleFocusKeyboardActionTests|PlaybackLibraryChangeTests|PlaybackNormalShortcutTests"`
