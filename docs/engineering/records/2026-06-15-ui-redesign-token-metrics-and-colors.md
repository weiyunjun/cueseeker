# UI Redesign Global Token Metrics and Color Constants Integration

Human requirement:

- `docs/human/requirements/20260615-Feature-UI Redesign.md`

## Scope

This record covers the global refactoring of redesign dimensions (Component 2.1, 2.2, 2.3) to move away from hardcoded layout values. Instead, they are now mapped dynamically to new Redesign Core Tokens (height: 40px, corner radius: 8px) defined as centralized constants.

## Changes

- **`WorkbenchControlMetrics`**: Added centralized Redesign Metric Tokens:
  - `redesignHeight: CGFloat = 40` (filters/buttons height)
  - `redesignCornerRadius: CGFloat = 8` (control corners)
  - `redesignSearchHeight: CGFloat = 40` (search field height)
  - `redesignFieldHeight: CGFloat = 40`
  - `redesignFieldRadius: CGFloat = 8`
  - `redesignSearchRadius: CGFloat = 9999`
  - `redesignInlineClearButtonSize: CGFloat = 32`
  - `redesignPaddingX: CGFloat = 16`
- **`WorkbenchRedesignColors`**: Extracted redesign colors as proper semantic Color constants (e.g. `textPrimary`, `textMuted`, `accent`, `bgSurface`, `borderFocus`, `focusRing`, etc.) to isolate redesigned theme styles fully from legacy styles.
- **Component Refactoring**:
  - Refactored `WorkbenchSearchField` (2.1), `WorkbenchInlineClearButton` (2.2), and `WorkbenchFilterPanelTriggerButton` (2.3) in [WorkbenchControls.swift](file:///Users/weiyunjun/Documents/Code/CueSeeker/apps/macos-native/Sources/CueSeekerApp/Shared/WorkbenchControls/WorkbenchControls.swift) to replace all hardcoded layout literals and colors with references to `WorkbenchControlMetrics` redesign tokens and `WorkbenchRedesignColors`.
  - Refactored `SchemaWorkbenchFilterControlBar` and `SchemaWorkbenchStyle` in [SchemaWorkbenchSearchShell.swift](file:///Users/weiyunjun/Documents/Code/CueSeeker/apps/macos-native/Sources/CueSeekerApp/Shared/WorkbenchSchemaSearch/SchemaWorkbenchSearchShell.swift) to dynamically layout using redesigned metric values.

## Verification

- Verified the build compiles successfully with `swift build`.
- Ran unit tests via `swift test` and confirmed all 270 tests pass.
