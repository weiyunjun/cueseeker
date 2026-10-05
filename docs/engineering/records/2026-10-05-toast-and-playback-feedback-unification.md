# Toast And Playback Feedback Unification

Human-owned documents:

- `docs/human/requirements/20261005-UI-Toast And Playback Feedback Unification.md`
- `docs/human/design/UI Design System.md`
- `docs/human/design/UI Application Rules.md`

## Why

1. **Icon Accent Color Bug**:
   - The dark mode refinements in `20261004` added keyword matching for Toast icons. Actions without explicit status keywords (such as `table.row.copy_cue_text` "已复制台词", `copy_deep_link`, etc.) defaulted to `WorkbenchRedesignColors.accent`.
   - On systems where the macOS accent color is set to Purple, neutral copy icons unexpectedly appeared purple instead of the intended pure white.

2. **Surface Inconsistency and Material Inversion**:
   - Workbench `Toast` was previously hardcoded to an opaque flat `#2A2A2E` box in Dark Mode, losing the frosted glass translucency.
   - In-player `PlaybackFeedbackOverlay` used `.ultraThinMaterial` without a forced dark appearance, causing it to render milky white in Light Mode and pitch black in Dark Mode over a black video.
   - Over `Playback Overlay` (dark drawer `#242426`), `PlaybackFeedbackOverlay` with 55% black opacity composite rendered darker than the drawer (`#101012`), violating the "Dark mode layers lighten toward the top" rule.

## What changed

1. **Tokens (`WorkbenchRedesignTokens.swift`)**:
   - Updated `toastBg`: Light `rgba(31, 31, 31, 0.90)`, Dark `rgba(45, 45, 50, 0.92)` (Hex `#2D2D32`).
   - Updated `toastBorder`: 1px outline with `rgba(255, 255, 255, 0.15)` across both Light and Dark modes.

2. **Toast Component (`Toast.swift`)**:
   - Updated `ToastView.iconColor(for:)` to return `.white` unconditionally across all scenarios, removing status color branches and returning to the pure white monochrome HUD specification.
   - Updated `ToastView.surface` to combine `WorkbenchRedesignColors.toastBg` with `.ultraThinMaterial` forced to `.dark` color scheme, preserving frosted glass HUD texture and ensuring upward layer illumination in Dark Mode.

3. **Playback Feedback Component (`PlaybackFeedbackOverlay.swift`)**:
   - Unified `feedbackBackground` to use the same surface recipe (`toastBg` + `.dark` `.ultraThinMaterial` + `toastBorder`).
   - Unified `feedbackText` to use `WorkbenchRedesignColors.toastText`.
   - Unified `feedbackIcon` to render `.white` unconditionally across all scenarios.

4. **Automated Tests (`ToastTests.swift`)**:
   - Added `toastIconsAreAlwaysPureWhiteAcrossAllScenarios` verifying that copy, warning, failure, and success scenarios all produce `.white` icon color without any color deviation.

## Verification

- Automated tests:
  - `swift test --package-path apps/macos-native --filter ToastTests`: 7/7 passed.
  - `swift test --package-path apps/macos-native --filter PlaybackNormalShortcutTests`: 16/16 passed.
  - `swift test --package-path apps/macos-native --filter WorkbenchControlMetricsTests`: 12/12 passed.
- Compilation:
  - Built cleanly with 0 errors.
