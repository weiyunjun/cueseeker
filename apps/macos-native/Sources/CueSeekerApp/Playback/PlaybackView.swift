import AppKit
import QuartzCore
import SwiftUI
import CueSeekerPlayback

struct PlaybackView: View {
    let player: PlaybackPlayer?
    let viewModel: PlaybackViewModel?
    let onSurfaceTap: () -> Void

    var body: some View {
        if let player, let viewModel {
            PlaybackVideoView(
                player: player,
                viewModel: viewModel,
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
    let onSurfaceTap: () -> Void

    var body: some View {
        ZStack {
            // S5.2: the dedicated full-window video page (ADR-0013) makes the
            // 69861f2 fullscreen render-sync band-aid unnecessary; the render
            // host is laid out by normal AppKit layout passes. No fullscreen
            // state is threaded into the render wrapper.
            PlaybackRenderViewWrapper(player: player)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .onTapGesture {
                onSurfaceTap()
            }

            PlaybackSubtitleOverlay(
                text: viewModel.activeSubtitleText,
                bottomPadding: 28
            )
            // The feedback HUD is hosted by PlaybackPageView above the centered
            // overlay panel (doc 12 §11/§13.4, doc 11 §6); it is intentionally
            // not in this render-surface ZStack so the panel cannot occlude it.
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

    // S5.2: no fullscreen-transition resync. The singleton render host stays
    // in the one window hierarchy and is laid out by normal AppKit layout
    // passes (ADR-0013 structural resolution); the 69861f2 band-aid is removed.
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

        synchronizeRenderViewFrame(logName: "PlaybackRenderHostView.layout")
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

    private func synchronizeRenderViewFrame(logName: String) {
        AppPerformanceProbe.measure(logName, thresholdMilliseconds: 8) {
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
    }
}
