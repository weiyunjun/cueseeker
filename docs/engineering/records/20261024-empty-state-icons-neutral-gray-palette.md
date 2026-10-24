# 2026-10-24 Empty State Icons Neutral Gray Palette and Registry Documentation

## Covering Human Documentation

- Requirement: `docs/human/requirements/20261024-UI-Empty State Icons Neutral Gray Palette And Registry Documentation.md`
- Design authorities:
  - `docs/human/design/ui/UI Index.md`
  - `docs/human/design/ui/Empty State Icon Registry.md`
  - `docs/human/design/ui/UI Tokens.md`
  - `docs/human/design/ui/UI Components - Domain.md`

## Implementation Steps

1. Updated empty-state icon opacity metrics in `WorkbenchControlMetrics.swift` so `search-hint` retains its system-accent opacities (`redesignEmptyIconSearchCardOpacity = 0.30`, `redesignEmptyIconSearchLineOpacity = 0.58`, `redesignEmptyIconMagnifierFillOpacity = 0.22`) while the remaining 9 empty/unavailable icons use the neutral-gray tier opacities (`redesignEmptyIconBadgeFillOpacity = 0.24`, `redesignEmptyIconBaseOpacity = 0.32`, `redesignEmptyIconMidOpacity = 0.52`, `redesignEmptyIconForegroundOpacity = 1.0`).
2. Updated `WorkbenchRedesignTokens.swift` to define `--color-empty-icon-badge-fill`, `--color-empty-icon-base`, `--color-empty-icon-mid`, and `--color-empty-icon-foreground` under `Icon` using the `--color-text-muted` neutral gray base (`#717171` in Light, `#979797` in Dark), while preserving `--color-empty-icon-search-card`, `--color-empty-icon-search-line`, `--color-empty-icon-magnifier-fill`, and `cardIconAccent*` under `Accent`.
3. Updated `AppEmptyStateIconMetrics` and `AppEmptyStateIconView` in `AppIcon.swift` so `search-hint` renders with the system-accent tokens and the remaining 9 `68×68px` empty-state duotone icons render using the neutral-gray tokens.
4. Updated `WorkbenchEmptyHintTests.swift` to verify both the `search-hint` accent opacity metrics and the neutral-gray opacity metrics & dynamic Light/Dark sRGB color values (`#717171` / `#979797`).

## Verification

- Ran `swift test --package-path apps/macos-native --filter WorkbenchEmptyHintTests`.
- Ran `swift test --package-path apps/macos-native --filter AppIconAssetTests`.

## Outcome

- Result matched expectations: `search-hint` retains its system-accent duotone appearance, while the other 9 `68×68px` empty-state duotone icons render in the neutral gray palette (Scheme C) across Light and Dark modes without affecting card/detail accent duotone icons.
