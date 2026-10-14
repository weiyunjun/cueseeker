# Single-Line Input Normalization And Return Behavior

Human-owned documents:

- `docs/human/requirements/20261014-Bug-Single Line Input Normalization And Return Behavior.md`
- `docs/human/requirements/20261014-Feature-WebDAV Folder Support.md`
- `docs/human/design/UI Design System.md`
- `docs/human/design/UI Application Rules.md`

## Why

1. **Single-Line Input Boundary & Synchronous Normalization Before Display**:
   - Plain SwiftUI `TextField` allowed AppKit's shared field editor (`NSTextView`) to insert newlines (`\r\n`, `\n`, `\r`, `\u{2028}`, `\u{2029}`) and disallowed characters into `NSTextStorage` before SwiftUI's `Binding.set` or `.onChange` ran on a subsequent pass.
   - Kept the outer `HStack` and `.padding(.horizontal, ...)` layouts of `WorkbenchSearchField`, `WorkbenchNumberField`, `WorkbenchFormTextField`, `WorkbenchDialogFormTextField`, and `WorkbenchDialogFormPasswordField` intact while sizing `WorkbenchNativeSingleLineTextField` to its natural single-line height via `sizeThatFits`, ensuring the field and its active field editor never shift to `(0, 0)` or overlap leading icons/trailing controls.
   - Re-applied the control's 14pt font, text color, and paragraph alignment (`applyTextStyle(to:)`) to `NSTextView` and `NSTextStorage` whenever normalized text replaces characters in an empty field editor so active text never falls back to 12pt.
   - Enforced integer-only input (ASCII digits `0-9`, disallowing `.` and `-`) across Settings number fields (`Auto Switch Gap` clamped immediately to `0...10000` including overflowing digit strings; `Settings - Subtitle` `Size >= 1` and remaining 7 fields `>= 0` without upper bound), rejected replacing existing digits with purely invalid characters, and restored the previous valid number on `controlTextDidEndEditing` or Return.
2. **Return Key Behavior Without `Select All` Or Unintended `WebDav Folder` Submission**:
   - Removed `onSubmit: submitIfIdle` and `.keyboardShortcut(.defaultAction)` from `WebDAVFolderDialog`.
   - Consumed `insertNewline(_:)`, `insertNewlineIgnoringFieldEditor(_:)`, `insertLineBreak(_:)`, and `insertParagraphSeparator(_:)` in `NSTextFieldDelegate.control(_:textView:doCommandBy:)` so pressing Return (or Option/Ctrl/Shift+Return) never inserts a newline and never triggers `NSTextField`'s default `selectText(self)` (`Select All`), keeping the caret at its position while preserving IME composition commit and `Command Panel` submission.
3. **Full-Container `I-beam` Pointer And Click-to-Focus**:
   - Added a lightweight `WorkbenchSingleLineContainerOverlay` (`PointerShapeProviding`) on single-line input containers that yields hit-testing to the enclosed `NSTextField` and the search clear button (`24×24`), while providing `.iBeam` cursor and click-to-focus across the surrounding container padding and leading icon.

## What changed

- `apps/macos-native/Sources/CueSeekerApp/Shared/WorkbenchControls/WorkbenchFormControls.swift`
- `apps/macos-native/Sources/CueSeekerApp/Shared/WorkbenchControls/WorkbenchControls.swift`
- `apps/macos-native/Sources/CueSeekerApp/Library/WebDAVFolderDialog.swift`
- `apps/macos-native/Sources/CueSeekerApp/Settings/SettingsPlayCategory.swift`
- `apps/macos-native/Sources/CueSeekerApp/Settings/SettingsSubtitleCategory.swift`
- `apps/macos-native/Tests/CueSeekerAppTests/WebDAVFolderDialogTests.swift`
- `apps/macos-native/Tests/CueSeekerAppTests/WorkbenchInputControlsTests.swift`

## Verification

- `swift test --package-path apps/macos-native --filter "WorkbenchInputControlsTests|WebDAVFolderDialogTests|SettingsStorePlaybackTests"`: passed.
