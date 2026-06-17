# UI Redesign Popup Layer Hover Suspension (Section 7 & 8)

This document records the implementation details for the popup layer independent interaction and Row Action Button hover suspension behavior.

## Implementation Details

### 1. General Environment Key
- A new SwiftUI EnvironmentKey `isWorkbenchPopupLayerOpen` is defined in `SubtitleTableView.swift` to track when any popup, dropdown, menu, or panel is open in the workbench shell.
- `SchemaWorkbenchSearchShell.swift` propagates its `openPopover != nil` state through this environment key:
  ```swift
  .environment(\.isWorkbenchPopupLayerOpen, openPopover != nil)
  ```

### 2. Coordinator State Tracking
- Inside the table view coordinator, a new property `isExternalPopupLayerOpen` is introduced to cache this environment state. It is populated during both `makeNSView` and `updateNSView`.
- When `isExternalPopupLayerOpen` becomes `true`:
  - The Row Action Menu is dismissed without triggering a hover recalculation: `dismissMenu(recalculateHover: false)`.
  - The hovered row index is cleared: `hoveredRow = nil`.
  - The hover buttons are hidden.
- When `isExternalPopupLayerOpen` transitions back to `false`:
  - The hover state is immediately re-evaluated using the current window mouse location.

### 3. Hover Suspension and Persistence
- While either `isMenuOpen` (Row Action Menu is open) or `isExternalPopupLayerOpen` (parent popup is open) is `true`, all mouse hover updates inside `handleMouseHover` and `updateHoveredRow` are suspended.
- This ensures the row hover background and the ellipsis button remain active and visible when the user moves the mouse into the Row Action Menu or to any other position, preventing premature dismissal of the menu.
- The old redundant dismissal check within `updateHoveredRow` has been removed.

### 4. Conditional Recalculation in Menu Dismissal
- `dismissMenu(recalculateHover:)` is updated with a parameter to distinguish whether hover states should be re-evaluated post-dismissal.
- An early exit `guard recalculateHover else { return }` is added to avoid layout updates when dismissing the menu due to an external popup opening.

## Traceability
- **Covering Requirement**: `docs/human/requirements/20260615-Feature-UI Redesign.md`
