import AppKit
import SwiftUI
import Testing
@testable import CueSeekerApp

/// The height a hosted menu panel reported for itself.
@MainActor
private final class MenuPanelSizeProbe {
    var size: CGSize = .zero
}

/// Hosts a menu panel the way a card's context menu is hosted: in an overlay
/// that spans the whole page and therefore offers the panel far more height
/// than its items need. Menus hung off an AppKit host are measured with no
/// height offered at all, so only this arrangement can catch a panel that grows
/// into whatever it is offered.
@MainActor
private func hostMenuPanel(itemCount: Int) async -> MenuPanelSizeProbe {
    let probe = MenuPanelSizeProbe()
    let root = ZStack(alignment: .topLeading) {
        Color.clear

        WorkbenchPopoverPanel(isRedesign: true) {
            VStack(spacing: 0) {
                ForEach(0..<itemCount, id: \.self) { _ in
                    Color.clear.frame(width: 200, height: 30)
                }
            }
        }
        .background(
            GeometryReader { proxy in
                Color.clear
                    .onAppear { probe.size = proxy.size }
                    .onChange(of: proxy.size) { size in probe.size = size }
            }
        )
    }
    .frame(width: 600, height: 900)

    let host = NSHostingView(rootView: AnyView(root))
    host.frame = CGRect(x: 0, y: 0, width: 600, height: 900)
    let window = NSWindow(
        contentRect: host.frame,
        styleMask: [.borderless],
        backing: .buffered,
        defer: false
    )
    window.contentView = host

    for _ in 0..<3 {
        host.layoutSubtreeIfNeeded()
        await Task.yield()
    }
    return probe
}

@MainActor
@Test
func menuPanelInATallOverlayIsOnlyAsTallAsItsItems() async throws {
    let probe = await hostMenuPanel(itemCount: 3)

    // Three rows of 30pt plus the padding ring on both sides.
    let expected = 3 * 30 + 2 * MenuMetrics.padding
    #expect(abs(probe.size.height - expected) < 0.5)
    #expect(probe.size.height < MenuMetrics.maximumHeight)
}

@MainActor
@Test
func menuPanelInATallOverlayStopsAtTheHeightCap() async throws {
    // Thirty rows are nearly twice the cap.
    let probe = await hostMenuPanel(itemCount: 30)

    #expect(abs(probe.size.height - MenuMetrics.maximumHeight) < 0.5)
}
