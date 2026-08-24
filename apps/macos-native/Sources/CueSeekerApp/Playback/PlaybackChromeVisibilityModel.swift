import AppKit
import SwiftUI

/// Process-wide record of whether CueSeeker currently hides the system cursor.
///
/// `PlaybackChromeVisibilityModel` is the only writer, because it owns the only
/// `NSCursor.hide()` / `NSCursor.unhide()` pair in the App. Debug E2E `inspect`
/// reads it: a screenshot never contains the cursor, so pointer-visibility
/// rules would otherwise have no observable evidence.
@MainActor
enum AppCursorVisibility {
    private(set) static var isCursorHidden = false

    static func noteCursorHidden(_ isHidden: Bool) {
        isCursorHidden = isHidden
    }
}

/// Single explicit Player-UI / cursor visibility state machine (v4).
///
/// Authoritative specs: `docs/product/12_liquid_glass_ux_mapping.md` §10.4 and
/// the Playback Pointer Visibility delta in the Shared Workbench Playback
/// Feature Surfaces requirement. This is the only owner of Player-UI visibility
/// and the playback cursor.
///
/// v4 separates Player UI state from cursor state. The current player decides
/// cursor visibility only while the cursor is governed by that player: the
/// player area exists, the live cursor position is inside it, and player focus
/// still belongs to the playback page.
@MainActor
final class PlaybackChromeVisibilityModel: ObservableObject {
    @Published private(set) var isPlayerUIVisible = true
    @Published private(set) var isPointerVisible = false

    private enum VisibilityState {
        case visible
        case hidden
    }

    private static let idleNanoseconds: UInt64 = 3_000_000_000

    private var playerUIState: VisibilityState = .visible
    private var cursorState: VisibilityState = .visible
    private var idleTask: Task<Void, Never>?
    private var cursorHiddenByPlayer = false
    private var focusObservers: [NSObjectProtocol] = []
    private var pointerDragEventMonitor: Any?
    private weak var playerAreaView: NSView?
    private weak var playerWindow: NSWindow?

    // MARK: - Lifecycle

    func enterVideoPage() {
        startObservingFocus()
        startObservingPointerDraggedEvents()
        setPlayerUIState(.visible)
        setCursorState(.hidden)
        applyCursorOwnership()
        restartIdleTimer()
    }

    func leaveVideoPage() {
        idleTask?.cancel()
        idleTask = nil
        stopObservingFocus()
        stopObservingPointerDraggedEvents()
        releaseCursorOwnership()
        playerAreaView = nil
        playerWindow = nil
    }

    /// Rule 9: entering playback fullscreen forces Player UI and cursor hidden.
    func enteringFullscreen() {
        idleTask?.cancel()
        idleTask = nil
        setPlayerUIState(.hidden)
        setCursorState(.hidden)
        applyCursorOwnership()
    }

    // MARK: - Pointer (driven by the NSTrackingArea overlay)

    func updatePlayerAreaView(_ view: NSView) {
        playerAreaView = view
        guard let window = view.window else {
            return
        }
        playerWindow = window
        handleFocusOrGovernanceChanged()
    }

    /// The pointer entered the player area. This updates governance only; it is
    /// not treated as real movement because layout/fullscreen changes can emit
    /// enter events without physical pointer motion.
    func pointerEnteredPlayerArea(view: NSView) {
        updatePlayerAreaView(view)
    }

    /// Rules 7, 11, and 13: only governed real mouse movement reveals Player UI
    /// and/or the cursor.
    func pointerMovedInPlayerArea(view: NSView) {
        updatePlayerAreaView(view)
        handlePhysicalPointerMovement()
    }

    /// Drag events can be delivered to the original press target instead of the
    /// tracking overlay. They still represent physical pointer movement.
    private func pointerDragged() {
        handlePhysicalPointerMovement()
    }

    private func handlePhysicalPointerMovement() {
        setCursorState(.visible)
        guard isCursorGovernedByCurrentPlayer else {
            if playerHasFocus, !isCursorInPlayerArea(), playerUIState == .visible {
                transitionPlayerUIToHidden()
            }
            applyCursorOwnership()
            return
        }

        if playerUIState == .hidden {
            setPlayerUIState(.visible)
        }
        applyCursorOwnership()
        restartIdleTimer()
    }

