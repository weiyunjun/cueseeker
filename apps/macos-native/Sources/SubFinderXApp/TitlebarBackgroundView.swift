import SwiftUI
import AppKit

struct TitlebarBackgroundView: NSViewRepresentable {
    var backgroundColor: Color

    func makeNSView(context: Context) -> DraggableNSView {
        let view = DraggableNSView()
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor(backgroundColor).cgColor
        return view
    }

    func updateNSView(_ nsView: DraggableNSView, context: Context) {
        nsView.layer?.backgroundColor = NSColor(backgroundColor).cgColor
    }
}

final class DraggableNSView: NSView {
    override func mouseDown(with event: NSEvent) {
        if event.clickCount == 2 {
            // Respect user's System Settings for double clicking the title bar.
            // Values are typically "Maximize", "Minimize", or missing (defaults to Zoom/Maximize).
            let action = UserDefaults.standard.string(forKey: "AppleActionOnDoubleClick") ?? "Maximize"
            
            if action == "Maximize" {
                self.window?.performZoom(nil)
            } else if action == "Minimize" {
                self.window?.miniaturize(nil)
            }
        } else {
            // For a single click/drag, initiate native window dragging.
            self.window?.performDrag(with: event)
        }
    }
}
