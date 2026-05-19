import AppKit
import SwiftUI

/// Single explicit Player-UI / cursor visibility state machine (v3).
///
/// Authoritative spec: `docs/product/12_liquid_glass_ux_mapping.md` §10.4 and
/// the proposal's "Player-UI / Cursor Visibility State Machine (v3)". This is
/// the only owner of Player-UI visibility and the playback cursor.
///
/// v3: "focus" means the video (playback) window is the key window. The cursor
/// is governed solely by Definition 4 — hidden iff the state is Hidden AND the
/// video window is key AND the live cursor position is inside the player area;
/// otherwise shown. Player-area enter/leave and in-area movement are delivered
/// by a single authoritative `NSTrackingArea` overlay
/// (`PlaybackChromeTrackingView`) through `pointerMovedInPlayerArea()` /
/// `pointerExitedPlayerArea()`.
@MainActor
final class PlaybackChromeVisibilityModel: ObservableObject {
    @Published private(set) var isPlayerUIVisible = true

    private enum State {
        case shown
        case hidden
    }

    private static let idleNanoseconds: UInt64 = 3_000_000_000

    private var state: State = .shown
    private var idleTask: Task<Void, Never>?
    private var cursorHidden = false
    private var focusObservers: [NSObjectProtocol] = []

    // MARK: - Lifecycle

    func enterVideoPage() {
        startObservingFocus()
        showShown()
    }

    func leaveVideoPage() {
        idleTask?.cancel()
        idleTask = nil
        stopObservingFocus()
        showCursor()
    }

    /// Entering playback fullscreen forces the not-shown state. It stays
    /// not-shown until a real in-area mouse movement (rule 8).
    func enteringFullscreen() {
        idleTask?.cancel()
        idleTask = nil
        state = .hidden
        isPlayerUIVisible = false
        syncCursor()
    }

    // MARK: - Pointer (driven by the NSTrackingArea overlay)

    /// The pointer entered or moved within the player area. Rule 8 / rule 5:
    /// switching to / staying Shown requires the player area (video window) to
    /// have focus.
    func pointerMovedInPlayerArea() {
        guard isPlayerWindowKey else {
            syncCursor()
            return
        }
        state = .shown
        isPlayerUIVisible = true
        syncCursor()
        restartIdleTimer()
    }

    /// Rule 7.1: the pointer left the player area (the video window).
    func pointerExitedPlayerArea() {
        if state == .shown {
            transitionToHidden()
        } else {
            syncCursor()
        }
    }

    // MARK: - Focus (the video window is key)

    private var isPlayerWindowKey: Bool {
        NSApp?.mainWindow?.isKeyWindow == true
    }

    private func focusChanged() {
        if isPlayerWindowKey {
            // Regaining focus must not show Player UI (rule 8 needs a move);
            // just re-assert the cursor for the current state.
            syncCursor()
        } else if state == .shown {
            // Rule 7.3: the player area lost focus.
            transitionToHidden()
        } else {
            syncCursor()
        }
    }

    // MARK: - State helpers

    private func showShown() {
        idleTask?.cancel()
        state = .shown
        isPlayerUIVisible = true
        syncCursor()
        restartIdleTimer()
    }

    private func transitionToHidden() {
        idleTask?.cancel()
        idleTask = nil
        state = .hidden
        isPlayerUIVisible = false
        syncCursor()
    }

    private func restartIdleTimer() {
        idleTask?.cancel()
        guard state == .shown else {
            idleTask = nil
            return
        }
        idleTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: Self.idleNanoseconds)
            guard !Task.isCancelled else {
                return
            }
            self?.idleElapsed()
        }
    }

    private func idleElapsed() {
        // Rule 7.2: the mouse is in the player area and did not move for 3s.
        guard state == .shown, isPlayerWindowKey, isCursorInPlayerArea() else {
            return
        }
        transitionToHidden()
    }

    // MARK: - Cursor (Definition 4, single balanced owner)

    private func isCursorInPlayerArea() -> Bool {
        guard let window = NSApp?.mainWindow else {
            return false
        }
        return window.frame.contains(NSEvent.mouseLocation)
    }

    /// Definition 4: the cursor is hidden iff the state is Hidden AND the video
    /// window is key AND the live cursor position is inside the player area;
    /// otherwise it is shown.
    private func syncCursor() {
        if state == .hidden, isPlayerWindowKey, isCursorInPlayerArea() {
            hideCursor()
        } else {
            showCursor()
        }
    }

    private func showCursor() {
        guard cursorHidden else {
            return
        }
        cursorHidden = false
        NSCursor.unhide()
    }

    private func hideCursor() {
        guard !cursorHidden else {
            return
        }
        cursorHidden = true
        NSCursor.hide()
    }

    // MARK: - Focus observers

    private func startObservingFocus() {
        guard focusObservers.isEmpty else {
            return
        }
        let center = NotificationCenter.default
        // The video window losing/gaining key drives focus. App
        // activate/deactivate also resigns/restores the main window's key
        // state, so window-key notifications cover cmd-tab too. Per rule 12,
        // the video page's own popovers/menus are in-window SwiftUI overlays
        // (no separate key window), so they do not flip the key window.
        for name in [
            NSWindow.didBecomeKeyNotification,
            NSWindow.didResignKeyNotification,
            NSApplication.didBecomeActiveNotification,
            NSApplication.didResignActiveNotification
        ] {
            focusObservers.append(
                center.addObserver(
                    forName: name,
                    object: nil,
                    queue: .main
                ) { [weak self] _ in
                    MainActor.assumeIsolated { self?.focusChanged() }
                }
            )
        }
    }

    private func stopObservingFocus() {
        focusObservers.forEach { NotificationCenter.default.removeObserver($0) }
        focusObservers.removeAll()
    }
}
