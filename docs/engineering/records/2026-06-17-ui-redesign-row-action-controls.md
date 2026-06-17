# UI Redesign Row Action Button & Menu Integration (Section 2.11 & 2.16)

Human requirement:

- `docs/human/requirements/20260615-Feature-UI Redesign.md`

## Scope

This record covers the implementation and integration of:
- **Section 2.11**: Row Action Button (`CueHoverButtons` redesign). Ellipsis button, size 36x36px, corner radius 8px, background default transparent, hover/open background `bgHover`. Ellipsis icon size aligned to `redesignControlIconSize` (20px). Cursor transitions to pointing hand (enabled) or operation not allowed (disabled) without leaking NSCursor stack. Focus ring fully tokenized.
- **Section 2.16**: Row Action Menu. Self-drawn absolute-positioned panel containing three options:
  - "Copy Cue Text" (Play/Copy copy-semantics on macOS mapped to `"doc.on.doc"`), enabled.
  - "Open Context" (magnifyingglass), disabled (not integrated yet).
  - "Favorite" (star), disabled (not integrated yet).

## Steps

1. **Update `WorkbenchPopoverRow` (in `WorkbenchControls.swift`)**:
   - Added `showsCheckmarkSlot` property to allow disabling leading checkmark slots for action items.
   - Constrained redesign menu item icons to 20x20px fixed layout slot and `redesignMenuItemSymbolFontSizeMacOS` (14pt) font size.
   - Map disabled menu item icon color to `textDisabled`.
2. **Implement `RowActionMenu` (in `SubtitleTableView.swift`)**:
   - Add SwiftUI structure representing the redesign row action items.
3. **Implement Overlay Click Handler (`SubtitleTableMenuOverlayView`)**:
   - Add a flipped transparent overlay to dismiss the active row menu on tapping outside.
4. **Update `Coordinator` in `SubtitleTableView.swift`**:
   - Add properties `isMenuOpen`, `menuHost`, and `menuOverlayView`.
   - Implement `showMenu(...)` and `dismissMenu()`.
   - Auto-layout the self-drawn popover menu based on `documentView.visibleRect` bounds, sizing dynamically using `fittingSize`.
   - Implement menu dismissal triggers on scrolling, layout change, or row data changes.
5. **Update `CueHoverButtons` (in `SubtitleTableView.swift`)**:
   - Add `isMenuOpen` state checking for background coloring.
   - Implement focus ring using token metrics.
   - Handle dynamic enabled cursor changes.

## Verification

- Compiled using `swift build` in `apps/macos-native`.
- Ran unit tests via `swift test` in `apps/macos-native`.
