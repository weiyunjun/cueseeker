import AppKit
import SwiftUI

/// Single explicit Player-UI / cursor visibility state machine (v4).
///
/// Authoritative spec: `docs/product/12_liquid_glass_ux_mapping.md` §10.4 and
/// the proposal's "Player-UI / Cursor Visibility State Machine (v4)". This is
/// the only owner of Player-UI visibility and the playback cursor.
///
/// v4 separates Player UI state from cursor state. The current player decides
/// cursor visibility only while the cursor is governed by that player: the
/// player area exists, the live cursor position is inside it, and player focus
/// still belongs to the playback page.
@MainActor
final class PlaybackChromeVisibilityModel: ObservableObject {
    @Published private(set) var isPlayerUIVisible = true

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
    private weak var playerAreaView: NSView?
    private weak var playerWindow: NSWindow?

    // MARK: - Lifecycle

    func enterVideoPage() {
        startObservingFocus()
        setPlayerUIState(.visible)
        cursorState = .visible
        applyCursorOwnership()
        restartIdleTimer()
    }

    func leaveVideoPage() {
        idleTask?.cancel()
        idleTask = nil
        stopObservingFocus()
        releaseCursorOwnership()
        playerAreaView = nil
        playerWindow = nil
    }

    /// Rule 9: entering playback fullscreen forces Player UI and cursor hidden.
    func enteringFullscreen() {
        idleTask?.cancel()
        idleTask = nil
        setPlayerUIState(.hidden)
        cursorState = .hidden
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
        guard isCursorGovernedByCurrentPlayer else {
            applyCursorOwnership()
            return
        }

        cursorState = .visible
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
        cursorState = .hidden
        applyCursorOwnership()
    }

    private func setPlayerUIState(_ state: VisibilityState) {
        playerUIState = state
        isPlayerUIVisible = state == .visible
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
    }

    private func hideCursor() {
        guard !cursorHiddenByPlayer else {
            return
        }
        cursorHiddenByPlayer = true
        NSCursor.hide()
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
}
