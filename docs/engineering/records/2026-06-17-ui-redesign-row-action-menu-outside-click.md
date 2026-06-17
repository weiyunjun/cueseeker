# UI Redesign Row Action Menu Outside-Click Integration (Section 7 & 8)

This document records the implementation details for elevating Row Action Menu outside-clicks to the container view and integrating window local mouse events to catch clicks outside the table.

## Implementation Details

### 1. Overlay and Menu Host Elevation
- Both `menuOverlayView` and `menuHost` have been elevated to be direct subviews of the table view `container` (`SubtitleTableContainerView`), which is non-flipped.
- In `showMenu`, we check that both `documentView` and `container` are available. If not, we reset `isMenuOpen = false` and return safely.
- Clicks on the container-level overlay `menuOverlayView` call `dismissMenu()` to hide the menu.
- The `menuOverlayView` and `menuHost` are added to the container view in sequence:
  ```swift
  if let menuOverlayView {
      container.addSubview(menuOverlayView)
  }
  if let menuHost {
      container.addSubview(menuHost)
  }
  ```
  This ensures the menu always sits on top of the overlay.

### 2. Non-Flipped Coordinate Positioning
- Since the container's coordinate system is not flipped (where Y coordinate grows upwards), Y positioning is calculated as:
  - Visually below the button: `buttonFrameInContainer.minY - menuHeight - 4`
  - Visually above the button (fallback when there is not enough bottom space): `buttonFrameInContainer.maxY + 4`
- Boundary checks are adjusted to fit within `container.bounds` (where Y ranges from 0 to height).

### 3. Local Event Monitor for Clicks Outside the Table
- A local event monitor `menuEventMonitor` (marked `nonisolated(unsafe)` for strict concurrency deinit checks) is registered in `installMenuDismissMonitor()` when the menu opens.
- The monitor intercepts all `.leftMouseDown` and `.rightMouseDown` events in the application window.
- In the monitor closure, we first verify `event.window === container.window`. If they don't match, we asynchronously call `dismissMenu()` and pass the event.
- If they match, we check if the click location converted to container coordinates is inside `menuHost.frame`.
  - If inside, the click is allowed to propagate normally.
  - If outside, we asynchronously call `dismissMenu()` to close the menu, while still allowing the event to go through so that outside controls are triggered instantly.
- The monitor is removed in `dismissMenu` and in `deinit`.
- `removeMenuDismissMonitor()` is placed before `guard recalculateHover else { return }` in `dismissMenu` to prevent event monitor leaks when the menu closes due to an external popup opening.

## Traceability
- **Covering Requirement**: `docs/human/requirements/20260615-Feature-UI Redesign.md`
