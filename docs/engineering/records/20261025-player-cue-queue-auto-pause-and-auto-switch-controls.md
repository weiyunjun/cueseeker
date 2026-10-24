# 20261025 Player Cue Queue Auto Pause and Auto Switch Controls

## 1. Requirement Reference

- Requirement: `docs/human/requirements/20261025-Feature-Player Cue Queue Auto Pause And Auto Switch Controls.md`
- Stabilized Design References:
  - `docs/human/design/ui/UI Design Rules.md`
  - `docs/human/design/ui/UI Interaction Rules.md`
  - `docs/human/design/ui/UI Tokens.md`
  - `docs/human/design/ui/UI Components - Controls.md`
  - `docs/human/design/ui/UI Components - Domain.md`
  - `docs/human/design/ui/UI Layouts - Playback.md`
  - `docs/human/design/ui/Icon Registry.md`
  - `docs/human/design/ui/Tooltip Usage Registry.md`

## 2. Implementation Summary

1. **Cue Queue Playback Visibility & Stability (`PlaybackStore.swift`, `AppCoordinator.swift`, `PlaybackVideoStage.swift`)**:
   - Extended `PlaybackChromeSnapshot` with `isCueQueuePlayback` and added `AppCoordinator.isCueQueuePlaybackActive` (`true` only when `activePlaybackSource` is `.search` or `.excerpt` with a selected cue item, and `false` for Library / Recent Videos / File video playlist playback).
   - Scoped `PlaybackCueQueueControlBar` to observe only `SettingsStore` and `AppLocalizationStore`, keeping the control bar's layout, state, and interactive region completely stable across playback time updates and same-video or cross-video cue transitions.
2. **Cue Queue Control Bar Component & Tokens (`PlaybackCueQueueControlBar.swift`, `PlaybackTheme.swift`, `SettingsStore.swift`, `AppIcon.swift`, `minus.svg`)**:
   - Added `minus.svg` and `AppIcon.minus` (`14pt` stroke icon at `1.15pt` line width) to pair with `AppIcon.plus`.
   - Added `SettingsStore` helpers (`autoSwitchCueSequenceGapStepMilliseconds = 100`, `canDecreaseAutoSwitchCueSequenceGap`, `canIncreaseAutoSwitchCueSequenceGap`, `decreaseAutoSwitchCueSequenceGapMilliseconds()`, and `increaseAutoSwitchCueSequenceGapMilliseconds()`).
   - Implemented `PlaybackCueQueueControlBar` above the left side of the progress scrubber (left-aligned with the bottom Play button at `24px`, `4px` above the `18px` progress scrubber hit area, and below `PlaybackProgressTimeCapsule` in Z-order), containing:
     - **Auto Pause button**: status dot (`#34D399` when active) + localized label, toggling `SettingsStore.autoPauseAfterCueFinishesEnabled`.
     - **Auto Switch button**: status dot + localized label, toggling `SettingsStore.autoSwitchToNextCuesInPlaylistEnabled` and automatically disabled when Auto Pause is off.
     - **Gap Stepper box**: `-` and `+` `100ms` step buttons (`0 ~ 10000 ms`) flanking a fixed-width (`64px`), read-only monospaced millisecond readout (`500 ms`) that prevents keyboard input/focus and layout jitter across digit-length changes (`0 ms` to `10000 ms`).
3. **Player UI Visibility, Pointer Governance, Click Isolation & Tooltips (`PlaybackCueQueueControlBar.swift`, `PlaybackVideoStage.swift`, `Localizable.strings`)**:
   - Registered the entire rounded-rectangle dock via `.playerInteractiveRegion()` so hovering anywhere inside the dock (buttons, read-only readout, disabled controls, or internal `4px` gaps) prevents the 3-second idle hide of the pointer and Player UI.
   - Absorbed clicks inside the rounded-rectangle dock so clicking disabled controls, readout text, or internal gaps never leaks through to toggle video stage play/pause, while clicking the video stage to the right of the dock continues to toggle play/pause.
   - Added 1-second hover tooltips (`player.control.auto_pause`, `player.control.auto_switch`, `player.control.auto_switch_gap.disabled`, `player.control.auto_switch_gap.decrease`, `player.control.auto_switch_gap.increase`) across English, Simplified Chinese, and Traditional Chinese without triggering center Playback Feedback HUD / Toast overlays.

## 3. Verification

- Executed `swift test --package-path apps/macos-native --filter "SettingsStorePlaybackTests|TooltipTests|PlaybackChromeVisibilityModelTests|PlaybackSegmentCompletionTests|AppIconAssetTests"`.
- All targeted unit tests compiled cleanly and passed.
