# Launch And Settings Window Foreground Focus Activation

- **Date**: 2026-11-07
- **Requirement**: `docs/human/requirements/20261107-Bug-Launch And Settings Window Foreground Focus Activation.md`

## Problem Summary

After the 2026-11-05 cleanup of window focus spoofing and synthetic event injection, window presentation in `AppDelegate` was simplified to a single synchronous `makeKeyAndOrderFront` + `NSApp.activate(ignoringOtherApps: true)` call:

1. **Development / CLI launch leaving the app inactive**: When launched as a child process from the terminal or IDE on macOS 15.5, synchronous activation inside `applicationDidFinishLaunching` before the first run-loop turn completes can be ignored by WindowServer, leaving the main window ordered front while the app remains inactive (grey traffic lights, while the Search field still shows its internal first-responder blue border).
2. **Click-through on the topbar Settings button leaving both windows inactive**: Clicking the Settings button on an inactive main window triggers `showSettings(_:)` synchronously inside `leftMouseUp` while AppKit is still finishing the click-through mouse event on the main window. Without activating via `NSRunningApplication.current.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])`, re-asserting key window status on the next run-loop turn after `leftMouseUp` completes, and ensuring the pending foreground window becomes key in `applicationDidBecomeActive(_:)`, both the main window and the Settings window remain inactive.

## Implementation Steps

1. Added `activateWindowForForeground(_:sender:)` and `pendingForegroundWindow` tracking in `AppDelegate.swift` for both `presentMainWindow()` and `showSettings(_:)`:
   - Calls `NSRunningApplication.current.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])`, `NSApp.activate(ignoringOtherApps: true)`, and `targetWindow.makeKeyAndOrderFront(sender)`.
   - Re-checks on the next main run-loop turn (`DispatchQueue.main.async`) and after deferred player initialization at startup so that if the app or target window is not yet active/key after `finishLaunching` or after a click-through `leftMouseUp` completes, foreground activation and `makeKeyAndOrderFront` are re-applied.
   - Implemented `applicationDidBecomeActive(_:)` to ensure `pendingForegroundWindow` is made the key window once WindowServer completes asynchronous app activation.
2. Updated `settingsWindowWillClose(_:)` in `AppDelegate.swift` to return key focus to the main window when the Settings window closes while the app is active and the main window is visible.
3. Preserved all 2026-11-05 retrospective redlines: no overriding of `isKeyWindow`, no coordinate spoofing, no synthetic events, and no mid-`leftMouseDown` interception.

## Verification

- Verified full native compilation via `swift build` in `apps/macos-native` (`Build complete!`).
