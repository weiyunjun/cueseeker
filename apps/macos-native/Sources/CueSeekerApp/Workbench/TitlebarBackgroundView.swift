import SwiftUI
import AppKit

struct TitlebarBackgroundView: NSViewRepresentable {
    var backgroundColor: NSColor
    var allowsHitTesting: Bool = true
    var onDoubleClickZoom: (NSWindow) -> Bool = { _ in true }

    init(
        backgroundColor: Color,
        allowsHitTesting: Bool = true,
        onDoubleClickZoom: @escaping (NSWindow) -> Bool = { _ in true }
    ) {
        self.backgroundColor = NSColor(backgroundColor)
        self.allowsHitTesting = allowsHitTesting
        self.onDoubleClickZoom = onDoubleClickZoom
    }

    init(
        backgroundColor: NSColor,
        allowsHitTesting: Bool = true,
        onDoubleClickZoom: @escaping (NSWindow) -> Bool = { _ in true }
    ) {
        self.backgroundColor = backgroundColor
        self.allowsHitTesting = allowsHitTesting
        self.onDoubleClickZoom = onDoubleClickZoom
    }

    func makeNSView(context: Context) -> DraggableNSView {
        let view = DraggableNSView()
        view.wantsLayer = true
        view.backgroundColor = backgroundColor
        view.allowsHitTesting = allowsHitTesting
        view.onDoubleClickZoom = onDoubleClickZoom
        return view
    }

    func updateNSView(_ nsView: DraggableNSView, context: Context) {
        nsView.backgroundColor = backgroundColor
        nsView.allowsHitTesting = allowsHitTesting
        nsView.onDoubleClickZoom = onDoubleClickZoom
    }
}

final class DraggableNSView: NSView, SubtitleTableTextSelectionInteractiveView {
    var allowsHitTesting = true
    var onDoubleClickZoom: ((NSWindow) -> Bool)?
    var backgroundColor: NSColor = .clear {
        didSet {
            updateBackgroundColor()
        }
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        allowsHitTesting ? super.hitTest(point) : nil
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateBackgroundColor()
    }

    override func mouseDown(with event: NSEvent) {
        if event.clickCount == 2 {
            // Respect user's System Settings for double clicking the title bar.
            // Values are typically "Maximize", "Minimize", or missing (defaults to Zoom/Maximize).
            let action = UserDefaults.standard.string(forKey: "AppleActionOnDoubleClick") ?? "Maximize"
            
            if action == "Maximize" {
                guard let window else {
                    return
                }
                guard onDoubleClickZoom?(window) ?? true else {
                    return
                }
                window.performZoom(nil)
            } else if action == "Minimize" {
                self.window?.miniaturize(nil)
            }
        } else {
            // For a single click/drag, initiate native window dragging.
            self.window?.performDrag(with: event)
        }
    }

    private func updateBackgroundColor() {
        var resolvedColor: CGColor?
        effectiveAppearance.performAsCurrentDrawingAppearance {
            resolvedColor = backgroundColor.cgColor
        }
        layer?.backgroundColor = resolvedColor
    }
}
