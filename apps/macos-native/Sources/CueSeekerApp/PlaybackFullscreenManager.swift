import AppKit
import QuartzCore
import SwiftUI
import CueSeekerPlayback

@MainActor
final class PlaybackFullscreenManager: NSObject, ObservableObject, NSWindowDelegate {
    @Published private(set) var isFullscreen = false
    @Published private(set) var isChromeVisible = false

    private var fullscreenWindow: PlaybackFullscreenWindow?
    private var fullscreenRootView: PlaybackFullscreenRootView?
    private weak var previousKeyWindow: NSWindow?
    private var chromeHideTask: Task<Void, Never>?
    private var onExitRequest: (() -> Void)?
    private var transitionCompletion: (() -> Void)?
    private var isCursorHidden = false
    private var isSuppressingInitialHover = false
    private var isFullscreenTransitioning = false
    private var initialHoverLocation: CGPoint?
    private let initialHoverMovementThreshold: CGFloat = 6

    @discardableResult
    func toggleFullscreen(
        player: PlaybackPlayer,
        viewModel: PlaybackViewModel,
        appState: AppState,
        onExitRequest: (() -> Void)? = nil,
        onTransitionCompleted: (() -> Void)? = nil
    ) -> Bool {
        if isFullscreen {
            return exitFullscreen(
                animated: true,
                onTransitionCompleted: onTransitionCompleted
            )
        } else {
            return enterFullscreen(
                player: player,
                viewModel: viewModel,
                appState: appState,
                onExitRequest: onExitRequest,
                onTransitionCompleted: onTransitionCompleted
            )
        }
    }

