# 2026-10-29 Text Input Click Outside Focus Cancellation And Default Focus Selection

## Requirement Reference
- `docs/human/requirements/20261029-UI-Text Input Click Outside Focus Cancellation And Default Focus Selection.md`

## Summary of Changes
1. **Base Input Primitives & Variant Decoupling (`WorkbenchNativeTextFields.swift`, `WorkbenchFormControls.swift`, `WorkbenchControls.swift`, `WorkbenchTextAreaInput.swift`, `SettingsPlayCategory.swift`, `SettingsSubtitleCategory.swift`)**:
   - Subclassed `NSTextFieldCell` (`WorkbenchSingleLineTextFieldCell`) and `NSSecureTextFieldCell` (`WorkbenchSecureTextFieldCell`) and overrode `select(withFrame:in:editor:delegate:start:length:)` so AppKit does not automatically select all text or horizontally scroll `_NSKeyboardFocusClipView` to the end of overflowing text when an input becomes first responder on mouse click.
   - Collapsed existing selection on single left-click (`clickCount == 1 && !shift`) before forwarding `mouseDown(with:)` in `WorkbenchNativeSingleLineTextField`, `WorkbenchNativeSecureTextField`, and `WorkbenchTextAreaNativeTextView`, and supported double-click word selection, triple-click line selection, and drag-to-select across `WorkbenchSingleLineContainerOverlayView`.
   - Handled `rightMouseDown` inside enabled text input containers so unfocused inputs gain focus and already-focused inputs preserve their focus and selection without popping up a native `NSMenu`.
   - Collapsed text selection and reset clip scroll origin when single-line inputs (`textDidEndEditing`) or multi-line `Text Area` (`resignFirstResponder`) lose focus.
   - Consolidated integer draft filtering and upper-bound clamping on `WorkbenchNumberField` (`filterIntegerDraft` / `normalizeIntegerDraft`), wired `WorkbenchSearchField`'s inline clear button (`✕`) to `clearTextAndFocus()`, kept `Text Area` focused when clicking or dragging its internal scrollbar, and attached `FocusedTextInputCompanionSurface` to `SettingsSubtitleColorPresetsPopover`.
2. **Window-Level Outside Click Focus Cancellation (`CueSeekerMainWindow.swift`)**:
   - In `CueSeekerWindow.sendEvent(_:)`, cancelled active text input focus (`makeFirstResponder(nil)`) on `.leftMouseDown` or `.rightMouseDown` whenever the click falls outside the focused input's container and outside any visible `FocusedTextInputCompanionView` (such as an open `Color Well` preset popover), while allowing the outside mouse event to dispatch normally.
3. **Default Focus & Select-All on Appearance (`WorkbenchNativeTextFields.swift`, `WorkbenchFormControls.swift`, `WorkbenchControls.swift`, `LibraryRenameDialog.swift`, `WorkbenchSearchView.swift`, `SchemaWorkbenchSearchShell.swift`, `PlaybackCommandPanel.swift`, `CueSeekerMainWindow.swift`, `InterfaceLayerRegistry.swift`)**:
   - Implemented one-shot native `autofocus` + `selectAllInCurrentEditor()` on `WorkbenchNativeSingleLineTextField` with automatic retry when a menu token is still dismantling on the initial frame.
   - Updated `CueSeekerMainWindow.isBehindDialog(_:)` to account for `WorkbenchDialogMotion.distance` during dialog entry transitions and guarded `InterfaceLayerRegistry.givePageFocusUp()` so it never strips focus from a field inside an opening dialog.
   - Enabled `autofocus` + select-all on `LibraryRenameDialog`, `WorkbenchSearchView` (`SchemaWorkbenchSearchToolbar` on initial entry only, without re-focusing after modal/selection-mode dismissal, and disabled on `Excerpt` detail), and `PlaybackCommandPanelRoot`.

## Verification
- Added unit tests in `WorkbenchInputControlsTests.swift`.
- Ran `swift test --package-path apps/macos-native --filter "WorkbenchInputControlsTests|WorkbenchControlMetricsTests|LibraryRenameTests|PlaybackSearchOverlayTests|MenuModalityAndFocusTests|OpensWithoutFocusTests|ExcerptListEditorDialogTests|SMBFolderDialogTests|WebDAVFolderDialogTests|FTPFolderDialogTests|NFSFolderDialogTests|WorkbenchTextAreaTests"`.
- Outcome matched expectations.
