# Workbench Toolbar Buttons Standardization

Human-owned documents:

- `docs/human/requirements/20261005-UI-Workbench Toolbar Buttons Standardization.md`
- `docs/human/design/UI Design System.md`
- `docs/human/design/UI Application Rules.md`

## Why

1. **Toolbar Visual Cohesion**:
   - Standardize page-level toolbar actions (Filter, Sort, Select) in Workbench search and list views to follow the unified Neutral button specification.
   - Eliminate visual fragmentation between ghost-style icon buttons and bordered neutral buttons across toolbars.

2. **Component Architecture Cleanliness**:
   - Formalize the two-tier button structure:
     - Topbar / Global Chrome: Ghost Icon Buttons (unbordered, transparent background by default).
     - Workbench View Controls: Neutral Buttons (1px control border, control background, 8px corner radius).
   - Ensure `WorkbenchButton` supports icon-only, icon + count badge, and icon + title variants.

3. **Active/Open State Color Linkage & Accent Border**:
   - Link `isOpen: true` states to `--color-bg-active`, `--color-text-active`, `--color-icon-active`, and `--color-border-active`.
   - On bordered Neutral buttons, switch border color to dynamic Accent color when open, matching Filter Chip selected style.
   - Remove legacy hardcoded blue (`#0040FF`) so all active tokens dynamically track the system's `macOS accent color`.

## What changed

1. **Tokens (`WorkbenchRedesignTokens.swift`)**:
   - Updated `accent`, `textActive`, `iconActive`, and `borderActive` to dynamically bind to `NSColor.controlAccentColor` / `Color.accentColor`, eliminating hardcoded blue.

2. **Workbench Controls (`WorkbenchControls.swift`)**:
   - Upgraded `WorkbenchButton` to support optional title (`title: String? = nil`), count badge (`count: Int = 0`, `countBackground`, `countTextColor`), and optional height override.
   - Implemented square sizing and compact slack padding for icon-only and icon+badge Neutral buttons.
   - Updated `WorkbenchButton`'s `borderColor` in `isOpen` state to use `WorkbenchRedesignColors.borderActive` (Accent color).
   - Linked `isOpen` state to `WorkbenchRedesignColors.textActive` and `WorkbenchRedesignColors.iconActive`.
   - Updated `WorkbenchIconButton` to link `isOpen` state to `WorkbenchRedesignColors.iconActive` when default `iconColor` is used.

3. **Search Shell Toolbar (`SchemaWorkbenchSearchShell.swift`)**:
   - Replaced `WorkbenchIconButton` with `WorkbenchButton` for the Filter Trigger and Select Mode Action controls, establishing consistent Neutral control frames across the search toolbar.

4. **Tests (`WorkbenchControlMetricsTests.swift`)**:
   - Added assertions verifying active tokens dynamically match `NSColor.controlAccentColor`.
   - Added `workbenchButtonNeutralVariantsAndOpenColorLinkage` verifying icon-only, icon+badge, and icon+title variants as well as active color token bindings.
   - Added `workbenchIconButtonOpenStateMatchesSpecification` verifying open state configuration.

## Verification

- Automated tests:
  - `swift test --filter WorkbenchControlMetricsTests`: 12/12 passed.
  - `swift test --filter SchemaWorkbenchCountSummaryTests`: 3/3 passed.
