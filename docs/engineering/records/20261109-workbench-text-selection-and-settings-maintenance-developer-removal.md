# Workbench Text Selection And Settings Maintenance Developer Removal

## Summary

- Requirement: `docs/human/requirements/20261109-UI-Workbench Text Selection And Settings Maintenance Developer Removal.md`
- Added reusable static text selection component `WorkbenchSelectableText` and global single-selection coordinator `WorkbenchStaticTextSelectionCoordinator` (`WorkbenchSelectableText.swift`, `CueSeekerMainWindow.swift`, `AppPointerShape.swift`, `SubtitleTableCoordinator+SelectionAndInput.swift`, `SubtitleTableExternalTextSelection.swift`, `WorkbenchAccessibility.swift`):
  - Supported left-mouse drag character selection, double-click word selection (and double-click drag word extension), triple-click full-text selection, and `Cmd + C` / `Edit -> Copy` clipboard copy.
  - Supported dragging from any non-interactive blank/label area into or across selectable static text (`ExternalDragState`, Liang-Barsky 2D segment-rect intersection, and line-clamped `utf16Offset`), projecting the external press point to the nearest boundary character of the entered text and continuing to track selection smoothly even if the pointer drifts outside the text bounds before mouse release.
  - Integrated with `PointerShapeProviding` and `SubtitleTableTextSelectionInteractiveView` so selectable static text surfaces report `.iBeam` (or `.grab` for clickable `File` status text), preserve the active drag pointer shape while dragging outside text bounds, revert to `.arrow` and refuse new selection when frozen/covered by an open menu or higher-layer dialog, and prevent `SubtitleTableExternalTextSelectionSession` from hijacking drags initiated on or locked onto selectable static text.
  - Enforced a single active text selection across the App, automatically clearing static text selection when clicking outside, starting another selection (static text, `SubtitleTable`, or `PlaybackSubtitleFocusReel`), focusing any text input, opening any menu (`.cueSeekerClearTextSelection`), switching pages/tabs/categories, or opening/closing dialogs.
- Enabled static text selection across the 6 specified Workbench and dialog locations (`WorkbenchDialogHeader.swift`, `TaskPanel.swift`, `LibraryRenameDialog.swift`, `CoverSummaryCard.swift`, `WorkbenchStatusIndicator.swift`, `SchemaWorkbenchSearchShell.swift`, `WorkbenchConfirmationDialog.swift`, `WorkbenchFormControls.swift`, `AnkiExportDialog.swift`):
  - `Folder Info`, `File Info`, and `Task Info` property group right-side `Value` texts (`WorkbenchDetailValueText`, `#1`/`#2` indexed rows, `Failure Reason`, and `TaskDetailProgressRow` percentage text).
  - `Rename Folder` / `Rename Files` right-side `Current Name` text.
  - `Cover Summary` `Title`, `Supporting Content` (lines 1 & 2), and `Progress Label`.
  - `WorkbenchStatusIndicator` texts (`Search` result count, `Excerpt` detail count, `Select Mode` selected row count, `Library` folder count, `Excerpt` overview list/cue count, and `File` top bar status text with click-vs-drag disambiguation on clickable status text) plus `Select Mode` toolbar batch selection banner hint.
  - `Confirmation Dialog` body message (`session.message`).
  - `Validation Message` red texts (`WorkbenchValidationMessage` when non-empty) and `Export to Anki` empty `Front` / `Back` card error texts.
- Removed `Maintenance` and `Developer` categories from `Settings` (`SettingsView.swift`, `WorkbenchAccessibility.swift`, `AppCoordinator+WorkbenchAccessibility.swift`, `WorkbenchFileView.swift`, deleted `SettingsMaintenanceCategory.swift` and `SettingsDeveloperCategory.swift`), leaving `General`, `Play`, `Shortcuts`, and `Subtitle`.

## Verification

- `swift test --package-path apps/macos-native --filter "WorkbenchSelectableTextTests|WorkbenchAccessibilityStep3Tests|TooltipTests"`