    @discardableResult
    func enterFullscreen(
        player: PlaybackPlayer,
        viewModel: PlaybackViewModel,
        appState: AppState,
        onExitRequest: (() -> Void)? = nil,
        onTransitionCompleted: (() -> Void)? = nil
    ) -> Bool {
        guard !isFullscreen, fullscreenWindow == nil, !isFullscreenTransitioning else {
            return false
        }

        let keyWindow = NSApplication.shared.keyWindow
        previousKeyWindow = keyWindow

        let screen = keyWindow?.screen
            ?? player.renderView.window?.screen
            ?? NSScreen.main

        guard let screen else {
            return false
        }

        let startFrame = validWindowFrame(
            renderFrameInScreen(for: player),
            fallback: fallbackWindowFrame(on: screen)
        )

        let window = PlaybackFullscreenWindow(
            contentRect: startFrame,
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false,
            screen: screen
        )
        window.title = "CueSeeker"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.backgroundColor = .black
        window.collectionBehavior = [.fullScreenPrimary]
        window.hasShadow = true
        window.isOpaque = true
        window.acceptsMouseMovedEvents = true
        window.isReleasedWhenClosed = false
        window.delegate = self
        hideStandardWindowButtons(for: window)
        window.onEscape = { [weak self] in
            Task { @MainActor in
                self?.requestExitFullscreen()
            }
        }

        let overlayView = NSHostingView(
            rootView: PlaybackFullscreenOverlayView(
                fullscreenManager: self,
                viewModel: viewModel,
                appState: appState,
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
        transitionCompletion = onTransitionCompleted
        isFullscreen = true
        isFullscreenTransitioning = true
        beginInitialHoverSuppression()
        hideChromeImmediately()

        window.contentView = rootView
        window.makeKeyAndOrderFront(nil)
        hideStandardWindowButtons(for: window)
        NSApplication.shared.activate(ignoringOtherApps: true)

        DispatchQueue.main.async { [weak self] in
            guard let self, self.fullscreenWindow === window else {
                return
            }

            self.hideStandardWindowButtons(for: window)
            window.toggleFullScreen(nil)
        }
        return true
    }

    @discardableResult
    func exitFullscreen(
        animated: Bool = false,
        onTransitionCompleted: (() -> Void)? = nil
    ) -> Bool {
        guard isFullscreen || fullscreenWindow != nil else {
            return false
        }

        guard !isFullscreenTransitioning || !animated else {
            return false
        }

        let window = fullscreenWindow
        let rootView = fullscreenRootView

        chromeHideTask?.cancel()
        chromeHideTask = nil
        isChromeVisible = false
        endInitialHoverSuppression()
        showCursorIfNeeded()

        if animated, let window, window.styleMask.contains(.fullScreen) {
            isFullscreenTransitioning = true
            transitionCompletion = onTransitionCompleted
            window.toggleFullScreen(nil)
            return true
        }

        finishExitFullscreen(window: window, rootView: rootView)
        completeFullscreenTransition()
        onTransitionCompleted?()
        return true
    }

    private func finishExitFullscreen(
        window: PlaybackFullscreenWindow?,
        rootView: PlaybackFullscreenRootView?
    ) {
        guard isFullscreen || fullscreenWindow != nil || isFullscreenTransitioning else {
            return
        }

        chromeHideTask?.cancel()
        chromeHideTask = nil
        isChromeVisible = false
        endInitialHoverSuppression()
        showCursorIfNeeded()

        fullscreenWindow = nil
        fullscreenRootView = nil
        onExitRequest = nil
        isFullscreenTransitioning = false

        rootView?.detachRenderView()
        window?.delegate = nil
        window?.contentView = nil
        window?.orderOut(nil)
        window?.close()

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

    func windowWillEnterFullScreen(_ notification: Notification) {
        guard let window = notification.object as? NSWindow, window === fullscreenWindow else {
            return
        }

        hideStandardWindowButtons(for: window)
    }

    func windowDidEnterFullScreen(_ notification: Notification) {
        guard let window = notification.object as? NSWindow, window === fullscreenWindow else {
            return
        }

        hideStandardWindowButtons(for: window)
        isFullscreenTransitioning = false
        hideChromeImmediately()
        completeFullscreenTransition()
    }

    func windowWillExitFullScreen(_ notification: Notification) {
        guard let window = notification.object as? NSWindow, window === fullscreenWindow else {
            return
        }

        hideStandardWindowButtons(for: window)
        isFullscreenTransitioning = true
        chromeHideTask?.cancel()
        chromeHideTask = nil
        isChromeVisible = false
        endInitialHoverSuppression()
        showCursorIfNeeded()
    }

    func windowDidExitFullScreen(_ notification: Notification) {
        guard let window = notification.object as? PlaybackFullscreenWindow, window === fullscreenWindow else {
            return
        }

        hideStandardWindowButtons(for: window)
        finishExitFullscreen(window: fullscreenWindow, rootView: fullscreenRootView)
        completeFullscreenTransition()
    }

    func windowDidFailToEnterFullScreen(_ window: NSWindow) {
        guard window === fullscreenWindow else {
            return
        }

        finishExitFullscreen(window: fullscreenWindow, rootView: fullscreenRootView)
        completeFullscreenTransition()
    }

    func windowDidFailToExitFullScreen(_ window: NSWindow) {
        guard window === fullscreenWindow else {
            return
        }

        hideStandardWindowButtons(for: window)
        isFullscreenTransitioning = false
        hideChromeImmediately()
        completeFullscreenTransition()
    }

    func windowWillClose(_ notification: Notification) {
        guard notification.object as? PlaybackFullscreenWindow === fullscreenWindow else {
            return
        }

        finishExitFullscreen(window: fullscreenWindow, rootView: fullscreenRootView)
        completeFullscreenTransition()
    }

    func windowDidResize(_ notification: Notification) {
        guard let window = notification.object as? NSWindow, window === fullscreenWindow else {
            return
        }

        hideStandardWindowButtons(for: window)
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

    private func fallbackWindowFrame(on screen: NSScreen) -> NSRect {
        let visibleFrame = screen.visibleFrame
        let width = min(960, visibleFrame.width)
        let height = min(540, visibleFrame.height)
        return NSRect(
            x: visibleFrame.midX - width / 2,
            y: visibleFrame.midY - height / 2,
            width: width,
            height: height
        )
    }

    private func validWindowFrame(_ frame: NSRect?, fallback: NSRect) -> NSRect {
        guard let frame, isUsableWindowFrame(frame) else {
            return fallback
        }

        return frame
    }

    private func isUsableWindowFrame(_ frame: NSRect) -> Bool {
        frame.width > 1 && frame.height > 1
    }

    private func hideStandardWindowButtons(for window: NSWindow) {
        let buttonTypes: [NSWindow.ButtonType] = [
            .closeButton,
            .miniaturizeButton,
            .zoomButton
        ]
        for buttonType in buttonTypes {
            window.standardWindowButton(buttonType)?.isHidden = true
        }
    }

    private func completeFullscreenTransition() {
        let completion = transitionCompletion
        transitionCompletion = nil
        completion?()
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

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        renderView.frame = bounds
        overlayView.frame = bounds
        renderView.needsLayout = true
        renderView.layoutSubtreeIfNeeded()
        overlayView.needsLayout = true
        overlayView.layoutSubtreeIfNeeded()
        CATransaction.commit()
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
    @ObservedObject var appState: AppState
    let onExit: () -> Void

    var body: some View {
        ZStack {
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    fullscreenManager.registerActivity()
                    viewModel.togglePlayPause()
                }

            GeometryReader { geometry in
                if fullscreenManager.isChromeVisible {
                    PlaybackChromeView(
                        viewModel: viewModel,
                        controls: .appState(appState, fullscreenAction: onExit)
                    )
                    .frame(
                        width: max(0, geometry.size.width - PlaybackChromeMetrics.horizontalInset * 2),
                        height: PlaybackChromeMetrics.height
                    )
                    .position(
                        x: geometry.size.width / 2,
                        y: max(
                            PlaybackChromeMetrics.height / 2,
                            geometry.size.height - PlaybackChromeMetrics.bottomInset - PlaybackChromeMetrics.height / 2
                        )
                    )
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
            .zIndex(2)

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
