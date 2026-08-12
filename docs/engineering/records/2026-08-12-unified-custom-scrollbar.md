# Unified Custom Scrollbar Implementation Record

Status: Complete

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

## Phase 3: App-Wide Ordinary Scroll Areas

- Migrated the remaining SwiftUI page, list, grid, command-panel, and sidebar
  scroll areas to `WorkbenchScrollView`.
- Replaced the Settings Library native `List` with a lazy stack inside the
  shared container so that it no longer owns an implicit platform scrollbar;
  the existing folder-row content and actions remain unchanged.
- Preserved every existing `ScrollViewReader` anchor path. A focused integration
  test confirms that programmatic scrolling still updates the real content
  offset.
- Audited App sources after migration. The only remaining SwiftUI `ScrollView`
  constructor is the one encapsulated by `WorkbenchScrollView`; the existing
  Table, Text Area, collage preview, and Playback Overlay AppKit scroll areas
  retain their dedicated custom overlays.
- Aligned the derived UX, Search, Liquid Glass mapping, and changelog documents
  with the committed human requirement. No file under `docs/human/` was edited.

## Final Verification

- Focused ordinary-scroll-container tests: 4 passed. They verify exact target
  identity, overlay-to-viewport alignment before and after resize, placement
  outside the scroll document, disabled native scrollers, real-offset thumb
  dragging on both axes, independent horizontal and vertical metrics,
  no-overflow omission, and `ScrollViewReader` positioning.
- Focused scrollbar regression selection: 8 passed.
- Complete Swift test run: 979 Swift Testing tests and 8 XCTest tests passed
  with zero failures. The repository's known shared-persistence migration test
  was skipped by its standard command.
- Release build completed successfully. The linker emitted only the existing
  duplicate-rpath warnings.
- Real Debug capture verification:
  - `all-migrated-library-static.png`: Library thumb remained at the main
    content viewport edge without crossing cards.
  - `settings-after-scrollbar-migration.png`: Settings Library retained a
    coherent static row layout and showed no thumb without overflow.
  - `settings-developer-custom-scrollbar-static.png`: the overflowing Settings
    Developer page showed the custom thumb at its own viewport edge without
    intruding into the sidebar or cards.

## Outcome

The implementation matches the current persistent-overflow scope. Ordinary
scroll areas use real scroll metrics without virtual loading or logical-index
state, while Table and Playback Overlay preserve their specialized virtual
models. Automatic visibility behavior remains out of scope. Final physical
wheel, trackpad, hover-color, and drag acceptance remains with the project
owner as required by the human-owned requirement.
