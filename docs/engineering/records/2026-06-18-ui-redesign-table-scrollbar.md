# Engineering Record: UI Redesign - Table Scrollbar (Section 2.21)

## 1. Covering Human-Owned Requirement

- `docs/human/requirements/20260615-Feature-UI Redesign.md`

## 2. Scope

This record covers the implementation of Section 2.21 Table Scrollbar for the
Search 2 redesign table.

The work is intentionally limited to the table body scrollbars:

- Draw only the scrollbar thumb, with no visible track or outer rail.
- Show a scrollbar only when that axis can scroll.
- Keep a needed scrollbar visible instead of fading it out.
- Preserve the existing scroll-position update behavior.
- Preserve the existing virtualized row rendering and visible-row hydration
  strategy.

## 3. Implementation Summary

- Added a `SubtitleTableScrollbarMetrics` helper that computes scrollbar
  visibility, thumb size, thumb position, and thumb-to-scroll offset mapping
  from viewport size, content size, and content offset.
- Added a transparent `SubtitleTableScrollbarOverlayView` for the redesign
  table body. It draws only vertical and horizontal thumbs using the existing
  redesign scrollbar tokens.
- Disabled AppKit's native scrollers only for the redesign table path, avoiding
  native track or rail drawing. The underlying `NSScrollView` remains the source
  of truth for actual scrolling, clipping, momentum scrolling, and bounds-change
  notifications.
- The overlay draws only the visible 8 px thumb, but uses a transparent thumb
  hit area so the thumb can be reliably grabbed and dragged without drawing a
  track or outer rail. Pointer events outside the interactive thumb area
  continue to reach the existing table row and hover handling.
- Follow-up manual testing found that the thumb still could not be dragged
  because `hitTest(_:)` received a point in the superview coordinate space while
  thumb hit testing used overlay-local bounds. The overlay now converts the
  incoming hit-test point from its superview before resolving the interactive
  thumb area.
- Thumb dragging maps overlay thumb movement back to the existing clip-view
  scroll offset and calls `reflectScrolledClipView(_:)`, so existing scroll
  notifications and visible-row updates continue to run.
- Follow-up performance testing found drag feedback slower than the previous
  native path. Drag updates now invalidate only old/new thumb rectangles instead
  of the full overlay, duplicate visible-row notifications are skipped when the
  visible range has not changed, and row hover button layout is paused while the
  scrollbar thumb is being dragged.
- Follow-up manual testing found that row action menus could fail to appear
  after scrollbar dragging. Generic table layout and scroll callbacks no longer
  dismiss an open menu; they preserve the menu and recompute its position from
  the stored trigger anchor instead.

## 4. Virtualization Constraints Preserved

- No SwiftUI `List`, `Table`, per-row view, or per-row scrollbar state was
  introduced.
- `rowHeightCache`, `visibleRowRange(in:)`, and `drawRowsNow(in:)` were not
  changed.
- Search result count changes still update the document height through
  `resizeDocument()`, and the scrollbar overlay only reads the resulting
  scroll metrics.

## 5. Verification

Commands run from `apps/macos-native/`:

```text
swift test --quiet
```

Result:

- 290 tests passed after the follow-up row action menu persistence fix.
- The command also printed an existing playback history disk I/O warning, but
  the test run completed successfully.

Focused coverage added:

- A scrollbar axis is hidden when its content fits the viewport.
- Vertical and horizontal axes are detected independently.
- The visible thumb uses the 8 px redesign scrollbar size.
- The transparent thumb hit area is wider than the visible thumb.
- Thumb position maps back to the expected scroll offset.
- Thumb drag delta maps to a positive scroll offset.
- Overlay hit testing from a parent view coordinate resolves to the scrollbar
  overlay when the point lands on the interactive thumb area.
- Duplicate visible-row notifications are skipped for scroll offsets that stay
  within the same virtualized row range.
- Row action menus remain open across container layout callbacks.
- Row action menus remain open across scroll/bounds-change notifications.

## 6. Outcome

Section 2.21 now uses redesign-owned scrollbar rendering for the table body
while leaving native scroll mechanics and virtualized table rendering intact.
