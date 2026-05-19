import AppKit
import SwiftUI

/// Single explicit Player-UI / cursor visibility state machine (v2).
///
/// Authoritative spec: `docs/product/12_liquid_glass_ux_mapping.md` §10.4 and
/// the proposal's "Player-UI / Cursor Visibility State Machine (v2)". This is
/// the only owner of Player-UI visibility and the playback cursor.
///
/// The movement signal comes from real physical `NSEvent` mouse-moved events,
/// not SwiftUI hover: layout / fullscreen / focus changes emit synthetic hover
/// events that must not count as movement.
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
    private var isAppActive = NSApp?.isActive ?? true
    private var pointerInPlayerArea = true
    private var idleTask: Task<Void, Never>?
    private var cursorHidden = false
    private var focusObservers: [NSObjectProtocol] = []
    private var localMoveMonitor: Any?
    private var globalMoveMonitor: Any?

    // MARK: - Lifecycle

    func enterVideoPage() {
        startObservingFocus()
        startObservingMouseMovement()
        isAppActive = NSApp?.isActive ?? true
        pointerInPlayerArea = true
        showShown()
    }

    func leaveVideoPage() {
        idleTask?.cancel()
        idleTask = nil
        stopObservingMouseMovement()
        stopObservingFocus()
        showCursor()
    }

    /// Entering playback fullscreen forces Hidden. It stays Hidden until a real
    /// in-area mouse movement (the Hidden -> Shown rule).
    func enteringFullscreen() {
        idleTask?.cancel()
        idleTask = nil
        state = .hidden
        isPlayerUIVisible = false
        if isAppActive {
            hideCursor()
        }
    }

    // MARK: - Movement (physical pointer only)

    private func handlePhysicalMove(inPlayerArea inArea: Bool) {
        // The cursor-hiding rule and the movement rules only apply while the
        // App is focused.
        guard isAppActive else {
            return
        }

        pointerInPlayerArea = inArea

        guard inArea else {
            // The mouse moved from the player area to another area.
            transitionToHidden()
            return
        }

        // Focused + in the player area + moved: Shown (and stay Shown).
        state = .shown
        isPlayerUIVisible = true
        showCursor()
        restartIdleTimer()
    }

    // MARK: - Focus

    private func appActiveChanged(_ active: Bool) {
        isAppActive = active
        if active {
            // Regaining focus must not show Player UI. Re-assert the cursor for
            // the current state: Hidden keeps the cursor hidden.
            switch state {
            case .shown:
                showCursor()
            case .hidden:
                hideCursor()
            }
        } else {
            // The App lost focus: Hidden. The cursor-hiding rule does not apply
            // while unfocused, so release the cursor to the system.
            idleTask?.cancel()
            idleTask = nil
            state = .hidden
            isPlayerUIVisible = false
            showCursor()
        }
    }

    // MARK: - State helpers

    private func showShown() {
        idleTask?.cancel()
        state = .shown
        isPlayerUIVisible = true
        if isAppActive {
            showCursor()
        }
        restartIdleTimer()
    }

    private func transitionToHidden() {
        idleTask?.cancel()
        idleTask = nil
        state = .hidden
        isPlayerUIVisible = false
        if isAppActive {
            hideCursor()
        } else {
            showCursor()
        }
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
        // The mouse is in the player area and did not move for 3 seconds.
        guard state == .shown, isAppActive, pointerInPlayerArea else {
            return
        }
        transitionToHidden()
    }

    // MARK: - Cursor (single balanced owner)

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
        focusObservers.append(
            center.addObserver(
                forName: NSApplication.didResignActiveNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated { self?.appActiveChanged(false) }
            }
        )
        focusObservers.append(
            center.addObserver(
                forName: NSApplication.didBecomeActiveNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated { self?.appActiveChanged(true) }
            }
        )
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
                if Self.isPhysicalMove(event) {
                    MainActor.assumeIsolated {
                        self?.handlePhysicalMove(inPlayerArea: true)
                    }
                }
                return event
            }
        }
        if globalMoveMonitor == nil {
            globalMoveMonitor = NSEvent.addGlobalMonitorForEvents(
                matching: Self.moveEventMask
            ) { [weak self] event in
                if Self.isPhysicalMove(event) {
                    MainActor.assumeIsolated {
                        self?.handlePhysicalMove(inPlayerArea: false)
                    }
                }
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
