import AppKit
import QuartzCore
import SwiftUI
import CueSeekerPlayback

struct PlaybackView: View {
    let player: PlaybackPlayer?
    let viewModel: PlaybackViewModel?
    @ObservedObject var fullscreenManager: PlaybackFullscreenManager
    let onSurfaceTap: () -> Void
    let onCopySubtitle: () -> Void
    let isFullscreenToggleDisabled: Bool
    let onToggleFullscreen: () -> Void

    var body: some View {
        if let player, let viewModel {
            PlaybackVideoView(
                player: player,
                viewModel: viewModel,
                fullscreenManager: fullscreenManager,
                onSurfaceTap: onSurfaceTap,
                onCopySubtitle: onCopySubtitle,
                isFullscreenToggleDisabled: isFullscreenToggleDisabled,
                onToggleFullscreen: onToggleFullscreen
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
    let onCopySubtitle: () -> Void
    let isFullscreenToggleDisabled: Bool
    let onToggleFullscreen: () -> Void
    @State private var isControlsVisible = false

    var body: some View {
        ZStack {
            if fullscreenManager.isFullscreen {
                Color.clear
            } else {
                PlaybackRenderViewWrapper(player: player)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        onSurfaceTap()
                    }
            }
            
            if isControlsVisible && !fullscreenManager.isFullscreen {
                PlaybackControlsView(
                    viewModel: viewModel,
                    isFullscreenToggleDisabled: isFullscreenToggleDisabled,
                    onCopySubtitle: onCopySubtitle,
                    onToggleFullscreen: onToggleFullscreen
                )
            }

            if !fullscreenManager.isFullscreen {
                PlaybackSubtitleOverlay(
                    text: viewModel.activeSubtitleText,
                    bottomPadding: isControlsVisible ? 112 : 28
                )

                PlaybackFeedbackOverlay(feedback: viewModel.feedback)
            }
        }
        .onHover { hover in
            isControlsVisible = hover
        }
    }
}

struct PlaybackSubtitleOverlay: View {
    let text: String?
    let bottomPadding: CGFloat

    var body: some View {
        VStack {
            Spacer()

            if let text {
                Text(text)
                    .font(.system(size: 21, weight: .semibold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .minimumScaleFactor(0.72)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.black.opacity(0.68))
                    )
                    .shadow(color: .black.opacity(0.5), radius: 8, y: 2)
                    .frame(maxWidth: 900)
                    .padding(.horizontal, 32)
                    .padding(.bottom, bottomPadding)
                    .transition(.opacity)
            }
        }
        .allowsHitTesting(false)
        .animation(.easeInOut(duration: 0.12), value: text)
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

        guard renderView.superview === self else {
            return
        }

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        renderView.frame = bounds
        renderView.needsLayout = true
        renderView.layoutSubtreeIfNeeded()
        CATransaction.commit()
    }

    private func attachRenderView() {
        guard renderView.superview !== self else {
            return
        }

        renderView.removeFromSuperview()
        addSubview(renderView)
        renderView.frame = bounds
        renderView.needsLayout = true
        renderView.layoutSubtreeIfNeeded()
    }
}
