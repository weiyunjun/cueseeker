import AppKit
import SwiftUI
import CueSeekerPlayback

@MainActor
final class PlaybackFullscreenManager: ObservableObject {
    @Published private(set) var isFullscreen = false
    @Published private(set) var isChromeVisible = false

    private var fullscreenWindow: PlaybackFullscreenWindow?
    private var fullscreenRootView: PlaybackFullscreenRootView?
    private var previousPresentationOptions: NSApplication.PresentationOptions?
    private weak var previousKeyWindow: NSWindow?
    private var chromeHideTask: Task<Void, Never>?
    private var onExitRequest: (() -> Void)?
    private var isCursorHidden = false
    private var isSuppressingInitialHover = false
    private var isSuspendedForAppDeactivation = false
    private var initialHoverLocation: CGPoint?
    private let initialHoverMovementThreshold: CGFloat = 6

    func toggleFullscreen(
        player: PlaybackPlayer,
        viewModel: PlaybackViewModel,
        onCopySubtitle: @escaping () -> Void = {},
        onExitRequest: (() -> Void)? = nil
    ) {
        if isFullscreen {
            exitFullscreen()
        } else {
            enterFullscreen(
                player: player,
                viewModel: viewModel,
                onCopySubtitle: onCopySubtitle,
                onExitRequest: onExitRequest
            )
        }
    }

    func enterFullscreen(
        player: PlaybackPlayer,
        viewModel: PlaybackViewModel,
        onCopySubtitle: @escaping () -> Void = {},
        onExitRequest: (() -> Void)? = nil
    ) {
        guard !isFullscreen, fullscreenWindow == nil else {
            return
        }

        let keyWindow = NSApplication.shared.keyWindow
        previousKeyWindow = keyWindow

        let screen = keyWindow?.screen
            ?? player.renderView.window?.screen
            ?? NSScreen.main

        guard let screen else {
            return
        }

        previousPresentationOptions = NSApplication.shared.presentationOptions

        let window = PlaybackFullscreenWindow(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false,
            screen: screen
        )
        window.backgroundColor = .black
        window.collectionBehavior = [.canJoinAllSpaces, .ignoresCycle]
        window.hasShadow = false
        window.isOpaque = true
        window.acceptsMouseMovedEvents = true
        window.isReleasedWhenClosed = false
        // Keep Theater Mode below system overlays such as the Cmd-Tab app switcher.
        window.level = .normal
        window.onEscape = { [weak self] in
            Task { @MainActor in
                self?.requestExitFullscreen()
            }
        }

        let overlayView = NSHostingView(
            rootView: PlaybackFullscreenOverlayView(
                fullscreenManager: self,
                viewModel: viewModel,
                onCopySubtitle: onCopySubtitle,
                onExit: { [weak self] in
                    Task { @MainActor in
                        self?.requestExitFullscreen()
                    }
                }
            )
        )
        overlayView.wantsLayer = true
        overlayView.layer?.backgroundColor = NSColor.clear.cgColor

        let rootView = PlaybackFullscreenRootView(
            renderView: player.renderView,
            overlayView: overlayView
        )

        fullscreenWindow = window
        fullscreenRootView = rootView
        self.onExitRequest = onExitRequest
        isFullscreen = true
        beginInitialHoverSuppression()
        hideChromeImmediately()

        window.contentView = rootView
        NSApplication.shared.presentationOptions = [.autoHideMenuBar, .autoHideDock]
        window.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)

