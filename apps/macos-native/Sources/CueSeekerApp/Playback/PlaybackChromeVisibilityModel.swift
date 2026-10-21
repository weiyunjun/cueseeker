import AppKit
import SwiftUI

/// The playback page's only owner of Player UI visibility and of the pointer.
///
/// Authoritative rules: `docs/human/requirements/20260912-UI-Player UI And
/// Pointer Visibility Rules.md`, mirrored in
/// `docs/product/12_liquid_glass_ux_mapping.md` §10.4.
///
/// Player UI is the top bar, the bottom control bar and their menus. A hidden
/// pointer always means a hidden Player UI. The pointer is hidden only while
/// this model governs it: the playback window has focus, no same-window layer
/// is open, and the pointer is inside the player area. Leaving governance
/// shows the pointer; the Player UI comes back only with pointer movement
/// inside the governed area.
///
/// The idle countdown is a condition, not an event. It runs while the window
/// has focus, the pointer is inside the player area and on no clickable
/// control, no layer is open, no drag of the progress bar or the volume
/// slider is in progress, and there is still something to hide. Any change re-evaluates it; pointer movement restarts
/// it. Clicks, the wheel and the keyboard are not movement.
@MainActor
final class PlaybackChromeVisibilityModel: ObservableObject {
    @Published private(set) var isPlayerUIVisible = true
    @Published private(set) var isPointerVisible = true

    /// AppKit answers these in the App; tests answer them directly.
    var hasWindowFocus: (NSWindow) -> Bool = { NSApp.isActive && $0.isKeyWindow }
    var pointerScreenLocation: () -> NSPoint = { NSEvent.mouseLocation }

    private static let windowControlButtons: [NSWindow.ButtonType] = [
        .closeButton, .miniaturizeButton, .zoomButton
    ]

    private var idleTask: Task<Void, Never>?
    private var cursorHiddenByPlayer = false
    private var focusObservers: [NSObjectProtocol] = []
    private var pointerDragEventMonitor: Any?
    private weak var playerAreaView: NSView?
    private weak var playerWindow: NSWindow?
    /// A Playback Overlay, Command Panel or in-window dialog is open above the
    /// page: the pointer is shown and the Player UI's state and countdown are
    /// frozen until it closes.
    private var isLayerOpen = false
    private var isDragging = false
    /// The clickable controls of the Player UI, in the player area's
    /// top-left-origin coordinates. The window controls are asked from AppKit.
    private var interactiveFrames: [CGRect] = []

    var isIdleCountdownRunning: Bool {
        idleTask != nil
    }

    // MARK: - Lifecycle

    func enterVideoPage() {
        startObservingFocus()
        startObservingPointerDraggedEvents()
        setPlayerUIVisible(true)
        setPointerVisible(true)
        reevaluate()
    }

    func leaveVideoPage() {
        cancelIdleCountdown()
        stopObservingFocus()
        stopObservingPointerDraggedEvents()
        releaseCursor()
        playerAreaView = nil
        playerWindow = nil
    }

    /// Entering fullscreen hides both at once.
    func enteringFullscreen() {
        cancelIdleCountdown()
        setPlayerUIVisible(false)
        setPointerVisible(false)
        applyCursorOwnership()
    }

    // MARK: - Inputs

    func updatePlayerAreaView(_ view: NSView) {
        playerAreaView = view
        if let window = view.window {
            playerWindow = window
        }
        reevaluate()
    }

    /// Enter and exit only refresh the live picture: layout and fullscreen
    /// changes emit them without physical pointer motion, and the pointer's
    /// real position is read when deciding.
    func pointerEnteredPlayerArea(view: NSView) {
        updatePlayerAreaView(view)
    }

    func pointerExitedPlayerArea(view: NSView) {
        updatePlayerAreaView(view)
    }

    func pointerMovedInPlayerArea(view: NSView) {
        updatePlayerAreaView(view)
        pointerMoved()
    }

    /// Same-window layers: Playback Overlay, Command Panel and dialogs.
    /// Opening a layer freezes the Player UI state and cancels the idle
    /// countdown without actively unhiding a hidden pointer; moving the
    /// pointer while the layer is open unhides it.
    func setLayerOpen(_ isOpen: Bool) {
        guard isLayerOpen != isOpen else {
            return
        }
        isLayerOpen = isOpen
        if isOpen {
            cancelIdleCountdown()
            applyCursorOwnership()
        } else {
            reevaluate()
        }
    }

    /// The progress bar or the volume slider is being dragged.
    func setDragging(_ isDragging: Bool) {
        guard self.isDragging != isDragging else {
            return
        }
        self.isDragging = isDragging
        reevaluate()
    }

    func setInteractiveFrames(_ frames: [CGRect]) {
        interactiveFrames = frames
        reevaluate()
    }

    /// A game controller has no pointer, so its input hides both at once. The
    /// keyboard does not.
    func pointerHideRequested() {
        guard isGoverned else {
            return
        }
        hideBoth()
    }

    /// The window's or the App's focus changed.
    func focusChanged() {
        reevaluate()
    }

    // MARK: - Decision

