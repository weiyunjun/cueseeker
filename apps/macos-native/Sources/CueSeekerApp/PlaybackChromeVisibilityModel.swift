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
/// otherwise shown. The movement signal is real physical `NSEvent` mouse
/// movement; a global mouse-move means the pointer is outside the video window
/// and is itself the "moved to another area" signal.
@MainActor
final class PlaybackChromeVisibilityModel: ObservableObject {
    @Published private(set) var isPlayerUIVisible = true

    private enum State {
        case shown
        case hidden
    }

    private static let idleNanoseconds: UInt64 = 3_000_000_000
    private static let moveEventMask: NSEvent.EventTypeMask = [
        .mouseMoved,
        .leftMouseDragged,
        .rightMouseDragged,
        .otherMouseDragged
    ]

    private var state: State = .shown
    private var idleTask: Task<Void, Never>?
    private var cursorHidden = false
    private var focusObservers: [NSObjectProtocol] = []
    private var localMoveMonitor: Any?
    private var globalMoveMonitor: Any?

    // MARK: - Lifecycle

    func enterVideoPage() {
        startObservingFocus()
        startObservingMouseMovement()
        showShown()
    }

    func leaveVideoPage() {
        idleTask?.cancel()
        idleTask = nil
        stopObservingMouseMovement()
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

    // MARK: - Movement (physical pointer only)

    /// A real physical move while the pointer is over the video window.
    private func handleLocalMove() {
        // Rule 8 / rule 5: switching to / staying Shown requires the player
        // area (video window) to have focus.
        guard isPlayerWindowKey else {
            syncCursor()
            return
        }
        state = .shown
        isPlayerUIVisible = true
        syncCursor()
        restartIdleTimer()
    }

    /// A physical move whose event is delivered outside our window — the
    /// pointer has moved to another area (rule 7.1).
    private func handleGlobalMove() {
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

    // MARK: - Observers

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

    private func startObservingMouseMovement() {
        if localMoveMonitor == nil {
            localMoveMonitor = NSEvent.addLocalMonitorForEvents(
                matching: Self.moveEventMask
            ) { [weak self] event in
                // Local in-window move: delta-filter so layout/fullscreen
                // synthetic events do not count as movement.
                if Self.isPhysicalMove(event) {
                    MainActor.assumeIsolated { self?.handleLocalMove() }
                }
                return event
            }
        }
        if globalMoveMonitor == nil {
            globalMoveMonitor = NSEvent.addGlobalMonitorForEvents(
                matching: Self.moveEventMask
            ) { [weak self] _ in
                // A global mouse-move means the pointer is outside our window;
                // that itself is the "moved to another area" signal, so no
                // delta filter here (global events carry no usable delta).
                MainActor.assumeIsolated { self?.handleGlobalMove() }
            }
        }
    }

    private func stopObservingMouseMovement() {
        if let localMoveMonitor {
            NSEvent.removeMonitor(localMoveMonitor)
            self.localMoveMonitor = nil
        }
        if let globalMoveMonitor {
            NSEvent.removeMonitor(globalMoveMonitor)
            self.globalMoveMonitor = nil
        }
    }

    private static func isPhysicalMove(_ event: NSEvent) -> Bool {
        // Synthetic events from layout / fullscreen / focus changes carry no
        // movement delta; only real pointer movement does.
        event.deltaX != 0 || event.deltaY != 0
    }
}
