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
- The overlay hit tests only visible thumbs. Pointer events outside the thumb
  continue to reach the existing table row and hover handling.
- Thumb dragging maps overlay thumb movement back to the existing clip-view
  scroll offset and calls `reflectScrolledClipView(_:)`, so existing scroll
  notifications and visible-row updates continue to run.

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

- 284 tests passed.
- The command also printed an existing playback history disk I/O warning, but
  the test run completed successfully.

Focused coverage added:

- A scrollbar axis is hidden when its content fits the viewport.
- Vertical and horizontal axes are detected independently.
- The visible thumb uses the 8 px redesign scrollbar size.
- Thumb position maps back to the expected scroll offset.

## 6. Outcome

Section 2.21 now uses redesign-owned scrollbar rendering for the table body
while leaving native scroll mechanics and virtualized table rendering intact.
