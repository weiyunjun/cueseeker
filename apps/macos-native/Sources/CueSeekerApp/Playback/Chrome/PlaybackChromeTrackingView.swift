import AppKit
import SwiftUI

struct PlaybackChromeTrackingView: NSViewRepresentable {
    let onViewChanged: (NSView) -> Void
    let onEntered: (NSView) -> Void
    let onMoved: (NSView) -> Void
    let onExited: (NSView) -> Void

    func makeNSView(context: Context) -> PlaybackChromeTrackingNSView {
        let view = PlaybackChromeTrackingNSView()
        view.onViewChanged = onViewChanged
        view.onEntered = onEntered
        view.onMoved = onMoved
        view.onExited = onExited
        return view
    }

    func updateNSView(_ nsView: PlaybackChromeTrackingNSView, context: Context) {
        nsView.onViewChanged = onViewChanged
        nsView.onEntered = onEntered
        nsView.onMoved = onMoved
        nsView.onExited = onExited
        nsView.notifyViewChanged()
    }
}

final class PlaybackChromeTrackingNSView: NSView {
    var onViewChanged: (NSView) -> Void = { _ in }
    var onEntered: (NSView) -> Void = { _ in }
    var onMoved: (NSView) -> Void = { _ in }
    var onExited: (NSView) -> Void = { _ in }

    // Never intercept clicks/drag: events pass through to the controls and
    // video below. Tracking-area enter/exit/moved are still delivered.
    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        notifyViewChanged()
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(
            NSTrackingArea(
                rect: .zero,
                options: [.mouseEnteredAndExited, .mouseMoved, .activeAlways, .inVisibleRect],
                owner: self,
                userInfo: nil
            )
        )
        notifyViewChanged()
    }

    func notifyViewChanged() {
        onViewChanged(self)
    }

    override func mouseEntered(with event: NSEvent) {
        onEntered(self)
    }

    override func mouseMoved(with event: NSEvent) {
        onMoved(self)
    }

    override func mouseExited(with event: NSEvent) {
        onExited(self)
    }
}
