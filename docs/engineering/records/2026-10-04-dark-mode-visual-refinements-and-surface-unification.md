# Dark Mode Visual Refinements And Surface Unification

Human-owned documents:

- `docs/human/requirements/20261004-UI-Dark Mode Visual Refinements And Surface Unification.md`
- `docs/human/design/UI Design System.md`
- `docs/human/design/UI Application Rules.md`

## Why

1. **Surface Unification Across Modals and Base Page**:
   - In Dark Mode, modal dialogs (`bgDialog`) and the Command Panel previously used `#2F2F34` (RGB 47), which was brighter than the main Workbench page background (`bgSurface`, `#1C1C1F`, RGB 28).
   - This multi-step dark gray hierarchy broke sub-component contrast when components were reused:
     - Task cards inside `TaskPanel` (using `tableBg`: `#26262A`, RGB 38) appeared sunken and darker than the dialog body (38 < 47).
     - Default Excerpt cover placeholders (`#303036`, RGB 48) merged directly into the Command Panel background (48 ≈ 47).
   - Following Occam's razor, unifying `bgDialog` in Dark Mode to `#1C1C1F` aligns modal dialogs with the Light Mode architecture, where layers are separated through scrims, drop shadows, and 1px edge outlines rather than lighter gray background fills.

2. **Toast Floating Pill Polish**:
   - The toast floating pill previously rendered identically across Light and Dark mode using a semi-transparent black material (`PlaybackTheme.menuBackground`), which lacked pop against dark pages and produced an unevenly thick top hairline due to material refraction.
   - Updated to use a dedicated floating surface token (`#2A2A2E`) with a uniform 1px outline (`#4A4A52`), text color `--color-text-primary`, and status-aware icon tints (success green, warning amber, danger red, accent blue).

3. **Checkbox Consistency**:
   - Checkbox glyphs across AppKit table rows and SwiftUI views previously used a dull grey fill (`#A1A1AA`) when checked, and lacked clear cut-out contrast.
   - Updated checked background to `NSColor.controlAccentColor` with a solid white backing beneath the cut-out checkmark, ensuring a vivid white mark inside an accent circle in both modes.

4. **Search Field Focus & Placeholder**:
   - Added an outer focus ring to `WorkbenchSearchField` matching the redesign button focus specifications, maintaining visual hierarchy when searching in Command Panel and Workbench.

## What changed

1. **Tokens (`WorkbenchRedesignTokens.swift`)**:
   - `bgDialog`: Dark Mode changed from `#2F2F34` to `#1C1C1F`.
   - `libraryCoverPlaceholderBg`: Dark Mode changed from `#303036` to `#2E2E33`.
   - `bgCheckboxChecked`: Updated to `NSColor.controlAccentColor`.
   - Added dedicated `toastBg`, `toastBorder`, and `toastText` dynamic tokens and SwiftUI wrappers.
2. **Checkbox Glyph (`WorkbenchCheckboxStyle.swift`)**:
   - Updated AppKit drawing (`drawAppKitGlyph`) and SwiftUI component (`WorkbenchCheckboxGlyph`) to render a solid white circle behind checked and indeterminate marks, making the checkmark cleanly legible against dark backgrounds.
3. **Toast (`Toast.swift`)**:
   - Replaced `PlaybackTheme.menuBackground` and `.ultraThinMaterial` with `WorkbenchRedesignColors.toastBg` and a uniform 1px `WorkbenchRedesignColors.toastBorder`.
   - Bound message text to `WorkbenchRedesignColors.toastText` and icon color to scenario status semantics.
4. **Search Field (`WorkbenchControls.swift`)**:
   - Added focus ring overlay to `WorkbenchSearchField` using `WorkbenchRedesignColors.focusRing`.
5. **Unit Verification (`WorkbenchControlMetricsTests.swift`)**:
   - Added `darkModeTokensAndSurfaceUnificationMatchDesignSpecification` asserting Dark Mode dialog background matches surface background and checked checkbox uses control accent color.

## Verification

- Automated tests:
  - `swift test --package-path apps/macos-native --filter WorkbenchControlMetricsTests`: 9/9 passed.
  - `swift test --package-path apps/macos-native --filter WorkbenchInputControlsTests`: 4/4 passed.
- Compilation:
  - `swift build --target CueSeekerApp`: built with 0 errors.
