# Unified Custom Scrollbar Implementation Record

Status: In Progress

## Authority

- `docs/human/requirements/20260812-Feature-Unified Custom Scrollbar.md`
- `docs/human/design/UI Design System.md`

## Classification

Platform UI/UX. This work changes native macOS scrollbar presentation and
pointer interaction without changing product-domain semantics.

## Baseline

- Starting commit: `a356a006`
- Branch: `main`

## Phase 1: Existing Custom Scrollbars

- Removed the Text Area hover, scrolling, dragging, and timer-driven visibility
  state. Its custom thumb is now presented whenever its real document exceeds
  the viewport and is removed when overflow ends.
- Kept Text Area scrolling tied directly to its existing `NSScrollView` content
  size and offset.
- Kept Playback Overlay's virtual ordinal mapping, while omitting its thumb when
  the logical item count does not exceed the visible cue capacity.
- Left the Table and collage preview scrolling models unchanged.

## Verification

- Focused custom-scrollbar regression tests: 21 passed.
- The focused coverage includes shared geometry, vertical and horizontal drag,
  wheel forwarding, Text Area overflow, Table overlay hit testing, collage
  preview layout, and Playback Overlay logical scrollbar mapping.

## Phase 2: Ordinary Scroll Container

- Added `WorkbenchScrollView`, which preserves SwiftUI `ScrollView` and
  `ScrollViewReader` behavior.
- The binding view resolves only its own `enclosingScrollView`; it never scans
  ancestors, descendants, or siblings and never selects an arbitrary scroll
  view.
- The custom overlay is a sibling overlay owned by the SwiftUI viewport, not a
  child of the scrolling document or the resolved `NSScrollView`.
- Ordinary scrollbar metrics come directly from the resolved document's real
  visible rectangle, frame size, and content offset. Thumb dragging updates the
  real clip-view origin and adds no logical-index or loading state.
- Migrated Library overview as the first representative surface.

Phase 2 verification:

- Two focused layout tests passed. They cover exact overlay-to-viewport bounds,
  resize alignment, direct target identity, placement outside the scroll view,
  real-offset thumb dragging, disabled native scrollers, and no-overflow
  presentation.
- Captured the real `1433 x 821` Debug scene as
  `library-custom-scrollbar-static.png`. The thumb rendered at the Library
  viewport's far-right edge without crossing card content, and the surrounding
  title, action, and grid layout remained intact.

## Remaining Work

- Migrate ordinary App-owned SwiftUI scroll areas without adding virtual scroll
  state.
- Verify representative static layouts in the real Debug client, then run the
  complete test suite and release build.
