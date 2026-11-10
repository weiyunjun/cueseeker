# 2026-11-10: Shortcut Field Right Alignment and Borderless Hover Refinement

## Requirement Source
- `docs/human/requirements/20261110-UI-Shortcut Field Right Alignment And Borderless Hover Refinement.md`
- `docs/human/design/ui/UI Tokens.md`
- `docs/human/design/ui/UI Components - Controls.md`
- `docs/human/design/ui/UI Components - Domain.md`

## Summary of Changes
1. **Right-Aligned Keycaps in `PlaybackShortcutField` (`SettingsShortcutsCategory.swift`)**:
   - Updated `PlaybackShortcutField` content alignment (`resolvedContentAlignment`) to `.trailing` when not recording so shortcut keycaps align with the trailing edge of the `144px` container (`--padding-field-x: 10px` inset), while keeping the recording placeholder `.leading`-aligned and the `Inline Clear` button `.trailing`-aligned during recording.
2. **Borderless Default/Empty Container with Hover/Pressed Fill and Keycap Hover/Pressed Sync (`SettingsShortcutsCategory.swift`)**:
   - Removed the always-on border and background fill in `Default` and `Empty` states (`Color.clear` background, `nil` border).
   - Added pointer hover tracking (`.onPointerHover`) and `PressableButtonStyle(isPressed: $isPressed, isHovered: $isHovered)` so hovering over an unrecorded `Shortcut Field` displays `--color-bg-hover` (`WorkbenchRedesignColors.bgHover`) on the container and switches internal keycaps to `--color-popover-surface-keycap-bg-hover` (`WorkbenchRedesignColors.popoverSurfaceKeycapHoverBg`), and pressing and holding advances the container to `--color-bg-pressed` (`WorkbenchRedesignColors.bgPressed`) and internal keycaps to `--color-popover-surface-keycap-bg-pressed` (`WorkbenchRedesignColors.popoverSurfaceKeycapPressedBg`).
   - Preserved `--color-bg-control` background and `--color-border-focus` border during `Recording`, and `--color-danger-text` border when `Error` (conflict) is present.
3. **Unit Tests (`PlaybackShortcutKeymapTests.swift`)**:
   - Added `shortcutFieldRightAlignsKeycapsAndUsesBorderlessHoverAndRecordingChrome` verifying content alignment, container background/border, and keycap background across Default, Empty, Hover, Pressed, Recording, and Error states.

## Verification
- Ran `swift test --package-path apps/macos-native --filter PlaybackShortcutKeymapTests` (all 10 tests passed).