    private func pointerMoved() {
        guard hasFocus, isPointerInPlayerArea else {
            return
        }
        setPointerVisible(true)
        applyCursorOwnership()
        guard !isLayerOpen else {
            return
        }
        setPlayerUIVisible(true)
        cancelIdleCountdown()
        reevaluate()
    }

    private func reevaluate() {
        guard playerWindow != nil else {
            return
        }
        if !hasFocus || !isPointerInPlayerArea {
            // Outside the window or without focus the Player UI is hidden and
            // the pointer is shown.
            cancelIdleCountdown()
            if !isLayerOpen {
                setPlayerUIVisible(false)
            }
            setPointerVisible(true)
            applyCursorOwnership()
            return
        }
        guard !isLayerOpen else {
            applyCursorOwnership()
            return
        }
        applyCursorOwnership()
        if isIdleCountdownDue {
            startIdleCountdownIfNeeded()
        } else {
            cancelIdleCountdown()
        }
    }

    private var hasFocus: Bool {
        guard let playerWindow else {
            return false
        }
        return hasWindowFocus(playerWindow)
    }

    private var isGoverned: Bool {
        !isLayerOpen && hasFocus && isPointerInPlayerArea
    }

    private var isIdleCountdownDue: Bool {
        isGoverned
            && !isDragging
            && !isPointerOnInteractiveControl
            && (isPlayerUIVisible || isPointerVisible)
    }

    private var pointerLocationInPlayerArea: CGPoint? {
        guard let view = playerAreaView, let window = playerWindow else {
            return nil
        }
        let windowPoint = window.convertPoint(fromScreen: pointerScreenLocation())
        return view.convert(windowPoint, from: nil)
    }

    private var isPointerInPlayerArea: Bool {
        guard let view = playerAreaView, let point = pointerLocationInPlayerArea else {
            return false
        }
        return view.bounds.contains(point)
    }

    /// Clickable controls only: the shown Player UI's controls and the window
    /// controls. A hidden control is not clickable.
    private var isPointerOnInteractiveControl: Bool {
        if isPlayerUIVisible,
           let point = pointerLocationInPlayerArea,
           interactiveFrames.contains(where: { $0.contains(point) }) {
            return true
        }
        guard let window = playerWindow else {
            return false
        }
        let screenPoint = pointerScreenLocation()
        return Self.windowControlButtons.contains { type in
            guard let button = window.standardWindowButton(type),
                  !button.isHiddenOrHasHiddenAncestor,
                  let buttonWindow = button.window else {
                return false
            }
            let frame = buttonWindow.convertToScreen(button.convert(button.bounds, to: nil))
            return frame.contains(screenPoint)
        }
    }

    // MARK: - Countdown

    private func startIdleCountdownIfNeeded() {
        guard idleTask == nil else {
            return
        }
        idleTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(PlaybackChromeMetrics.idleHideDuration))
            guard !Task.isCancelled else {
                return
            }
            self?.idleElapsed()
        }
    }

    private func cancelIdleCountdown() {
        idleTask?.cancel()
        idleTask = nil
    }

    /// The countdown's end. Internal so tests need not wait for it.
    func idleElapsed() {
        cancelIdleCountdown()
        guard isIdleCountdownDue else {
            return
        }
        hideBoth()
    }

    private func hideBoth() {
        cancelIdleCountdown()
        setPlayerUIVisible(false)
        setPointerVisible(false)
        applyCursorOwnership()
    }

    // MARK: - State

    private func setPlayerUIVisible(_ isVisible: Bool) {
        guard isPlayerUIVisible != isVisible else {
            return
        }
        isPlayerUIVisible = isVisible
    }

    private func setPointerVisible(_ isVisible: Bool) {
        guard isPointerVisible != isVisible else {
            return
        }
        isPointerVisible = isVisible
    }

    // MARK: - Cursor ownership

    private func applyCursorOwnership() {
        if !isPointerVisible, hasFocus, isPointerInPlayerArea {
            hideCursor()
        } else {
            releaseCursor()
        }
    }

    private func releaseCursor() {
        guard cursorHiddenByPlayer else {
            return
        }
        cursorHiddenByPlayer = false
        AppCursorVisibility.setHidden(false)
    }

    private func hideCursor() {
        guard !cursorHiddenByPlayer else {
            return
        }
        cursorHiddenByPlayer = true
        AppCursorVisibility.setHidden(true)
    }

    // MARK: - Observers

    private func startObservingFocus() {
        guard focusObservers.isEmpty else {
            return
        }
        let center = NotificationCenter.default
        // Settings and other non-player windows become key windows without the
        // App resigning active, so focus listens to both window and
        // application changes.
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

    /// Drag events go to the original press target instead of the tracking
    /// overlay. They are pointer movement all the same.
    private func startObservingPointerDraggedEvents() {
        guard pointerDragEventMonitor == nil else {
            return
        }
        pointerDragEventMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.leftMouseDragged, .rightMouseDragged, .otherMouseDragged]
        ) { [weak self] event in
            MainActor.assumeIsolated {
                self?.pointerMoved()
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
