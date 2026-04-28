import AppKit
import SwiftUI
import SubFinderXPlayback

struct PlaybackView: View {
    let player: MPVPlayer?
    let viewModel: PlaybackViewModel?
    @ObservedObject var fullscreenManager: PlaybackFullscreenManager

    var body: some View {
        if let player, let viewModel {
            PlaybackVideoView(
                player: player,
                viewModel: viewModel,
                fullscreenManager: fullscreenManager
            )
        } else {
            Color.black
        }
    }
}

struct PlaybackVideoView: View {
    let player: MPVPlayer
    @ObservedObject var viewModel: PlaybackViewModel
    @ObservedObject var fullscreenManager: PlaybackFullscreenManager
    @State private var isControlsVisible = false

    var body: some View {
        ZStack {
            if fullscreenManager.isFullscreen {
                Color.black
            } else {
                MPVRenderViewWrapper(player: player)
            }
            
            if isControlsVisible && !fullscreenManager.isFullscreen {
                PlaybackControlsView(
                    viewModel: viewModel,
                    onToggleFullscreen: {
                        fullscreenManager.toggleFullscreen(
                            player: player,
                            viewModel: viewModel
                        )
                    }
                )
            }
        }
        .onHover { hover in
            isControlsVisible = hover
        }
    }
}

struct MPVRenderViewWrapper: NSViewRepresentable {
    let player: MPVPlayer

    func makeNSView(context: Context) -> NSView {
        MPVRenderHostView(player: player)
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

private final class MPVRenderHostView: NSView {
    private let renderView: MPVRenderView

    init(player: MPVPlayer) {
        self.renderView = player.renderView
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
        attachRenderView()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()

        if window != nil, renderView.superview == nil {
            attachRenderView()
        }
    }

    override func layout() {
        super.layout()

        if renderView.superview === self {
            renderView.frame = bounds
        }
    }

    private func attachRenderView() {
        guard renderView.superview !== self else {
            return
        }

        renderView.removeFromSuperview()
        addSubview(renderView)
        renderView.frame = bounds
    }
}
