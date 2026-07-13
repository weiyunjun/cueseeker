import AppKit
import SwiftUI
import Testing
@testable import CueSeekerApp

@MainActor
@Test
func workbenchEmptyHintPassesMouseHitTestingToUnderlyingTableSurface() {
    let probe = WorkbenchEmptyHintHitProbeView()
    let hostingView = NSHostingView(
        rootView: ZStack {
            WorkbenchEmptyHintHitProbe(probe: probe)
            WorkbenchEmptyHint(message: "No rows")
        }
        .frame(width: 320, height: 200)
    )
    hostingView.frame = CGRect(x: 0, y: 0, width: 320, height: 200)

    let window = NSWindow(
        contentRect: hostingView.frame,
        styleMask: [.borderless],
        backing: .buffered,
        defer: false
    )
    window.contentView = hostingView
    hostingView.layoutSubtreeIfNeeded()

    #expect(hostingView.hitTest(CGPoint(x: 160, y: 100)) === probe)
}

@MainActor
private final class WorkbenchEmptyHintHitProbeView: NSView {}

private struct WorkbenchEmptyHintHitProbe: NSViewRepresentable {
    let probe: WorkbenchEmptyHintHitProbeView

    func makeNSView(context _: Context) -> WorkbenchEmptyHintHitProbeView {
        probe
    }

    func updateNSView(_ nsView: WorkbenchEmptyHintHitProbeView, context _: Context) {}
}
