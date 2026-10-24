# 2026-10-24 Empty State Icons Neutral Gray Palette and Registry Documentation

## Covering Human Documentation

- Requirement: `docs/human/requirements/20261024-UI-Empty State Icons Neutral Gray Palette And Registry Documentation.md`
- Design authorities:
  - `docs/human/design/ui/UI Index.md`
  - `docs/human/design/ui/Empty State Icon Registry.md`
  - `docs/human/design/ui/UI Tokens.md`
  - `docs/human/design/ui/UI Components - Domain.md`

## Implementation Steps

1. Updated empty-state icon opacity metrics in `WorkbenchControlMetrics.swift` to the 5 neutral-gray tier opacities (`redesignEmptyIconBadgeFillOpacity = 0.24`, `redesignEmptyIconBaseOpacity = 0.32`, `redesignEmptyIconMidOpacity = 0.52`, `redesignEmptyIconLineOpacity = 0.58`, `redesignEmptyIconForegroundOpacity = 1.0`).
2. Updated `WorkbenchRedesignTokens.swift` to define `--color-empty-icon-badge-fill`, `--color-empty-icon-base`, `--color-empty-icon-mid`, `--color-empty-icon-line`, and `--color-empty-icon-foreground` under `Icon` using the `--color-text-muted` neutral gray base (`#717171` in Light, `#979797` in Dark), while preserving the system-accent duotone tokens (`cardIconAccent*`) for File/Task card and detail dialog icons.
3. Updated `AppEmptyStateIconMetrics` and `AppEmptyStateIconView` in `AppIcon.swift` so all 10 `68×68px` empty-state duotone icons render using the neutral-gray tokens rather than system-accent tokens.
4. Updated `WorkbenchEmptyHintTests.swift` to verify the 5 neutral-gray opacity metrics and dynamic Light/Dark sRGB color values (`#717171` / `#979797`).

## Verification

- Ran `swift test --package-path apps/macos-native --filter WorkbenchEmptyHintTests`.

## Outcome

- Result matched expectations: all 10 `68×68px` empty-state duotone icons now render in the neutral gray palette (Scheme C) across Light and Dark modes without affecting card/detail accent duotone icons.
