# 2026-11-10: Form Label Width and Rename Current Name Alignment

## Requirement Source
- `docs/human/requirements/20261110-UI-Form Label Width And Rename Current Name Alignment.md`
- `docs/human/design/ui/UI Tokens.md`
- `docs/human/design/ui/UI Design Rules.md`
- `docs/human/design/ui/UI Layouts - Workbench.md`

## Summary of Changes
1. **Horizontal Two-Column Form Label Width (`WorkbenchControlMetrics`)**:
   - Updated `redesignFormLabelWidth` (`--width-form-label`) from `72` to `96` so horizontal two-column dialog form labels such as `Current Name` fit on a single line without wrapping.
2. **Rename Dialog Current Name Text Alignment (`LibraryRenameDialog`)**:
   - Added `.padding(.leading, WorkbenchControlMetrics.redesignFieldPaddingX)` (`--padding-field-x: 10px`) to the `Current Name` value (`rename-current-name`) so its text start aligns with the text inside the `New Name` input box below.
3. **Unit Tests (`WorkbenchControlMetricsTests`, `WorkbenchInputControlsTests`)**:
   - Updated `buttonHeightMatchesDesignSpecification` for `redesignFormLabelWidth == 96`.
   - Added verification in `autofocusSelectsAllOnSearchRenameAndCommandPanelWithoutRefocusingOnModalOrSelectionDismiss` checking that `Current Name` fits within `redesignFormLabelWidth` on a single line and that `rename-current-name` aligns horizontally with the `New Name` text field's inner text origin.

## Verification
- Ran `swift test --package-path apps/macos-native --filter "WorkbenchControlMetricsTests|WorkbenchInputControlsTests"`.
