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

    private weak var fullscreenWindow: NSWindow?
    private weak var fullscreenPlayer: PlaybackPlayer?
    private var transitionCompletion: (() -> Void)?
    private var didEnterSystemFullscreenForPlayback = false

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
        fullscreenPlayer = player
        transitionCompletion = onTransitionCompleted
        didEnterSystemFullscreenForPlayback = !window.styleMask.contains(.fullScreen)
        state = didEnterSystemFullscreenForPlayback
            ? .enteringSystemFullscreen
            : .activeFullscreen

        window.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)

        guard didEnterSystemFullscreenForPlayback else {
            activatePlaybackPresentation()
            synchronizeFullscreenRenderLayout()
            completeFullscreenTransition()
            return true
        }

        synchronizeFullscreenRenderLayout()
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

        if didEnterSystemFullscreenForPlayback,
           let window,
           window.styleMask.contains(.fullScreen) {
            state = .exitingSystemFullscreen
            transitionCompletion = onTransitionCompleted
            synchronizeFullscreenRenderLayout()
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

        isVideoOnlyPresentationVisible = false
        fullscreenWindow = nil
        fullscreenPlayer = nil
        didEnterSystemFullscreenForPlayback = false
        state = .windowed
    }

    func windowWillEnterFullScreen(_ notification: Notification) {
        guard notification.object as? NSWindow === fullscreenWindow else { return }
        guard state == .enteringSystemFullscreen else { return }

        activatePlaybackPresentation()
        synchronizeFullscreenRenderLayout()
    }

    func windowDidEnterFullScreen(_ notification: Notification) {
        guard notification.object as? NSWindow === fullscreenWindow else { return }
        guard state == .enteringSystemFullscreen else { return }

        state = .activeFullscreen
        synchronizeFullscreenRenderLayout()
        completeFullscreenTransition()
    }

    func windowWillExitFullScreen(_ notification: Notification) {
        guard notification.object as? NSWindow === fullscreenWindow else { return }
        guard didEnterSystemFullscreenForPlayback || state == .exitingSystemFullscreen else { return }
        guard state == .activeFullscreen || state == .exitingSystemFullscreen else { return }

        state = .exitingSystemFullscreen
        synchronizeFullscreenRenderLayout()
    }

    func windowDidExitFullScreen(_ notification: Notification) {
        guard notification.object as? NSWindow === fullscreenWindow else { return }
        guard didEnterSystemFullscreenForPlayback || state == .exitingSystemFullscreen else { return }

        synchronizeFullscreenRenderLayout()
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

        synchronizeFullscreenRenderLayout()
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
        synchronizeFullscreenRenderLayout()
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
    }

    private func synchronizeFullscreenRenderLayout() {
        fullscreenPlayer?.synchronizeRenderLayoutForFullscreenTransition()
    }

}
