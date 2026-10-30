# 2026-10-30 Cover More Action Button and Card Hover Polish

## Requirement Authority

- `docs/human/requirements/20261030-UI-Cover Bottom Scrim More Action And Card Hover Polish.md`
- Referenced UI design documents:
  - `docs/human/design/ui/UI Index.md`
  - `docs/human/design/ui/UI Design Rules.md`
  - `docs/human/design/ui/UI Interaction Rules.md`
  - `docs/human/design/ui/UI Tokens.md`
  - `docs/human/design/ui/UI Components - Controls.md`
  - `docs/human/design/ui/UI Components - Domain.md`
  - `docs/human/design/ui/Icon Registry.md`

## Implementation Steps

1. **Cover More Action Button `3px` Three-Dot Fill Variant (`dots-three-fill.svg`, `WorkbenchControls.swift`, `LibraryCoverViews.swift`)**:
   - Added `apps/macos-native/Sources/CueSeekerApp/Resources/Icons/dots-three-fill.svg` with three solid `<circle>` elements of radius `18.3` (`fill="currentColor"` on the `256×256` master grid), rendering each dot at a `3px` display diameter at `--size-control-icon` (`21px`).
   - Added optional `iconWeight: AppIconWeight? = nil` to `WorkbenchIconButton` and configured `LibraryCoverMoreButton` to pass `iconWeight: .fill`, while leaving all `Regular` `dots-three` and `dots-three-vertical` usages (table rows, File cards, Task cards, Cover Summary, and player bottom chrome) unchanged.
2. **Unified Cover Badge and Cover More Button Background & Three-State Opacities (`WorkbenchControlMetrics.swift`, `WorkbenchRedesignTokens.swift`)**:
   - Unified `--color-library-time-badge-bg` across Light Mode and Dark Mode to `rgba(15, 23, 42, 0.72)`.
   - Updated the cover `...` button three-state opacities across Light Mode and Dark Mode to step down from the badge background opacity:
     - `Default` (`--opacity-library-cover-action-bg`): `0.72` (`rgba(15, 23, 42, 0.72)`)
     - `Hover / Open` (`--opacity-library-cover-action-bg-hover`): `0.56` (`rgba(15, 23, 42, 0.56)`)
     - `Pressed` (`--opacity-library-cover-action-bg-pressed`): `0.40` (`rgba(15, 23, 42, 0.40)`)
3. **Removed Media Card Cover Hover & Selected Scale (`WorkbenchControlMetrics.swift`, `WorkbenchLibraryView.swift`, `LibraryCoverViews.swift`, `LibraryMediaCards.swift`, `ExcerptListCardGrid.swift`, `CardHighlightModel.swift`, `LibraryOverviewComponents.swift`)**:
   - Removed `redesignLibraryCoverHoverScale` (`--scale-library-cover-hover: 1.02`) and `LibraryCoverHoverEffectModifier` / `libraryCoverHoverEffect`.
   - Added `CardHighlightModel.animatesHoverBackground` (`!keepsCurrentWhenPointerLeaves`) and `animatesHover` on `LibraryOverviewCardSurface` / `LibraryOverviewCardButtonStyle` so Workbench media cards retain the `0.12s easeOut` (`--duration-library-cover-hover`) background transition on `Hover`, while Playback media cards (`Playback Overlay` and `Command Panel`) switch both `Hover` and `Selected` backgrounds immediately without animation.
4. **Tests (`AppIconAssetTests.swift`, `CardHighlightModelTests.swift`)**:
   - Added `.dotsThree` (`weight: .fill`) verification in `stateVariantIconsResolveFilled()`.
   - Added unit test assertions in `CardHighlightModelTests` verifying Workbench vs. Playback hover animation flags and the unified `0.72 / 0.56 / 0.40` cover action button opacities.

## Verification & Outcome

- Executed `swift test --package-path apps/macos-native --no-parallel --filter "CardHighlightModelTests|stateVariantIconsResolveFilled|everyIconResolvesAtEveryDocumentedSize|everyStrokeMasterDrawsAllItsLinesAtTheMasterWidth"`.
- Result: All tests compiled and passed, matching the requirement specification.
