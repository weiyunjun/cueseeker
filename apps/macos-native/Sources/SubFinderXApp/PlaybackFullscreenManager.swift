import AppKit
import SwiftUI
import SubFinderXPlayback

@MainActor
final class PlaybackFullscreenManager: ObservableObject {
    @Published private(set) var isFullscreen = false

    private var fullscreenWindow: PlaybackFullscreenWindow?
    private var fullscreenRootView: PlaybackFullscreenRootView?
    private var previousPresentationOptions: NSApplication.PresentationOptions?
    private weak var previousKeyWindow: NSWindow?

    func toggleFullscreen(player: MPVPlayer, viewModel: PlaybackViewModel) {
        if isFullscreen {
            exitFullscreen()
        } else {
            enterFullscreen(player: player, viewModel: viewModel)
        }
    }

    func enterFullscreen(player: MPVPlayer, viewModel: PlaybackViewModel) {
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
        window.isReleasedWhenClosed = false
        window.level = .screenSaver
        window.onEscape = { [weak self] in
            Task { @MainActor in
                self?.exitFullscreen()
            }
        }

        let overlayView = NSHostingView(
            rootView: PlaybackFullscreenOverlayView(
                viewModel: viewModel,
                onExit: { [weak self] in
                    Task { @MainActor in
                        self?.exitFullscreen()
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
        isFullscreen = true

        window.contentView = rootView
        NSApplication.shared.presentationOptions = [.autoHideMenuBar, .autoHideDock]
        window.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    func exitFullscreen() {
        guard isFullscreen || fullscreenWindow != nil else {
            return
        }

        let window = fullscreenWindow
        let rootView = fullscreenRootView

        fullscreenWindow = nil
        fullscreenRootView = nil

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
    private let renderView: MPVRenderView
    private let overlayView: NSView

    init(renderView: MPVRenderView, overlayView: NSView) {
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
    @ObservedObject var viewModel: PlaybackViewModel
    let onExit: () -> Void

    @State private var isControlsVisible = true

    var body: some View {
        ZStack {
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    viewModel.togglePlayPause()
                }

            if isControlsVisible {
                PlaybackControlsView(
                    viewModel: viewModel,
                    isFullscreen: true,
                    onToggleFullscreen: onExit
                )
                .transition(.opacity)
            }
        }
        .background(Color.clear)
        .onHover { hovering in
            isControlsVisible = hovering
        }
        .animation(.easeInOut(duration: 0.16), value: isControlsVisible)
    }
}
