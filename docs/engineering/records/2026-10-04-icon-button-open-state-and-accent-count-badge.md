# Icon Button Open State And Accent Count Badge

Human-owned documents:

- `docs/human/requirements/20261004-UI-Icon Button Open State And Accent Count Badge.md`
- `docs/human/design/UI Design System.md`
- `docs/human/design/UI Application Rules.md`

## Why

1. **Open State Distinguishability**:
   - Icon Buttons (`WorkbenchIconButton`) previously shared the exact same visual appearance between `Hover` and `Open` (`Surface Hover`). When panels/dialogs were opened or select mode was enabled, buttons lacked a persistent, unambiguous active state.
   - Solid accent color for buttons was evaluated and rejected due to heavy visual weight and color collision with accent badges.
   - An accent tint background (`--color-bg-active`) provides clear active state feedback while keeping icon glyph colors constant (dark in Light mode, white in Dark and Playback modes).
2. **Count Badge Contrast & Brand Consistency**:
   - Number badges on Filter triggers, Task entries, and Filter Dialog section headers previously used `--color-text-muted` (grey), which had weak visual hierarchy on both light surfaces and dark video topbars.
   - Updated to use `macOS Accent Color` solid background with `--color-icon-on-dark` (`#FFFFFF`) text, ensuring high contrast, clean layering on open buttons, and cross-surface consistency.

## What changed

1. **Tokens**:
   - In `WorkbenchRedesignTokens.swift`, updated `NS.bgActive` to `NSColor.controlAccent(lightAlpha: 0.12, darkAlpha: 0.22)` and `NS.bgActiveHover` to `NSColor.controlAccent(lightAlpha: 0.18, darkAlpha: 0.30)`.
   - In `PlaybackTheme.swift`, added `controlActiveBackground: Color` (`Color.accentColor.opacity(0.26)`) for the cinematic player chrome environment.
2. **WorkbenchIconButton**:
   - Added `openBackground: Color? = nil`, defaulting open background to `WorkbenchRedesignColors.bgActive`.
   - Updated default `countBackground` to `Color.accentColor` and `countTextColor` to `WorkbenchRedesignColors.iconOnDark`.
   - Updated `redesignBackgroundColor` to return `openBackground ?? WorkbenchRedesignColors.bgActive` when `isOpen`, and `hoverBackground` when hovered.
   - For disabled buttons (`!isEnabled`), count badge background dims to `countBackground.opacity(0.35)` while maintaining white text, preserving the active filter semantic indication without neutral grey wash-out.
3. **Topbar App Entries & Task Entry**:
   - In `TaskEntryButton.swift` and `TopbarAppEntries.swift`, added `openBackground: Color? = nil` parameter forwarding to `WorkbenchIconButton` and updated count badge default colors.
   - In `LiquidGlassVideoTopBar.swift`, passed `openBackground: PlaybackTheme.controlActiveBackground` and accent badge colors for cinematic topbar rendering.
4. **Filter Dialog Section Badges**:
   - In `CueFacetFilterPanel.swift`, updated `TaskCountBadge` in section headers to use `Color.accentColor` background and `WorkbenchRedesignColors.iconOnDark` text.
5. **Unit Verification**:
   - In `WorkbenchControlMetricsTests.swift`, added `iconButtonOpenAndBadgeColorTokensMatchDesignSpecification` asserting icon button defaults, open background fallback, and Playback active background token.

## Verification

- Automated tests:
  - `swift test --package-path apps/macos-native --filter WorkbenchControlMetricsTests`: 8/8 passed.
  - `swift test --package-path apps/macos-native --filter WorkbenchInputControlsTests`: 4/4 passed.
