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

## Remaining Work

- Add a directly bound ordinary SwiftUI scroll container whose overlay frame is
  owned by the actual viewport.
- Migrate ordinary App-owned SwiftUI scroll areas without adding virtual scroll
  state.
- Verify representative static layouts in the real Debug client, then run the
  complete test suite and release build.
