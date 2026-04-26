import AppKit
import SwiftUI

struct PlaybackView: NSViewRepresentable {
    let onReady: (UInt) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = PlaybackHostView()
        let viewID = UInt(bitPattern: Unmanaged.passUnretained(view).toOpaque())
        DispatchQueue.main.async {
            onReady(viewID)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

private final class PlaybackHostView: NSView {
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
