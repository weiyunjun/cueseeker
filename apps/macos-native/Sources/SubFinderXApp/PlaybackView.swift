import AppKit
import SwiftUI
import SubFinderXPlayback

struct PlaybackView: NSViewRepresentable {
    let player: MPVPlayer?

    func makeNSView(context: Context) -> NSView {
        guard let player else {
            return PlaybackPlaceholderView()
        }

        return MPVRenderView(player: player)
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

private final class PlaybackPlaceholderView: NSView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }
}
