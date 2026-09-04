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
                fromUser: true,
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

    /// A system fullscreen the manager did not start — the zoom button's
    /// tiling menu, or a window that was fullscreen before the video opened.
    /// Fullscreen means the window's fullscreen, whoever entered it, so the
    /// page adopts it. `entering`: the transition has just begun and the
    /// delegate's callbacks finish it like the manager's own; leaving the
    /// page later leaves fullscreen too. Not entering: the window is already
    /// fullscreen, the presentation starts now, and leaving the page keeps
    /// the window as the Workbench had it.
    @discardableResult
    func adoptSystemFullscreen(
        window: NSWindow,
        entering: Bool,
        onTransitionCompleted: (() -> Void)? = nil
    ) -> Bool {
        guard state == .windowed, fullscreenWindow == nil else {
            return false
        }

        fullscreenWindow = window
        didEnterSystemFullscreenForPlayback = entering
        if entering {
            transitionCompletion = onTransitionCompleted
            state = .enteringSystemFullscreen
        } else {
            state = .activeFullscreen
            activatePlaybackPresentation()
            onTransitionCompleted?()
        }
        return true
    }

    /// `fromUser`: F, Escape, the player's button or the zoom button. The
    /// user leaves the window's fullscreen whoever entered it. Leaving the
    /// page instead undoes only a fullscreen that playback entered.
    @discardableResult
    func exitFullscreen(
        fromUser: Bool = false,
        onTransitionCompleted: (() -> Void)? = nil
    ) -> Bool {
        guard state != .windowed || fullscreenWindow != nil else {
            return false
        }

        guard !state.isTransitioning || !fromUser else {
            return false
        }

        let window = fullscreenWindow

        if let window,
           window.styleMask.contains(.fullScreen),
           fromUser || didEnterSystemFullscreenForPlayback {
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
        guard state == .activeFullscreen || state == .exitingSystemFullscreen else { return }

        state = .exitingSystemFullscreen
    }

    func windowDidExitFullScreen(_ notification: Notification) {
        guard notification.object as? NSWindow === fullscreenWindow else { return }
        guard state == .exitingSystemFullscreen else { return }

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
    }

}
