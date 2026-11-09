# Player Chrome Independent Style And Translucent Overlay Unification

## Summary

- Requirement: `docs/human/requirements/20261109-UI-Player Chrome Independent Style And Translucent Overlay Unification.md`
- Decoupled `Player Chrome` components from Workbench Light / Dark Mode and unified Player floating overlay surfaces:
  - Added 4 semantic `Player Chrome` tokens to `PlaybackTheme`: `--color-player-menu-divider` (`rgba(255,255,255,0.10)`), `--color-player-scrollbar-thumb-default` (`rgba(255,255,255,0.24)`), `--color-player-scrollbar-thumb-interactive` (`rgba(255,255,255,0.38)`), and `--color-player-keycap-bg` (`rgba(255,255,255,0.14)`).
  - Removed 11 retired `Player Chrome` tokens and metrics (`controlActiveBackground`, `menuItemSelectedBackground`, `cueControlBarBorder`, `cueControlStepperBackground`, `cueControlStepperBorder`, `cueControlStatusActive`, `cueQueueToggleDotGap`, `cueQueueStatusDotSize`, `cueQueueStepperPadding`, `cueQueueStepperButtonSize`, and `cueQueueStepperButtonRadius`).
  - Removed `.environment(\.colorScheme, isPlayerChrome ? .dark : colorScheme)` from `WorkbenchPopoverPanel` and `TooltipStandardBubbleView`, and removed `1px` outer borders from `Player Chrome` popup menus (`Subtitle`, `Speed`, `More`, `Audio Track`), `Player Chrome` `Tooltip`, and `Player Cue Queue Control Bar`.
  - Updated `PlaybackFeedbackOverlay` container background from `PlaybackTheme.topbarGradientStart` to `PlaybackTheme.menuBackground` (`--color-player-menu-bg`, `rgba(0,0,0,0.55)`).
  - Updated `TooltipStandardBubbleView` and `TooltipSurfaceBackground` when `isPlayerChrome == true` to use `PlaybackTheme.menuBackground`, `PlaybackTheme.overlayShadowColor`, `PlaybackTheme.textPrimary`, and `PlaybackTheme.keycapBackground` without an outer border.
  - Updated `WorkbenchMenuDivider` and `TableScrollbarOverlayView` (`appearanceMode = .playerChrome`) so `Player Chrome` popup menus render dividers and scrollbar thumbs with dedicated `PlaybackTheme` tokens.
  - Simplified `PlaybackCueQueueControlBar` (`C-12.7`): removed the outer bar border, removed the status dot from `Auto Pause` and `Auto Switch` toggles, flattened the `Gap Stepper` by removing its nested box background/border/padding, and sized stepper `-` / `+` buttons to `28×28px` (`--height-player-cue-control`) with `6px` corner radius (`--radius-player-cue-control`).
  - Aligned `PlaybackVolumeControl` slider fill and thumb with `PlaybackTheme.errorContent` (`--color-player-error-content`) and `WorkbenchIconButton` disabled state on `Player Chrome` with `PlaybackTheme.textTertiary` (`--color-player-text-tertiary`).

## Verification

- `swift test --package-path apps/macos-native --filter "PlaybackChromeVisibilityModelTests|TooltipTests"`
