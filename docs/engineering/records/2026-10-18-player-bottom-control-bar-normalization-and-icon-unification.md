# 2026-10-18: Player Bottom Control Bar Normalization and Icon Unification

Human-owned documents:

- `docs/human/requirements/20261018-UI-Player Bottom Control Bar Normalization And Icon Unification.md`
- `docs/human/design/ui/UI Design Rules.md`
- `docs/human/design/ui/UI Tokens.md`
- `docs/human/design/ui/UI Components - Controls.md`
- `docs/human/design/ui/UI Components - Domain.md`
- `docs/human/design/ui/UI Layouts - Playback.md`

## Why

- The Player Bottom Control Bar (`L-07.2`) retained early-stage hardcoded styling and legacy tokens (`40×40px` circle buttons, `PlaybackCinematicBacking` persistent dark bases with `0.85` concentric scale hover animations, dual-button transport capsule, and left-side time capsule), diverging from the Player Topbar (`L-07.1`) and global `C-03.2 Icon Button / Default` / `C-04.1 Menu` specifications.
- At narrow window widths (`600px`), placing the time capsule in the bottom-left control group alongside an expanded volume slider risked horizontal crowding.
- The unplayed progress track (`rgba(0,0,0,0.60)`) lacked visibility over dark video frames, and the Player Speed Menu / Player More Menu used legacy `12px` padding, `14px` outer radius, `30px` row height, and `13px` text instead of the global `C-04.1 Menu` geometry.

## What changed

- **`PlaybackTheme.swift`**:
  - Updated `PlaybackTheme.progressTrack` to `Color.white.opacity(0.24)` (`--color-player-progress-track`) and `PlaybackTheme.progressHoverTrack` to `Color.white.opacity(0.38)` (`--color-player-progress-hover-track`).
  - Removed obsolete `PlaybackTheme.controlBackground`, `PlaybackTheme.iconSelected`, and `PlaybackCinematicBacking`.
  - Normalized `PlaybackChromeMetrics`: updated `height` to `90` (`--height-player-bottom-control-bar`), `bottomControlsRowHeight` to `44` (`--height-player-bottom-controls-row`), `bottomControlRegionHeight` to `74` (`18 + 44 + 12`), `controlsGap` to `4` (`--spacing-1`), `progressTimeGap` to `12` (`--spacing-3`), `progressTimeCapsuleGap` to `4` (`--spacing-1`), and added normalized tokens for the speed button (`speedButtonHorizontalPadding = 10`) and volume control (`volumeSliderWidth = 68`, `volumeThumbSize = 10`, `volumeValueWidth = 32`, `volumeTrailingPadding = 10`, `volumeExpandDuration = 0.18`).
- **`PlaybackChromeIconButton.swift`**:
  - Unified all bottom control bar icon buttons with `C-03.2 Icon Button / Default` (`32×32px` container, `8px` continuous corner radius, `21px` icon box, `Color.clear` default background, single-layer `PlaybackTheme.controlHoverBackground` on Hover / Open / Subtitles-enabled states, and `PlaybackTheme.textPrimary` / `PlaybackTheme.textTertiary` foreground colors).
- **`PlaybackChromeView.swift` & `PlaybackProgressScrubber.swift`**:
  - Added a bottom-to-top dark linear gradient (`PlaybackTheme.topbarGradientEnd` to `PlaybackTheme.topbarGradientStart`) across the `90px` bottom control bar surface.
  - Ungrouped the Previous and Next buttons into standalone `32×32px` icon buttons and unified left and right control group spacing to `4px` (`--spacing-1`).
  - Removed `PlaybackChromeTimeCapsule` from the bottom-left control group and added `PlaybackProgressScrubberRow` displaying current time on the left and remaining time (`-MM:SS` / `-H:MM:SS`) on the right of the progress scrubber with `12px` (`--spacing-3`) spacing in `12px` monospaced `PlaybackTheme.textPrimary`, and `32px` (`--padding-player-chrome-x` + `--spacing-2`) horizontal padding to visually align the outer edges of the time digits with the icons below.
  - Updated the hover/drag time preview box in `PlaybackProgressScrubber` to use a single-layer `PlaybackTheme.menuBackground` fill with `6px` (`--radius-field`) corner radius and `4px` (`--spacing-1`) gap above the scrubber hit area.
  - Normalized `PlaybackSpeedChromeButton` to `32px` height, `8px` corner radius, `10px` horizontal padding, and single-layer `PlaybackTheme.controlHoverBackground` on both Hover and `isOpen`.
- **`PlaybackVolumeControl.swift`**:
  - Normalized the volume control to a `32×32px` icon button when collapsed and a `32px` high, `8px` radius single-layer `PlaybackTheme.controlHoverBackground` bar when hovered (`68px` slider track, `10px` thumb, `12px` monospaced percentage label at `32px` width, `10px` trailing padding, `0.18s` expand/collapse transition).
- **`PlaybackChromeSpeedMenu.swift`, `PlaybackChromeMoreMenu.swift`, & `WorkbenchControls.swift`**:
  - Unified `PlaybackChromeSpeedMenu`, `PlaybackChromeMoreMenuOverlay`, and `WorkbenchPopoverPanel(surface: .playerChrome)` with global `C-04.1 Menu` geometry (`12px` menu radius, `6px` menu padding, `32px` item height, `6px` item radius, `10px` item horizontal padding, `8px` trailing icon padding, `8px` content gap, `14px` font size, `16px` check/caret icon size, and `0px` vertical item gap).
- **`PlaybackChromeVisibilityModelTests.swift` & `PlaybackMoreMenuTests.swift`**:
  - Updated stage tap interactive rect expectations for the `74px` `bottomControlRegionHeight` and updated More menu layout tests for the normalized `C-04.1 Menu` metrics.

## Verification

- Verified `PlaybackChromeVisibilityModelTests`, `PlaybackMoreMenuTests`, `MenuPanelHeightTests`, and `MenuHighlightModelTests` pass via `swift test --package-path apps/macos-native`.
