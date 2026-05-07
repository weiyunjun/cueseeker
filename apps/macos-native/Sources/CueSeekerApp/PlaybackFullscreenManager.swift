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
    private var returnFrameInScreen: NSRect?
    private var chromeHideTask: Task<Void, Never>?
    private var onExitRequest: (() -> Void)?
    private var isCursorHidden = false
    private var isSuppressingInitialHover = false
    private var isSuspendedForAppDeactivation = false
    private var isFullscreenTransitioning = false
    private var initialHoverLocation: CGPoint?
    private let initialHoverMovementThreshold: CGFloat = 6

    @discardableResult
    func toggleFullscreen(
        player: PlaybackPlayer,
        viewModel: PlaybackViewModel,
        onCopySubtitle: @escaping () -> Void = {},
        onExitRequest: (() -> Void)? = nil
    ) -> TimeInterval? {
        if isFullscreen {
            return exitFullscreen(animated: true)
        } else {
            return enterFullscreen(
                player: player,
                viewModel: viewModel,
                onCopySubtitle: onCopySubtitle,
                onExitRequest: onExitRequest,
                animated: true
            )
        }
    }

    @discardableResult
    func enterFullscreen(
        player: PlaybackPlayer,
        viewModel: PlaybackViewModel,
        onCopySubtitle: @escaping () -> Void = {},
        onExitRequest: (() -> Void)? = nil,
        animated: Bool = true
    ) -> TimeInterval? {
        guard !isFullscreen, fullscreenWindow == nil, !isFullscreenTransitioning else {
            return nil
        }

        let keyWindow = NSApplication.shared.keyWindow
        previousKeyWindow = keyWindow

        let screen = keyWindow?.screen
            ?? player.renderView.window?.screen
            ?? NSScreen.main

        guard let screen else {
            return nil
        }

        previousPresentationOptions = NSApplication.shared.presentationOptions
        returnFrameInScreen = renderFrameInScreen(for: player)
        let targetFrame = screen.frame
        let startFrame = validWindowFrame(
            returnFrameInScreen,
            fallback: targetFrame
        )

        let window = PlaybackFullscreenWindow(
            contentRect: animated ? startFrame : targetFrame,
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
        isFullscreenTransitioning = animated
        beginInitialHoverSuppression()
        hideChromeImmediately()

        window.contentView = rootView
        NSApplication.shared.presentationOptions = [.autoHideMenuBar, .autoHideDock]
        window.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)

        DispatchQueue.main.async { [weak self] in
            self?.hideChromeImmediately()
        }

        guard animated else {
            return nil
        }

        let duration = max(0, window.animationResizeTime(targetFrame))
        animateWindow(
            window,
            to: targetFrame,
            duration: duration
        ) { [weak self] in
            self?.isFullscreenTransitioning = false
            self?.hideChromeImmediately()
        }
        return duration
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

    @discardableResult
    func exitFullscreen(animated: Bool = false) -> TimeInterval? {
        guard isFullscreen || fullscreenWindow != nil else {
            return nil
        }

        guard !isFullscreenTransitioning || !animated else {
            return nil
        }

        let window = fullscreenWindow
        let rootView = fullscreenRootView
        let targetFrame = validWindowFrameOrNil(returnFrameInScreen, fallback: window?.frame)

        chromeHideTask?.cancel()
        chromeHideTask = nil
        isChromeVisible = false
        isSuspendedForAppDeactivation = false
        endInitialHoverSuppression()
        showCursorIfNeeded()

        if animated, let window, let targetFrame {
            isFullscreenTransitioning = true
            let duration = max(0, window.animationResizeTime(targetFrame))
            animateWindow(
                window,
                to: targetFrame,
                duration: duration
            ) { [weak self] in
                self?.finishExitFullscreen(window: window, rootView: rootView)
            }
            return duration
        }

        finishExitFullscreen(window: window, rootView: rootView)
        return nil
    }

    private func finishExitFullscreen(
        window: PlaybackFullscreenWindow?,
        rootView: PlaybackFullscreenRootView?
    ) {
        guard isFullscreen || fullscreenWindow != nil || isFullscreenTransitioning else {
            return
        }

        fullscreenWindow = nil
        fullscreenRootView = nil
        onExitRequest = nil
        returnFrameInScreen = nil
        isFullscreenTransitioning = false

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
            exitFullscreen(animated: true)
        }
    }

    private func renderFrameInScreen(for player: PlaybackPlayer) -> NSRect? {
        let renderView = player.renderView
        guard let window = renderView.window else {
            return nil
        }

        let frame = window.convertToScreen(renderView.convert(renderView.bounds, to: nil))
        guard isUsableWindowFrame(frame) else {
            return nil
        }

        return frame
    }

    private func validWindowFrame(_ frame: NSRect?, fallback: NSRect) -> NSRect {
        guard let frame, isUsableWindowFrame(frame) else {
            return fallback
        }

        return frame
    }

    private func validWindowFrameOrNil(_ frame: NSRect?, fallback: NSRect?) -> NSRect? {
        guard let fallback else {
            return nil
        }

        return validWindowFrame(frame, fallback: fallback)
    }

    private func isUsableWindowFrame(_ frame: NSRect) -> Bool {
        frame.width > 1 && frame.height > 1
    }

    private func animateWindow(
        _ window: NSWindow,
        to targetFrame: NSRect,
        duration: TimeInterval,
        completion: @escaping () -> Void
    ) {
        guard duration > 0 else {
            window.setFrame(targetFrame, display: true)
            completion()
            return
        }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = duration
            window.animator().setFrame(targetFrame, display: true)
        } completionHandler: {
            completion()
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
