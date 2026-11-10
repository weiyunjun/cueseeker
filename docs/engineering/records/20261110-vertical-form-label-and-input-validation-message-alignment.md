# 2026-11-10: Vertical Form Label and Input Validation Message Alignment

## Requirement Source
- `docs/human/requirements/20261110-UI-Vertical Form Label And Input Validation Message Alignment.md`
- `docs/human/design/ui/UI Design Rules.md`
- `docs/human/design/ui/UI Components - Controls.md`
- `docs/human/design/ui/UI Layouts - Workbench.md`

## Summary of Changes
1. **Vertical Form Label Alignment (`WorkbenchFormFieldContainer` in `WorkbenchFormControls`)**:
   - Added `.padding(.leading, WorkbenchControlMetrics.redesignFieldPaddingX)` (`--padding-field-x: 10px`) to the top `WorkbenchFormLabel` so vertical form labels (such as `List Name` and `Description` in `Edit List` / `New Excerpt List`) align horizontally with the inner text origin of the input boxes below.
2. **Input Validation Message Alignment (`WorkbenchValidationMessage` in `WorkbenchFormControls`)**:
   - Added `.padding(.leading, WorkbenchControlMetrics.redesignFieldPaddingX)` (`--padding-field-x: 10px`) to `WorkbenchValidationMessage` so validation error text below all dialog input fields (`Edit List` / `New Excerpt List`, `Rename`, `WebDAV` / `SMB` / `FTP` / `NFS Folder`, `Export to Anki`) and `Settings -> Shortcuts` `Shortcut Field` aligns horizontally with the inner content start (`--padding-field-x: 10px`), while long shortcut conflict messages continue to extend leftward toward the action name.
3. **Unit Tests (`WorkbenchInputControlsTests`)**:
   - Extended `autofocusSelectsAllOnSearchRenameAndCommandPanelWithoutRefocusingOnModalOrSelectionDismiss` to verify `Rename` validation message alignment with `New Name` text origin.
   - Added `verticalFormLabelsAndValidationMessagesAlignWithFieldTextOrigin` verifying vertical form validation/text origin alignment and `Settings -> Shortcuts` short/long validation message alignment.

## Verification
- Ran `swift test --package-path apps/macos-native --filter "WorkbenchInputControlsTests"`.
