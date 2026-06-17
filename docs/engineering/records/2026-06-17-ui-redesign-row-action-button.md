# UI Redesign Row Action Button & Menu Integration (Section 2.11 & 2.16)

Human requirement:

- `docs/human/requirements/20260615-Feature-UI Redesign.md`

## Scope

This record covers the implementation and integration of:
- **Section 2.11**: Row Action Button (`CueHoverButtons` redesign). Ellipsis button, size 36x36px, corner radius 8px, background default transparent, hover/open background `bgHover`. Ellipsis icon size aligned to `redesignControlIconSize` (20px). Cursor transitions to pointing hand (enabled) or operation not allowed (disabled) without leaking NSCursor stack.
- **Section 2.16**: Row Action Menu. Popover containing two options: "Play" (play.fill) and "Copy" (doc.on.doc) reusing identical styles and layout of `WorkbenchPopoverPanel` and `WorkbenchPopoverRow`.

## Changes

- **`SubtitleTableView.swift`**:
  - Propagated `@Environment(\.isEnabled)` from `SubtitleTableView` to `Coordinator`.
  - Added `isEnabled` property to `Coordinator` and `CueHoverButtons`.
  - Updated `CueHoverButtons` in redesign mode to render a single 36x36px ellipsis button that displays a popover menu on click.
  - Implemented menu open persistence for background hover effect.
  - Added robust dynamic cursor transitions and safety cleanup in `.onDisappear` and `.onChange(of: isEnabled)`.
  - Updated `layoutHoverButtons()` coordinates to position the 36x36px ellipsis button dynamically at the trailing edge of the cues column.

## Verification

- Compiled using `swift build` in `apps/macos-native`.
- Ran unit tests via `swift test` in `apps/macos-native`.
