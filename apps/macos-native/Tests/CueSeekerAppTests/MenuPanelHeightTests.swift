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

        WorkbenchPopoverPanel(
            highlight: MenuHighlightModel()
        ) {
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

@MainActor
@Test
func menuPanelSnapsFractionalMeasurementsAndKeepsUnclippedScrollBoundsStableOnKeyboardNavigation() async throws {
    var cappedPanelSize: CGSize = .zero
    var cappedStackSize: CGSize = .zero
    let cappedRoot = ZStack(alignment: .topLeading) {
        Color.clear

        MenuItemStack(
            padding: MenuMetrics.padding,
            strip: MenuMetrics.scrollbarStrip,
            cap: 95.82
        ) {
            VStack(spacing: 0) {
                ForEach(0..<5, id: \.self) { _ in
                    Color.clear.frame(width: 172.34, height: 28.37)
                }
            }
        }
        .background(
            GeometryReader { proxy in
                Color.clear
                    .onAppear { cappedStackSize = proxy.size }
                    .onChange(of: proxy.size) { size in cappedStackSize = size }
            }
        )

        WorkbenchPopoverPanel(
            maximumHeight: 95.82,
            highlight: MenuHighlightModel()
        ) {
            VStack(spacing: 0) {
                ForEach(0..<5, id: \.self) { _ in
                    Color.clear.frame(width: 172.34, height: 28.37)
                }
            }
        }
        .background(
            GeometryReader { proxy in
                Color.clear
                    .onAppear { cappedPanelSize = proxy.size }
                    .onChange(of: proxy.size) { size in cappedPanelSize = size }
            }
        )
    }
    .frame(width: 600, height: 900)

    let cappedHost = NSHostingView(rootView: AnyView(cappedRoot))
    cappedHost.frame = CGRect(x: 0, y: 0, width: 600, height: 900)
    let cappedWindow = NSWindow(
        contentRect: cappedHost.frame,
        styleMask: [.borderless],
        backing: .buffered,
        defer: false
    )
    cappedWindow.contentView = cappedHost
    for _ in 0..<4 {
        cappedHost.layoutSubtreeIfNeeded()
        await Task.yield()
    }

    #expect(cappedStackSize.width > 0)
    #expect(cappedStackSize.height > 0)
    #expect(cappedStackSize.width.truncatingRemainder(dividingBy: 1) == 0)
    #expect(cappedStackSize.height.truncatingRemainder(dividingBy: 1) == 0)
    #expect(cappedPanelSize.width.truncatingRemainder(dividingBy: 1) == 0)
    #expect(cappedPanelSize.height.truncatingRemainder(dividingBy: 1) == 0)
    #expect(cappedPanelSize.height == 95)

    let highlight = MenuHighlightModel()
    highlight.open(selectablePositions: Array(0..<6))
    var unclippedPanelSize: CGSize = .zero
    let unclippedRoot = ZStack(alignment: .topLeading) {
        Color.clear

        WorkbenchPopoverPanel(
            maximumHeight: MenuMetrics.maximumHeight,
            highlight: highlight
        ) {
            VStack(spacing: 0) {
                ForEach(0..<6, id: \.self) { position in
                    WorkbenchPopoverRow(
                        title: "Action \(position)",
                        isHighlighted: highlight.isSelected(position),
                        isRowHovered: highlight.isHovered(position),
                        showsCheckmarkSlot: false
                    )
                    .id(position)
                }
            }
        }
        .background(
            GeometryReader { proxy in
                Color.clear
                    .onAppear { unclippedPanelSize = proxy.size }
                    .onChange(of: proxy.size) { size in unclippedPanelSize = size }
            }
        )
    }
    .frame(width: 600, height: 900)

    let unclippedHost = NSHostingView(rootView: AnyView(unclippedRoot))
    unclippedHost.frame = CGRect(x: 0, y: 0, width: 600, height: 900)
    let unclippedWindow = NSWindow(
        contentRect: unclippedHost.frame,
        styleMask: [.borderless],
        backing: .buffered,
        defer: false
    )
    unclippedWindow.contentView = unclippedHost
    for _ in 0..<5 {
        unclippedHost.layoutSubtreeIfNeeded()
        await Task.yield()
    }

    let scrollView = try #require(findHostedScrollView(in: unclippedHost))
    let initialBoundsOrigin = scrollView.contentView.bounds.origin
    let initialPanelSize = unclippedPanelSize
    #expect(initialPanelSize.width.truncatingRemainder(dividingBy: 1) == 0)
    #expect(initialPanelSize.height.truncatingRemainder(dividingBy: 1) == 0)

    var boundsChangeCount = 0
    let observer = NotificationCenter.default.addObserver(
        forName: NSView.boundsDidChangeNotification,
        object: scrollView.contentView,
        queue: nil
    ) { _ in
        boundsChangeCount += 1
    }
    defer {
        NotificationCenter.default.removeObserver(observer)
    }

    for delta in [1, 1, 1, 1, 1, -1, -1, -1, -1, -1] {
        highlight.moveHighlight(by: delta)
        unclippedHost.layoutSubtreeIfNeeded()
        await Task.yield()
    }

    #expect(boundsChangeCount == 0)
    #expect(scrollView.contentView.bounds.origin == initialBoundsOrigin)
    #expect(unclippedPanelSize == initialPanelSize)
}

@MainActor
private func findHostedScrollView(in view: NSView) -> NSScrollView? {
    if let overlay = view as? WorkbenchScrollViewOverlayView,
       let target = overlay.targetScrollViewForTesting {
        return target
    }
    if let scrollView = view as? NSScrollView {
        return scrollView
    }
    for subview in view.subviews {
        if let found = findHostedScrollView(in: subview) {
            return found
        }
    }
    return nil
}
