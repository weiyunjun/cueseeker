import AppKit
import SwiftUI

/// Single explicit Player-UI / cursor visibility state machine (v1).
///
/// Authoritative spec: `docs/product/12_liquid_glass_ux_mapping.md` §10.4 and
/// the proposal's "Player-UI / Cursor Visibility State Machine (v1)". This is
/// the only owner of Player-UI visibility and the playback cursor; the
/// fullscreen manager no longer drives chrome or the cursor.
@MainActor
final class PlaybackChromeVisibilityModel: ObservableObject {
    @Published private(set) var isPlayerUIVisible = true

    private enum State {
        case shown
        case hidden
    }

    private static let idleNanoseconds: UInt64 = 3_000_000_000

    private var state: State = .shown
    private var isAppActive = NSApp?.isActive ?? true
    private var pointerInPlayerArea = false
    private var lastPointerLocation: CGPoint?
    private var idleTask: Task<Void, Never>?
    private var cursorHidden = false
    // After fullscreen entry or app refocus AppKit emits a synthetic pointer
    // event without real movement; suppress it until the pointer truly moves.
    private var suppressUntilRealMove = false
    private var focusObservers: [NSObjectProtocol] = []

    // MARK: - Lifecycle

    func enterVideoPage() {
        startObservingFocus()
        suppressUntilRealMove = false
        lastPointerLocation = nil
        pointerInPlayerArea = false
        isAppActive = NSApp?.isActive ?? true
        showShown()
    }

    func leaveVideoPage() {
        idleTask?.cancel()
        idleTask = nil
        stopObservingFocus()
        showCursor()
    }

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

    /// Entering playback fullscreen force-hides Player UI and the cursor once.
    /// Afterwards the normal rules apply inside fullscreen.
    func enteringFullscreen() {
        idleTask?.cancel()
        idleTask = nil
        state = .hidden
        isPlayerUIVisible = false
        hideCursor()
        suppressUntilRealMove = true
    }

    // MARK: - Inputs

    func pointerMoved(to location: CGPoint, isInPlayerArea inArea: Bool) {
        pointerInPlayerArea = inArea

        if suppressUntilRealMove {
            if let last = lastPointerLocation, !Self.approximatelyEqual(last, location) {
                suppressUntilRealMove = false
            } else {
                lastPointerLocation = location
                return
            }
        }

        // Mouse movement always shows the cursor.
        showCursor()
        lastPointerLocation = location

        guard inArea else {
            // (1) pointer moves out of the player area: hide UI only.
            transitionToHidden(hideCursor: false)
            return
        }

        guard isAppActive else {
            // Cursor is shown by the move, but Hidden -> Shown also needs focus.
            return
        }

        showShown()
        restartIdleTimer()
    }

    func pointerExited() {
        pointerInPlayerArea = false
        // (1) pointer left the player area: hide UI only, keep the cursor.
        showCursor()
        transitionToHidden(hideCursor: false)
    }

    private func appActiveChanged(_ active: Bool) {
        isAppActive = active
        if active {
            // Regaining focus alone must not show Player UI; require a real move.
            suppressUntilRealMove = true
        } else {
            // (3) the app loses focus: hide UI only, keep the cursor.
            showCursor()
            transitionToHidden(hideCursor: false)
        }
    }

    // MARK: - State helpers

    private func showShown() {
        idleTask?.cancel()
        state = .shown
        isPlayerUIVisible = true
        showCursor()
        restartIdleTimer()
    }

    private func transitionToHidden(hideCursor hidesCursor: Bool) {
        idleTask?.cancel()
        idleTask = nil
        state = .hidden
        isPlayerUIVisible = false
        if hidesCursor {
            hideCursor()
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
        // (2) pointer in the player area and no movement for 3s: hide UI + cursor.
        guard state == .shown, pointerInPlayerArea, isAppActive else {
            return
        }
        transitionToHidden(hideCursor: true)
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

    private static func approximatelyEqual(_ lhs: CGPoint, _ rhs: CGPoint) -> Bool {
        abs(lhs.x - rhs.x) < 0.5 && abs(lhs.y - rhs.y) < 0.5
    }
}