    /// Rules 10.1 and 14: leaving the player area hides Player UI when visible
    /// and stops the current player from deciding cursor visibility.
    func pointerExitedPlayerArea(view: NSView) {
        updatePlayerAreaView(view)
        if playerUIState == .visible {
            transitionPlayerUIToHidden()
        }
        applyCursorOwnership()
    }

    func keyboardInputReceived() {
        setCursorState(.hidden)
        applyCursorOwnership()
    }

    // MARK: - Focus and cursor governance

    private var playerHasFocus: Bool {
        guard NSApp.isActive else {
            return false
        }
        guard let window = playerWindow ?? playerAreaView?.window else {
            return false
        }
        return window.isKeyWindow
    }

    private var isCursorGovernedByCurrentPlayer: Bool {
        playerHasFocus && isCursorInPlayerArea()
    }

    private func focusChanged() {
        handleFocusOrGovernanceChanged()
    }

    private func handleFocusOrGovernanceChanged() {
        if !playerHasFocus, playerUIState == .visible {
            // Rule 10.3: losing player focus hides Player UI. Cursor state is
            // intentionally left to the cursor rules.
            transitionPlayerUIToHidden()
        }
        applyCursorOwnership()
    }

    // MARK: - State helpers

    private func transitionPlayerUIToHidden() {
        idleTask?.cancel()
        idleTask = nil
        setPlayerUIState(.hidden)
    }

    private func restartIdleTimer() {
        idleTask?.cancel()
        guard playerUIState == .visible else {
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
        // Rules 10.2 and 12.2: governed 3s inactivity hides both states.
        guard playerUIState == .visible, isCursorGovernedByCurrentPlayer else {
            return
        }
        transitionPlayerUIToHidden()
        setCursorState(.hidden)
        applyCursorOwnership()
    }

    private func setPlayerUIState(_ state: VisibilityState) {
        guard playerUIState != state else {
            return
        }
        playerUIState = state
        isPlayerUIVisible = state == .visible
    }

    private func setCursorState(_ state: VisibilityState) {
        guard cursorState != state else {
            return
        }
        cursorState = state
        isPointerVisible = state == .visible
    }

    // MARK: - Cursor ownership

    private func isCursorInPlayerArea() -> Bool {
        guard let view = playerAreaView,
              let window = playerWindow ?? view.window else {
            return false
        }
        let windowPoint = window.convertPoint(fromScreen: NSEvent.mouseLocation)
        let viewPoint = view.convert(windowPoint, from: nil)
        return view.bounds.contains(viewPoint)
    }

    private func applyCursorOwnership() {
        if cursorState == .hidden, isCursorGovernedByCurrentPlayer {
            hideCursor()
        } else {
            releaseCursorOwnership()
        }
    }

    private func releaseCursorOwnership() {
        guard cursorHiddenByPlayer else {
            return
        }
        cursorHiddenByPlayer = false
        NSCursor.unhide()
        AppCursorVisibility.noteCursorHidden(false)
    }

    private func hideCursor() {
        guard !cursorHiddenByPlayer else {
            return
        }
        cursorHiddenByPlayer = true
        NSCursor.hide()
        AppCursorVisibility.noteCursorHidden(true)
    }

    // MARK: - Focus observers

    private func startObservingFocus() {
        guard focusObservers.isEmpty else {
            return
        }
        let center = NotificationCenter.default
        // Settings and other non-player windows become key windows without the
        // App resigning active, so player focus must listen to both window and
        // application focus changes.
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

    private func startObservingPointerDraggedEvents() {
        guard pointerDragEventMonitor == nil else {
            return
        }
        pointerDragEventMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.leftMouseDragged, .rightMouseDragged, .otherMouseDragged]
        ) { [weak self] event in
            MainActor.assumeIsolated {
                self?.pointerDragged()
            }
            return event
        }
    }

    private func stopObservingPointerDraggedEvents() {
        guard let pointerDragEventMonitor else {
            return
        }
        NSEvent.removeMonitor(pointerDragEventMonitor)
        self.pointerDragEventMonitor = nil
    }
}
