# Single Line Text Input IME Placeholder Overlap Fix

Human-owned documents:

- `docs/human/requirements/20261007-Bug-Single Line Text Input IME Placeholder Overlap.md`
- `docs/human/design/UI Design System.md`

## Why

1. **Problem**:
   - In single-line text inputs across the application (Workbench search box, Playback Command Panel search box, Excerpt List name field, Library rename field, Anki export filename field), entering text with Chinese IME (or other composition-based IMEs) caused the placeholder text to remain visible and overlap with the uncommitted pinyin/marked text.

2. **Root Cause**:
   - `WorkbenchSingleLineTextInput` used a custom `ZStack` checking `if text.isEmpty { Text(placeholder) }`.
   - During IME composition, the underlying AppKit field editor holds marked text, but SwiftUI's `text` binding is not updated until the characters are committed. Because `text.isEmpty` remained `true`, the placeholder view stayed rendered over the marked text.
   - Native controls like `WorkbenchNumberField` avoid this by passing `prompt: Text(placeholder).foregroundColor(...)` to SwiftUI's `TextField`, which integrates directly with AppKit's native placeholder hiding on IME composition.

## What changed

1. **Workbench Form Controls (`WorkbenchFormControls.swift`)**:
   - Replaced the custom `ZStack` and `if text.isEmpty` branch in `WorkbenchSingleLineTextInput` with SwiftUI's native `prompt` parameter on `TextField`:
     ```swift
     TextField(
         "",
         text: $text,
         prompt: Text(placeholder).foregroundColor(placeholderColor)
     )
     ```
   - This ensures the underlying AppKit `NSTextField` natively manages placeholder visibility, hiding it immediately upon IME marked text input without adding custom states or wrappers.

2. **Tests (`WorkbenchInputControlsTests.swift`)**:
   - Added unit test `singleLineTextInputUsesNativePrompt` verifying that `WorkbenchSingleLineTextInput` configures the native `NSTextField.placeholderString`.

## Verification

- `swift build --product CueSeeker --package-path apps/macos-native`: passed.
- `swift test --package-path apps/macos-native --filter WorkbenchInputControlsTests`: passed (5/5 tests passed).
