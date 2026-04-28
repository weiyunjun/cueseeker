import AppKit
import SwiftUI
import SubFinderXPlayback

struct PlaybackView: View {
    let player: PlaybackPlayer?
    let viewModel: PlaybackViewModel?
    @ObservedObject var fullscreenManager: PlaybackFullscreenManager
    let onSurfaceTap: () -> Void

    var body: some View {
        if let player, let viewModel {
            PlaybackVideoView(
                player: player,
                viewModel: viewModel,
                fullscreenManager: fullscreenManager,
                onSurfaceTap: onSurfaceTap
            )
        } else {
            Color.black
        }
    }
}

struct PlaybackVideoView: View {
    let player: PlaybackPlayer
    @ObservedObject var viewModel: PlaybackViewModel
    @ObservedObject var fullscreenManager: PlaybackFullscreenManager
    let onSurfaceTap: () -> Void
    @State private var isControlsVisible = false

    var body: some View {
        ZStack {
            if fullscreenManager.isFullscreen {
                Color.black
            } else {
                PlaybackRenderViewWrapper(player: player)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        onSurfaceTap()
                    }
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

            PlaybackFeedbackOverlay(feedback: viewModel.feedback)
        }
        .onHover { hover in
            isControlsVisible = hover
        }
    }
}

struct PlaybackRenderViewWrapper: NSViewRepresentable {
    let player: PlaybackPlayer

    func makeNSView(context: Context) -> NSView {
        PlaybackRenderHostView(player: player)
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

private final class PlaybackRenderHostView: NSView {
    private let renderView: NSView

    init(player: PlaybackPlayer) {
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
