# File Card Dots Three Menu And Hover

Human-owned documents:

- `docs/human/requirements/20261002-UI-File Card Dots Three Menu And Hover.md`
- `docs/human/design/UI Design System.md`
- `docs/human/design/UI Application Rules.md`

## Why

1. **Card Action Consolidation**:
   - Previously, File cards at Levels 1, 2, and 3 exposed explicit text buttons on the trailing edge (e.g. `Rename Folder`, `Remove`, `Rename Files`).
   - Consolidating these actions into a single `dots-three` pure icon button (32×32px, 21px icon, 8px radius) declutters the card layout, maintains consistent trailing margins across all levels, and supports destructive warning action presentation (`Remove`).
2. **Card Hover Feedback and Token Hierarchy**:
   - Cards previously used `--color-bg-dialog` as background without visual hover feedback.
   - Standardizing card normal background to `--color-table-bg` (`#FFFFFF` Light / `#26262A` Dark) and card hover to `--color-row-hover` (`#F9FAFB` Light / `#2E2E33` Dark) unifies card hover feedback with table row hover behavior without shifting card borders (`--color-border-control`).
   - The `dots-three` button hover and open state uses `--color-row-selected` (`#F3F4F6` Light / `#36363C` Dark), providing a clear 3-tier brightness step-ladder: Page $\rightarrow$ Card Normal $\rightarrow$ Card Hover $\rightarrow$ Button Hover/Open.
3. **Menu Interaction and Modality Consistency**:
   - The contextual popover adheres to CueSeeker's established `MenuGate` (`.cardMenu`), keyboard arrow navigation, Enter trigger, Esc dismiss, non-click-through dismissal on outside clicks, global scroll freeze, text-selection clearing, and auto-flipping placement (below or above based on viewport space).

## What changed

- **Icon Asset & Registry**:
   - Added stroke master SVG asset `apps/macos-native/Sources/CueSeekerApp/Resources/Icons/dots-three.svg` (256×256 viewBox, stroke-width 16).
   - Registered `case dotsThree = "dots-three"` in `AppIcon.swift`.
- **WorkbenchFileView**:
   - Defined `FileCardMenuItem`, `FileCardMenuState`, and `FileCardMenuPopover`.
   - Updated `WorkbenchFileCard`:
     - Applied `--color-table-bg` as normal background and `--color-row-hover` on pointer hover, preserving `--color-border-control`.
     - Replaced trailing action buttons with a 32×32px `WorkbenchIconButton(icon: .dotsThree, isOpen: isMenuOpen, hoverBackground: rowSelected)` that triggers menu presentation.
     - Handled disabled state during running background operations (`isFolderOperationBlocked`).
   - Integrated `MenuGateClientView` and popover overlay on `fileScrollSurface`:
     - Pinned coordinate space `fileCardCoordinateSpaceName`.
     - Positioned popover using `MenuPlacement.openingFrame` right-aligned with the anchor button, opening downward by default and flipping upward when vertical space is constrained.
     - Bound active menu to `MenuHighlightModel` for keyboard navigation and dismissal.
   - Updated Level 1, 2, and 3 cards to pass contextual `FileCardMenuItem`s:
     - Level 1: `Rename Folder` (Neutral) and `Remove` (Destructive).
     - Level 2: `Rename Folder` (Neutral).
     - Level 3: `Rename Files` (Neutral).
- **Automated Tests**:
   - Added `apps/macos-native/Tests/CueSeekerAppTests/FileCardMenuTests.swift`:
     - Verified `FileCardMenuItem` properties, default states, and action execution.
     - Verified `MenuPlacement` opening frame calculation for normal downward and space-constrained upward placement.
     - Verified color token resolutions in Light and Dark modes (`tableBg`, `rowHover`, `rowSelected`) and `dotsThree` asset resolution.
     - Verified `FileCardMenuPopover` layout and fitting size constraints without overflow.

## Verification

- Automated tests:
  - `swift test --package-path apps/macos-native --filter FileCardMenuTests`: 4/4 passed.
  - `swift test --package-path apps/macos-native --filter AppIconAssetTests`: 5/5 passed.
- Human owner will perform manual E2E acceptance as agreed.