        DispatchQueue.main.async { [weak self] in
            self?.hideChromeImmediately()
        }
    }

    func suspendFullscreenForAppDeactivation() {
        guard isFullscreen, !isSuspendedForAppDeactivation else {
            return
        }

        isSuspendedForAppDeactivation = true
        chromeHideTask?.cancel()
        chromeHideTask = nil
        isChromeVisible = false
        endInitialHoverSuppression()
        showCursorIfNeeded()
        fullscreenWindow?.orderOut(nil)

        if let previousPresentationOptions {
            NSApplication.shared.presentationOptions = previousPresentationOptions
        }
    }

    func restoreFullscreenAfterAppActivation() {
        guard isFullscreen, isSuspendedForAppDeactivation, let fullscreenWindow else {
            return
        }

        isSuspendedForAppDeactivation = false
        beginInitialHoverSuppression()
        hideChromeImmediately()
        NSApplication.shared.presentationOptions = [.autoHideMenuBar, .autoHideDock]
        fullscreenWindow.makeKeyAndOrderFront(nil)

        DispatchQueue.main.async { [weak self] in
            self?.hideChromeImmediately()
        }
    }

    func exitFullscreen() {
        guard isFullscreen || fullscreenWindow != nil else {
            return
        }

        let window = fullscreenWindow
        let rootView = fullscreenRootView

        fullscreenWindow = nil
        fullscreenRootView = nil
        onExitRequest = nil
        chromeHideTask?.cancel()
        chromeHideTask = nil
        isChromeVisible = false
        isSuspendedForAppDeactivation = false
        endInitialHoverSuppression()
        showCursorIfNeeded()

        rootView?.detachRenderView()
        window?.contentView = nil
        window?.orderOut(nil)
        window?.close()

        if let previousPresentationOptions {
            NSApplication.shared.presentationOptions = previousPresentationOptions
        }
        previousPresentationOptions = nil
        previousKeyWindow?.makeKeyAndOrderFront(nil)
        previousKeyWindow = nil
        isFullscreen = false
    }

    private func requestExitFullscreen() {
        if let onExitRequest {
            onExitRequest()
        } else {
            exitFullscreen()
        }
    }

    func registerActivity() {
        guard isFullscreen else {
            return
        }

        endInitialHoverSuppression()
        showChrome()
        scheduleChromeHide()
    }

    func registerHoverActivity(at location: CGPoint) {
        guard isFullscreen else {
            return
        }

        if isSuppressingInitialHover {
            guard let initialHoverLocation else {
                self.initialHoverLocation = location
                return
            }

            let deltaX = location.x - initialHoverLocation.x
            let deltaY = location.y - initialHoverLocation.y
            let distance = sqrt(deltaX * deltaX + deltaY * deltaY)
            guard distance >= initialHoverMovementThreshold else {
                return
            }
        }

        registerActivity()
    }

    func hideChromeImmediately() {
        guard isFullscreen else {
            return
        }

        chromeHideTask?.cancel()
        chromeHideTask = nil
        isChromeVisible = false
        hideCursorIfNeeded()
    }

    private func showChrome() {
        isChromeVisible = true
        showCursorIfNeeded()
    }

    private func scheduleChromeHide() {
        chromeHideTask?.cancel()
        chromeHideTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard !Task.isCancelled else {
                return
            }

            await MainActor.run {
                self?.hideChromeImmediately()
            }
        }
    }

    private func beginInitialHoverSuppression() {
        isSuppressingInitialHover = true
        initialHoverLocation = nil
    }

    private func endInitialHoverSuppression() {
        isSuppressingInitialHover = false
        initialHoverLocation = nil
    }

    private func hideCursorIfNeeded() {
        guard !isCursorHidden else {
            return
        }

        NSCursor.hide()
        isCursorHidden = true
    }

    private func showCursorIfNeeded() {
        guard isCursorHidden else {
            return
        }

        NSCursor.unhide()
        isCursorHidden = false
    }
}

private final class PlaybackFullscreenWindow: NSWindow {
    var onEscape: (() -> Void)?

    override var canBecomeKey: Bool {
        true
    }

    override var canBecomeMain: Bool {
        true
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            onEscape?()
            return
        }

        super.keyDown(with: event)
    }
}

private final class PlaybackFullscreenRootView: NSView {
    private let renderView: NSView
    private let overlayView: NSView

    init(renderView: NSView, overlayView: NSView) {
        self.renderView = renderView
        self.overlayView = overlayView
        super.init(frame: .zero)

        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor

        renderView.removeFromSuperview()
        addSubview(renderView)
        addSubview(overlayView)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func layout() {
        super.layout()
        renderView.frame = bounds
        overlayView.frame = bounds
    }

    func detachRenderView() {
        if renderView.superview === self {
            renderView.removeFromSuperview()
        }
    }
}

private struct PlaybackFullscreenOverlayView: View {
    @ObservedObject var fullscreenManager: PlaybackFullscreenManager
    @ObservedObject var viewModel: PlaybackViewModel
    let onCopySubtitle: () -> Void
    let onExit: () -> Void

    var body: some View {
        ZStack {
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    fullscreenManager.registerActivity()
                    viewModel.togglePlayPause()
                }

            if fullscreenManager.isChromeVisible {
                PlaybackControlsView(
                    viewModel: viewModel,
                    isFullscreen: true,
                    onCopySubtitle: onCopySubtitle,
                    onToggleFullscreen: onExit
                )
                .transition(.opacity)
            }

            PlaybackSubtitleOverlay(
                text: viewModel.activeSubtitleText,
                bottomPadding: fullscreenManager.isChromeVisible ? 128 : 56
            )

            PlaybackFeedbackOverlay(feedback: viewModel.feedback)
        }
        .background(Color.clear)
        .onContinuousHover { phase in
            if case .active(let location) = phase {
                fullscreenManager.registerHoverActivity(at: location)
            }
        }
        .animation(.easeInOut(duration: 0.16), value: fullscreenManager.isChromeVisible)
    }
}
