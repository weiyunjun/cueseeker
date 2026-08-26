import AppKit
import SwiftUI

/// Where a menu's anchor control is, answered across hosting boundaries.
///
/// A button that lives in one `NSHostingView` cannot hand its frame to a menu
/// host in another through SwiftUI coordinate spaces: each hierarchy's
/// "global" space is its own root. The shared window is the one space both
/// sides can reach, so a probe view sits behind each side and the anchor
/// converts through it on demand.
@MainActor
final class MenuAnchorHandle {
    fileprivate(set) weak var view: NSView?

    /// This anchor's frame in `host`'s top-left-down space, or nil while
    /// either side is off screen or they are not in the same window.
    func frame(in host: MenuAnchorHandle) -> CGRect? {
        guard let view, let hostView = host.view,
              let window = view.window, hostView.window === window
        else {
            return nil
        }
        return hostView.convert(view.convert(view.bounds, to: nil), from: nil)
    }

    var bounds: CGRect? {
        view?.bounds
    }
}

/// Mount as the background of the anchor control, or of the surface a menu is
/// placed in, at exactly the area the handle should describe.
struct MenuAnchorProbe: NSViewRepresentable {
    let handle: MenuAnchorHandle

    func makeNSView(context _: Context) -> ProbeView {
        let view = ProbeView()
        handle.view = view
        return view
    }

    func updateNSView(_ nsView: ProbeView, context _: Context) {
        handle.view = nsView
    }

    final class ProbeView: NSView {
        /// SwiftUI measures top-left down; answering in the same direction
        /// keeps every "below the anchor" below it.
        override var isFlipped: Bool {
            true
        }

        override func hitTest(_ point: NSPoint) -> NSView? {
            nil
        }
    }
}
