import AppKit
import SwiftUI

/// The frames of the Player UI's clickable controls, collected by the stage
/// for `PlaybackChromeVisibilityModel`: the pointer resting on one keeps the
/// Player UI and the pointer shown.
struct PlayerInteractiveRegionKey: PreferenceKey {
    static let defaultValue: [Anchor<CGRect>] = []

    static func reduce(value: inout [Anchor<CGRect>], nextValue: () -> [Anchor<CGRect>]) {
        value.append(contentsOf: nextValue())
    }
}

extension View {
    /// Marks a clickable Player UI control.
    func playerInteractiveRegion() -> some View {
        anchorPreference(key: PlayerInteractiveRegionKey.self, value: .bounds) { [$0] }
    }
}

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

    /// Top-left origin, so a pointer position converted into this view lands
    /// in the same coordinates as the SwiftUI frames of the stage it fills.
    override var isFlipped: Bool {
        true
    }

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
