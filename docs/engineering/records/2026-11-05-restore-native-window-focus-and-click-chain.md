# Restore Native Window Focus And Click Chain To Fix Launch And Popup Failures

- **Date**: 2026-11-05
- **Requirement**: `docs/human/requirements/20261105-Bug-Restore Native Window Focus And Click Chain To Fix Launch And Popup Failures.md`
- **Retrospective**: `docs/human/retrospectives/20261105-Retrospective-Window Focus Spoofing And Synthetic Event Injection Breaking Launch And Clicks.md`

## Problem Summary

Compared against the verified working baseline (`CueSeeker-1021.app`, commit `5a300794`), subsequent patches for window focus loss hover clearing (`17101f43`, `2c9fa074`), synchronous menu relay (`c2e78b7b`), and startup player warm-up (`6af5b2db`) introduced severe regressions on macOS:

1. **Launch window hidden / inactive**: `AppDelegate.applicationDidFinishLaunching` synchronously initialized `libmpv` and `CAMetalLayer` before creating the main window, and `CueSeekerWindow` overrode `isKeyWindow` with a custom `hasUserInteractionFocus` state and `isPerformingSystemActivation` guard.
2. **Popup buttons, dialogs, and Settings window failing to open or requiring two clicks**:
   - `CueSeekerWindow` overrode `mouseLocationOutsideOfEventStream` to return `NSPoint(x: -10_000, y: -10_000)` whenever its custom focus flag was false.
   - `CueSeekerHostingView` overrode `mouseEntered`, `mouseMoved`, and `mouseExited` and injected synthetic `mouseExited` events at `(-10_000, -10_000)` into `NSHostingView` during focus and scroll transitions.
   - `CueSeekerWindow.sendEvent` and `MenuGate` intercepted `leftMouseDown` / `rightMouseDown` to run `activateWindowForFocusIfNeeded`, which synchronously mutated window focus and triggered synthetic `mouseExited` events mid-click, cancelling SwiftUI button presses before `leftMouseUp`.
   - `CueSeekerWindow` installed a global mouse monitor (`NSEvent.addGlobalMonitorForEvents`) that cleared `hasUserInteractionFocus`.

## Solution

1. **Restored native window presentation and focus management**:
   - Removed `hasUserInteractionFocus`, `override var isKeyWindow`, `isFocusedForHover`, `activateWindowForFocus`, `activateWindowForFocusIfNeeded`, `clearUserInteractionFocus`, `outsideClickGlobalMonitor`, and `.cueSeekerWindowFocusChanged` from `CueSeekerWindow`.
   - Restored `presentMainWindow()` and `showSettings(_:)` in `AppDelegate` to standard `makeKeyAndOrderFront` + `NSApp.activate(ignoringOtherApps: true)`.
   - Moved `appState.ensurePlayerInitialized()` and `_ = appState.player?.renderView` to run asynchronously on the main queue after the main window is created and presented.
2. **Removed coordinate spoofing, synthetic event injection, and test backdoor overrides**:
   - Removed `override var mouseLocationOutsideOfEventStream` from `CueSeekerWindow`.
   - Restored `CueSeekerHostingView` to only manage cursor rects (`resetCursorRects` and `cursorUpdate`).
   - Removed `isWindowFocusedOverrideForTesting` and `mouseLocationOverrideForTesting` (`CueSeekerHostingViewLocationOverride`) across the entire codebase.
3. **Preserved unfocused window hover suppression via pure state-layer filtering and native tracking areas**:
   - `PressableButtonStyle` continues to evaluate `PressableHitGeometry.contains(value.location, in: proxy.size)` to clear its visual `isPressingInside` highlight when dragging outside a button, while native SwiftUI `Button` hit-testing handles action execution / cancellation on release.
   - `PointerHoverGate`, `PointerHoverLocationGate`, `PointerHoverSession`, `WindowFocusHoverSession`, `CardHighlightModel`, and `MenuHighlightModel` filter hover state in the state layer using native `NSApp.isActive && window.isKeyWindow` (scoped to each view/model's hosting `NSWindow` so opening an independent window such as Settings keeps the unfocused Main Window's hover and hand cursor suppressed) and native `NSApplication.didBecomeActiveNotification` / `didResignActiveNotification` / `NSWindow.didBecomeKeyNotification` / `didResignKeyNotification` notifications, re-evaluating the stationary pointer position via read-only `window.mouseLocationOutsideOfEventStream` and `NSTrackingArea.Options.assumeInside` when a window regains focus.
   - Custom AppKit tracking areas (`PointerHoverProbeView`, `TableScrollbarPrimitive`, `SubtitleTableHeaderView`, `SubtitleTableDocumentView`) use `.activeInKeyWindow` instead of `.activeAlways`.
