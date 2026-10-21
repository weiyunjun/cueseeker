# 2026-10-21 Reevaluate Hover And Pointer After Scroll Debounce Across All Surfaces

## Covered Requirement

- `docs/human/requirements/20261021-Bug-Reevaluate Hover And Pointer After Scroll Debounce Across All Surfaces.md`

## Referenced Design Documents

- `docs/human/design/ui/UI Design Rules.md`
- `docs/human/design/ui/UI Interaction Rules.md`
- `docs/human/design/ui/UI Components - Controls.md`
- `docs/human/design/ui/UI Components - Domain.md`

## Implementation Summary

1. **Window-level event-driven scroll debounce (`CueSeekerWindow` & `PointerHoverScrollState`)**:
   - Wired `CueSeekerWindow.sendEvent(_ event: NSEvent)` (`CueSeekerMainWindow.swift`) to notify `PointerHoverScrollState.shared.noteScrolled()` on `.scrollWheel` events and `PointerHoverScrollState.shared.notePointerMoved()` on `.mouseMoved`, `.leftMouseDragged`, and `.rightMouseDragged` events when the window is focused.
   - Wired `PlaybackSubtitleFocusReel`'s wheel event monitor and `MenuGate`'s pointer routing to notify `PointerHoverScrollState.shared` so scroll debounce and pointer-move cancellation stay unified across all surfaces.
   - Unified `CardHighlightModel` and `MenuHighlightModel` scroll state transitions through `PointerHoverScrollState.shared` (`broadcastScrolled()`, `broadcastPointerMoved()`, `broadcastScrollSettled()`), removing redundant per-instance local `NSEvent` monitors.
2. **Hosting-view & AppKit surface re-evaluation after 300ms scroll debounce**:
   - Updated `CueSeekerHostingView` (`AppPointerShape.swift`) to suppress synthesized tracking events while `PointerHoverScrollState.shared.isScrolling` is true and observe `.cueSeekerScrollDebounceSettled` to re-evaluate SwiftUI `.onHover` / `.onPointerHover` states and `AppPointerShape` at the current pointer position once scrolling settles.
   - Updated `SubtitleVirtualTableHeaderView`, `SubtitleVirtualTableDocumentView`, `TableScrollbarOverlayView`, and `PlaybackCollagePreviewScrollContainerView` to lock Hover while `PointerHoverScrollState.shared.isScrolling` is true and re-evaluate Hover at `window.mouseLocationOutsideOfEventStream` on `.cueSeekerScrollDebounceSettled`.

## Verification

- Ran `swift test --package-path apps/macos-native --filter "PointerHoverGateTests|CardHighlightModelTests|MenuHighlightModelTests|AppPointerShapeTests"`.
- Outcome matched expectations.
