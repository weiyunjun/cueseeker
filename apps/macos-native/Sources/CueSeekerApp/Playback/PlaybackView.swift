import AppKit
import QuartzCore
import SwiftUI
import CueSeekerPlayback

struct PlaybackView: View {
    let player: PlaybackPlayer?
    let viewModel: PlaybackViewModel?
    let uiProbeScope: String

    var body: some View {
        if let player, let viewModel {
            PlaybackVideoView(
                player: player,
                viewModel: viewModel,
                uiProbeScope: uiProbeScope
            )
        } else {
            Color.black
        }
    }
}

struct PlaybackVideoView: View {
    let player: PlaybackPlayer
    let viewModel: PlaybackViewModel
    let uiProbeScope: String

    var body: some View {
        ZStack {
            // S5.2: the dedicated full-window video page (ADR-0013) makes the
            // 69861f2 fullscreen render-sync band-aid unnecessary; the render
            // host is laid out by normal AppKit layout passes. No fullscreen
            // state is threaded into the render wrapper.
            PlaybackRenderViewWrapper(
                player: player,
                uiProbeScope: uiProbeScope
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // The feedback HUD is hosted by PlaybackPageView above the centered
            // overlay panel (doc 12 §11/§13.4, doc 11 §6); it is intentionally
            // not in this render-surface ZStack so the panel cannot occlude it.
        }
    }
}

struct PlaybackRenderViewWrapper: NSViewRepresentable {
    let player: PlaybackPlayer
    let uiProbeScope: String

    func makeNSView(context: Context) -> NSView {
        UIInvalidationProbe.count("playback.render_host_update", scope: uiProbeScope)
        UIInvalidationProbe.count("playback.render_host_native_make", scope: uiProbeScope)
        return PlaybackRenderHostView(
            player: player,
            uiProbeScope: uiProbeScope
        )
    }

    // S5.2: no fullscreen-transition resync. The singleton render host stays
    // in the one window hierarchy and is laid out by normal AppKit layout
    // passes (ADR-0013 structural resolution); the 69861f2 band-aid is removed.
    func updateNSView(_ nsView: NSView, context: Context) {
        UIInvalidationProbe.count("playback.render_host_update", scope: uiProbeScope)
        UIInvalidationProbe.count("playback.render_host_native_update", scope: uiProbeScope)
    }
}

private final class PlaybackRenderHostView: NSView {
    private let renderView: NSView
    private let uiProbeScope: String

    init(player: PlaybackPlayer, uiProbeScope: String) {
        self.renderView = player.renderView
        self.uiProbeScope = uiProbeScope
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
        attachRenderView()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
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
        UIInvalidationProbe.count("playback.render_host_update", scope: uiProbeScope)
        UIInvalidationProbe.count("playback.render_host_attached", scope: uiProbeScope)
        renderView.frame = bounds
        renderView.needsLayout = true
        renderView.layoutSubtreeIfNeeded()
    }

    private func synchronizeRenderViewFrame(logName: String) {
        AppPerformanceProbe.measure(logName, thresholdMilliseconds: 8) {
            guard renderView.superview === self else {
                return
            }

            UIInvalidationProbe.count("playback.render_host_update", scope: uiProbeScope)
            UIInvalidationProbe.count("playback.render_host_frame_sync", scope: uiProbeScope)

            CATransaction.begin()
            CATransaction.setDisableActions(true)
            renderView.frame = bounds
            renderView.needsLayout = true
            renderView.layoutSubtreeIfNeeded()
            CATransaction.commit()
        }
    }
}
