import AppKit
import SwiftUI
import CueSeekerPlayback

@MainActor
enum PlaybackFullscreenState: Equatable {
    case windowed
    case enteringSystemFullscreen
    case activeFullscreen
    case exitingSystemFullscreen

    var isTransitioning: Bool {
        switch self {
        case .enteringSystemFullscreen, .exitingSystemFullscreen:
            return true
        case .windowed, .activeFullscreen:
            return false
        }
    }
}

@MainActor
final class PlaybackFullscreenManager: ObservableObject {
    @Published private(set) var state: PlaybackFullscreenState = .windowed
    @Published private(set) var isVideoOnlyPresentationVisible = false
    @Published private(set) var isChromeVisible = false

    private weak var fullscreenWindow: NSWindow?
    private var chromeHideTask: Task<Void, Never>?
    private var transitionCompletion: (() -> Void)?
    private var didEnterSystemFullscreenForPlayback = false
    private var isSuppressingInitialPointerMove = false
    private var initialPointerLocation: CGPoint?
    private let initialPointerMovementThreshold: CGFloat = 0.5

    var isFullscreen: Bool {
        isVideoOnlyPresentationVisible
    }

    var isTransitioning: Bool {
        state.isTransitioning
    }

    @discardableResult
    func toggleFullscreen(
        player: PlaybackPlayer,
        onTransitionCompleted: (() -> Void)? = nil
    ) -> Bool {
        switch state {
        case .windowed:
            return enterFullscreen(
                player: player,
                onTransitionCompleted: onTransitionCompleted
            )
        case .activeFullscreen:
            return exitFullscreen(
                animated: true,
                onTransitionCompleted: onTransitionCompleted
            )
        case .enteringSystemFullscreen, .exitingSystemFullscreen:
            return false
        }
    }

    @discardableResult
    func enterFullscreen(
        player: PlaybackPlayer,
        onTransitionCompleted: (() -> Void)? = nil
    ) -> Bool {
        guard state == .windowed, fullscreenWindow == nil else {
            return false
        }

        guard let window = player.renderView.window
            ?? NSApplication.shared.keyWindow
            ?? NSApplication.shared.mainWindow
        else {
            return false
        }

        fullscreenWindow = window
        transitionCompletion = onTransitionCompleted
        didEnterSystemFullscreenForPlayback = !window.styleMask.contains(.fullScreen)
        state = didEnterSystemFullscreenForPlayback
            ? .enteringSystemFullscreen
            : .activeFullscreen

        window.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)

        guard didEnterSystemFullscreenForPlayback else {
            activatePlaybackPresentation()
            completeFullscreenTransition()
            return true
        }

