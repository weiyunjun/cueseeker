# Implementation Record: Input Controls And Form Layouts Refinement

- **Date**: 2026-10-15
- **Requirement**: `docs/human/requirements/20261015-UI-Input Controls And Form Layouts Refinement.md`

## Summary of Changes

1. **Global Input Control Tokens & Validation Reservation Rules**:
   - Updated `WorkbenchControlMetrics`:
     - `redesignFieldHeight` (`--height-field`): `40` → `30`
     - `redesignFieldRadius` (`--radius-field`): `8` → `6` (kept `redesignTableCellHoverRadius` at `8`)
     - `redesignFieldPaddingX` (`--padding-field-x`): `16` → `10`
     - Added `redesignFormLabelWidth` (`--width-form-label`): `72`
   - Dialog form fields constantly reserve `1` line of red validation message height (`--spacing-1: 4px` gap) aligned with the input container's left edge; Settings input rows do not reserve validation line height by default.

2. **WebDav Folder Dialog (`WebDAVFolderDialog.swift`, `AppCoordinator+Indexing.swift`, `WebDAVSupport.swift`, `IndexingStore.swift`)**:
   - Switched form rows to a two-column horizontal layout (`--width-form-label: 72px`, horizontal gap `--spacing-3: 12px`, vertical row gap `--spacing-3: 12px`).
   - Made `Name` optional with localized placeholder (`webdav.field.name.placeholder`), defaulting to the last path segment of the WebDAV URL (or host on root path) via `WebDAVAddress.defaultDisplayName(for:)`.
   - Kept `Address`, `Username`, and `Password` required without placeholders.
   - Removed failure Toasts on validation/connection errors and surfaced single-line red validation messages in the reserved line directly below the bottom `Password` input.

3. **Rename Dialog (`LibraryRenameDialog.swift`, `WorkbenchFormControls.swift`)**:
   - Switched to a two-column horizontal layout (`--width-form-label: 72px`, horizontal gap `--spacing-3: 12px`, vertical row gap `--spacing-3: 12px`).
   - Preserved multi-line wrapping without truncation for `Current Name`, with `New Name` reserving `1` validation message line aligned with the input box's left edge.

4. **Excerpt List Editor Dialog (`WorkbenchControls.swift`)**:
   - Extended `redesignExcerptListEditorDescriptionHeight` down to align the `Description` (`Text Area`) bottom edge with the bottom of Line 1 of the left-side `Support Text` (`coverHeight + redesignSpacing3 + supportLine`), aligning the reserved validation message line below `Text Area` with Line 2 of `Support Text`.

5. **Export to Anki Dialog (`AnkiExportDialog.swift`, `AppCoordinator+AnkiExport.swift`)**:
   - Converted `Location` from static text to an editable single-line `Text Field` with the folder chooser `Icon Button / Default` (`.folder`) on the right (gap `--spacing-2: 8px`) and `1` reserved validation message line below, validating that the typed folder path is non-empty, exists, is a directory, and is writable.

6. **Settings Input Rows & Shortcuts Restore Button (`SettingsShortcutsCategory.swift`)**:
   - Hid the `Restore Default` button when a shortcut is at its default value (`keymap.isDefault(action)`), and resized it to reuse `Icon Button / Dialog Close` (`--size-dialog-close-button: 24px`, `--size-dialog-close-icon: 16px`, `--radius-control: 8px`).
