# 2026-10-21 Clear And Suppress Hover When Window Loses Focus

## Covered Requirement

- `docs/human/requirements/20261021-Bug-Clear And Suppress Hover When Window Loses Focus.md`

## Referenced Design Documents

- `docs/human/design/ui/UI Design Rules.md`
- `docs/human/design/ui/UI Interaction Rules.md`
- `docs/human/design/ui/UI Components - Controls.md`
- `docs/human/design/ui/UI Components - Domain.md`

## Implementation Summary

1. **Window-level event-driven Hover gating (`CueSeekerWindow` & `CueSeekerHostingView`)**:
   - Added `CueSeekerWindow` (`CueSeekerMainWindow.swift`) to return an offscreen coordinate (`(-10_000, -10_000)`) from `mouseLocationOutsideOfEventStream` while the window is not the active key window (`!NSApp.isActive || !isKeyWindow`), preventing background `NSHostingView.layout()` passes from synthesizing Hover in unfocused windows.
   - Updated `CueSeekerHostingView` (`AppPointerShape.swift`) to observe `NSApplication` and `NSWindow` active/key notifications, suppress `mouseEntered`/`mouseMoved` while unfocused, dispatch `super.mouseExited` on focus loss to clear all non-frozen SwiftUI `.onHover` / `.onContinuousHover` states immediately, and dispatch `super.mouseEntered` + `super.mouseMoved` at the current mouse position upon focus regain.
   - Updated `SubtitleTablePageChromeHostingView` (`SubtitleTableView.swift`) and the Settings window (`AppDelegate.swift`) to use `CueSeekerHostingView` and `CueSeekerWindow`.
2. **Pointer shape & highlight model synchronization**:
   - Updated `AppPointerShape` to require `window.isKeyWindow` for pointer ownership and reset the cursor to `.arrow` immediately when the main window loses key focus.
   - Added `cancelScrollDebounceForWindowResign()` in `PointerHoverScrollState` and `broadcastWindowDidResignFocus()` in `CardHighlightModel` and `MenuHighlightModel` so unfrozen Hover states clear immediately on focus loss while preserving frozen states and `Select` states.
3. **AppKit tracking surfaces**:
   - Updated `SubtitleTableHeaderView`, `SubtitleVirtualTableDocumentView`, `TableScrollbarNSView`, `PlaybackCollagePreviewScrollContainerView`, `OverlaySidebarPointerMonitorNSView`, and `PlaybackProgressScrubber` to clear Hover on window focus loss, ignore pointer motion while unfocused, and re-evaluate Hover at the current mouse position when the window regains focus.

## Verification

- Ran `swift test --package-path apps/macos-native --filter "PointerHoverGateTests|CardHighlightModelTests|MenuHighlightModelTests|SubtitleTableVirtualRowTests|PointerShapeModelTests"`.
- Outcome matched expectations.