        window.toggleFullScreen(nil)
        return true
    }

    @discardableResult
    func exitFullscreen(
        animated: Bool = false,
        onTransitionCompleted: (() -> Void)? = nil
    ) -> Bool {
        guard state != .windowed || fullscreenWindow != nil else {
            return false
        }

        guard !state.isTransitioning || !animated else {
            return false
        }

        let window = fullscreenWindow

        chromeHideTask?.cancel()
        chromeHideTask = nil

        if didEnterSystemFullscreenForPlayback,
           let window,
           window.styleMask.contains(.fullScreen) {
            state = .exitingSystemFullscreen
            transitionCompletion = onTransitionCompleted
            window.toggleFullScreen(nil)
            return true
        }

        finishExitFullscreen()
        completeFullscreenTransition()
        onTransitionCompleted?()
        return true
    }

    private func finishExitFullscreen() {
        guard state != .windowed || fullscreenWindow != nil else {
            return
        }

        chromeHideTask?.cancel()
        chromeHideTask = nil
        endInitialPointerSuppression()
        PlaybackCursorVisibility.show(for: .playbackFullscreen)

        isVideoOnlyPresentationVisible = false
        fullscreenWindow = nil
        didEnterSystemFullscreenForPlayback = false
        state = .windowed
    }

    func windowWillEnterFullScreen(_ notification: Notification) {
        guard notification.object as? NSWindow === fullscreenWindow else { return }
        guard state == .enteringSystemFullscreen else { return }

        activatePlaybackPresentation()
    }

    func windowDidEnterFullScreen(_ notification: Notification) {
        guard notification.object as? NSWindow === fullscreenWindow else { return }
        guard state == .enteringSystemFullscreen else { return }

        state = .activeFullscreen
        completeFullscreenTransition()
    }

    func windowWillExitFullScreen(_ notification: Notification) {
        guard notification.object as? NSWindow === fullscreenWindow else { return }
        guard didEnterSystemFullscreenForPlayback || state == .exitingSystemFullscreen else { return }
        guard state == .activeFullscreen || state == .exitingSystemFullscreen else { return }

        state = .exitingSystemFullscreen
        chromeHideTask?.cancel()
        chromeHideTask = nil
        PlaybackCursorVisibility.show(for: .playbackFullscreen)
    }

    func windowDidExitFullScreen(_ notification: Notification) {
        guard notification.object as? NSWindow === fullscreenWindow else { return }
        guard didEnterSystemFullscreenForPlayback || state == .exitingSystemFullscreen else { return }

        finishExitFullscreen()
        completeFullscreenTransition()
    }

    func windowDidFailToEnterFullScreen(_ window: NSWindow) {
        guard window === fullscreenWindow else {
            return
        }
        guard state == .enteringSystemFullscreen else {
            return
        }

        finishExitFullscreen()
        completeFullscreenTransition()
    }

    func windowDidFailToExitFullScreen(_ window: NSWindow) {
        guard window === fullscreenWindow else {
            return
        }
        guard state == .exitingSystemFullscreen else {
            return
        }

        state = .activeFullscreen
        completeFullscreenTransition()
    }

    func windowWillClose(_ notification: Notification) {
        guard notification.object as? NSWindow === fullscreenWindow else { return }

        finishExitFullscreen()
        completeFullscreenTransition()
    }

    func windowDidResize(_ notification: Notification) {
        guard notification.object as? NSWindow === fullscreenWindow else { return }
    }

    private func completeFullscreenTransition() {
        let completion = transitionCompletion
        transitionCompletion = nil
        completion?()
    }

    private func activatePlaybackPresentation() {
        isVideoOnlyPresentationVisible = true
        beginInitialPointerSuppression()
        hidePlayerUI(hideCursor: true)
    }

    func registerPointerMove(
        location: CGPoint,
        isInPlayerArea: Bool,
        isInPlayerUI: Bool,
        displayCheckZone: PlaybackDisplayCheckZone
    ) {
        guard isFullscreen else {
            return
        }

        guard isActualPointerMove(location) else {
            return
        }

        PlaybackCursorVisibility.show(for: .playbackFullscreen)

        guard isInPlayerArea else {
            hidePlayerUI(hideCursor: false)
            return
        }

        showPlayerUI()
        chromeHideTask?.cancel()
        guard !isInPlayerUI else {
            return
        }

        schedulePlayerUIHide(location: location, zone: displayCheckZone)
    }

    func registerPointerExit() {
        guard isFullscreen else {
            return
        }

        chromeHideTask?.cancel()
        chromeHideTask = nil
        hidePlayerUI(hideCursor: false)
    }

    private func showPlayerUI() {
        isChromeVisible = true
        PlaybackCursorVisibility.show(for: .playbackFullscreen)
    }

    private func hidePlayerUI(hideCursor: Bool) {
        chromeHideTask?.cancel()
        chromeHideTask = nil
        isChromeVisible = false
        if hideCursor {
            PlaybackCursorVisibility.hide(for: .playbackFullscreen)
        } else {
            PlaybackCursorVisibility.show(for: .playbackFullscreen)
        }
    }

    private func schedulePlayerUIHide(location: CGPoint, zone: PlaybackDisplayCheckZone) {
        guard zone.contains(location) else {
            return
        }
        chromeHideTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard !Task.isCancelled else {
                return
            }

            await MainActor.run {
                guard zone.contains(location) else {
                    return
                }
                self?.hidePlayerUI(hideCursor: true)
            }
        }
    }

    private func beginInitialPointerSuppression() {
        isSuppressingInitialPointerMove = true
        initialPointerLocation = nil
    }

    private func endInitialPointerSuppression() {
        isSuppressingInitialPointerMove = false
        initialPointerLocation = nil
    }

    private func isActualPointerMove(_ location: CGPoint) -> Bool {
        guard isSuppressingInitialPointerMove else {
            return true
        }

        guard let initialPointerLocation else {
            self.initialPointerLocation = location
            return false
        }

        let deltaX = location.x - initialPointerLocation.x
        let deltaY = location.y - initialPointerLocation.y
        if sqrt(deltaX * deltaX + deltaY * deltaY) < initialPointerMovementThreshold {
            return false
        }

        endInitialPointerSuppression()
        return true
    }
}
