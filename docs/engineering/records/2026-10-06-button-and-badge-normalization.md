# Button And Badge Normalization

Human-owned documents:

- `docs/human/requirements/20261006-UI-Button-And-Badge-Normalization.md`
- `docs/human/design/UI Design System.md`
- `docs/human/design/UI Application Rules.md`
- `docs/human/design/Icon Registry.md`

## Why

1. **Inconsistent Button Category & Structure**:
   - The Library sort button had a label and 18px icon with an Open state matching its attached popover menu, whereas the Search and Excerpt List filter button was an icon-only button without text, causing visual and behavioral divergence between the two controls that serve the same purpose.
2. **Accent Color Overuse on Open and Badge**:
   - The count badge previously used accent color fill with white text, creating harsh contrast and visual noise.
   - The Open state for both `WorkbenchButton` and `WorkbenchIconButton` applied accent color backgrounds and borders, rather than matching the cleaner Hover appearance.
3. **Badge Visibility and Token Alignment (Scheme A)**:
   - When badge background matched button hover background (`#F3F4F6`), the badge capsule merged into the button background on hover and open.
   - Badge background is now normalized to `--color-badge-neutral-bg` (Light: `#E5E7EB`, Dark: `rgba(255, 255, 255, 0.20)`), which is one step darker than button hover in light mode, ensuring distinct badge capsule boundaries.
   - Badge text color is normalized to `--color-text-secondary` (`#494949` in Light, `#B9B9B9` in Dark), aligning with filter section labels (e.g., "Language") and button label text.
4. **Missing Exit Selection Icon**:
   - The "Exit Selection" button in batch selection mode was text-only, while other action buttons had leading icons.

## What changed

1. **Tokens (`WorkbenchRedesignTokens.swift`)**:
   - Added `badgeNeutralBg` in `WorkbenchRedesignColors.NS` (Light `#E5E7EB`, Dark `rgba(255, 255, 255, 0.20)`).
   - Added `badgeNeutralBg` and `badgeNeutralText` in `WorkbenchRedesignColors` SwiftUI wrappers.
2. **Sort and Filter Button Normalization (`SchemaWorkbenchSearchShell.swift`)**:
   - Added `title: L("table.filter")` to the filter button in `SchemaWorkbenchSearchShell`. Because the button now has a title, `iconSize` automatically resolves to `redesignButtonIconSize` (18px), matching the Library sort button.
3. **Exit Selection Button Icon (`SchemaWorkbenchSearchShell.swift`, `AppIcon.swift`, `sign-out.svg`)**:
   - Added Phosphor `sign-out` icon SVG asset (`256x256`, 16-unit stroke width) to `Resources/Icons/sign-out.svg`.
   - Registered `signOut = "sign-out"` in `AppIcon`.
   - Added `icon: .signOut` to the Exit Selection button in `SchemaWorkbenchSearchShell`.
4. **Count Badge Color Normalization (`WorkbenchControls.swift`, `TaskEntryButton.swift`, `TopbarAppEntries.swift`, `CueFacetFilterPanel.swift`)**:
   - Changed default `countBackground` in `WorkbenchButton`, `WorkbenchIconButton`, `TaskEntryButton`, and `TaskCountBadge` to `WorkbenchRedesignColors.badgeNeutralBg`.
   - Changed default `countTextColor` to `WorkbenchRedesignColors.textSecondary` (aliased as `badgeNeutralText`).
   - Updated `CueFacetFilterDialog` section compact badges to use the normalized default colors.
5. **Open State Unified with Hover (`WorkbenchControls.swift`, `LiquidGlassVideoTopBar.swift`)**:
   - In `WorkbenchButton`: `isOpen` state now uses `WorkbenchRedesignColors.bgHover`, `WorkbenchRedesignColors.borderControlHover`, and `WorkbenchRedesignColors.textSecondary`, completely eliminating accent color fills and borders.
   - In `WorkbenchIconButton`: `isOpen` state defaults `redesignBackgroundColor` to `hoverBackground` and `redesignIconColor` to `iconColor ?? WorkbenchRedesignColors.textSecondary`.
   - In `LiquidGlassVideoTopBar`: removed explicit accent overrides on `TopbarAppEntries` so player topbar entries match `PlaybackTheme.controlHoverBackground` and normalized badge colors.

## Verification

- Automated tests:
  - `swift test --filter AppIconAssetTests`: passed (6/6 tests passing, validating `sign-out.svg` resolution and stroke width).
  - `swift test --filter WorkbenchControlMetricsTests`: passed (12/12 tests passing, validating badge color tokens in light and dark mode, button open state colors, and metrics).
