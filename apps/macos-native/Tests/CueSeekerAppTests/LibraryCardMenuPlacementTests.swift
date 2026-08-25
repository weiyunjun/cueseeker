import AppKit
import SwiftUI
import Testing
@testable import CueSeekerApp

/// Drives a card's context menu the way a right-click does — through the very
/// callback the cards are handed — inside a page tall enough to scroll.
@MainActor
private final class CardMenuOpener {
    var open: (([LibraryCardContextMenuItem], CGPoint) -> Void)?
    var items: [LibraryCardContextMenuItem] = []
}

@MainActor
private func hostCardMenu(
    anchor: CGPoint,
    viewport: CGSize = CGSize(width: 600, height: 800),
    pageHeight: CGFloat = 2_400
) async -> (host: NSHostingView<AnyView>, window: NSWindow, opener: CardMenuOpener) {
    let opener = CardMenuOpener()
    let items = (1...5).map { index in
        LibraryCardContextMenuItem(
            title: "Item \(index)",
            systemImage: "circle",
            action: {}
        )
    }
    let root = WorkbenchScrollView {
        LibraryCardContextMenuHost { openContextMenu in
            Color.clear
                .frame(maxWidth: .infinity)
                .frame(height: pageHeight)
                .onAppear {
                    opener.open = openContextMenu
                    opener.items = items
                }
        }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)

    let host = NSHostingView(rootView: AnyView(root))
    host.frame = CGRect(origin: .zero, size: viewport)
    let window = NSWindow(
        contentRect: host.frame,
        styleMask: [.borderless],
        backing: .buffered,
        defer: false
    )
    window.contentView = host
    for _ in 0..<6 {
        host.layoutSubtreeIfNeeded()
        await Task.yield()
    }

    // Right-clicked on a page that is already on screen, which is the only way a
    // reader can reach a card.
    opener.open?(opener.items, anchor)
    for _ in 0..<6 {
        host.layoutSubtreeIfNeeded()
        await Task.yield()
    }
    return (host, window, opener)
}

@MainActor
private func openCardMenuFrame(in host: NSView) -> CGRect? {
    firstCardMenuMonitor(in: host)?.menuFrame
}

@MainActor
private func firstCardMenuMonitor(
    in root: NSView
) -> LibraryCardMenuPointerMonitor.MonitoringView? {
    for subview in root.subviews {
        if let match = subview as? LibraryCardMenuPointerMonitor.MonitoringView {
            return match
        }
        if let match = firstCardMenuMonitor(in: subview) {
            return match
        }
    }
    return nil
}

@MainActor
private func scrollCardMenuPage(_ host: NSView, to y: CGFloat) async {
    guard let overlay = firstCardMenuScrollOverlay(in: host),
          let scrollView = overlay.targetScrollViewForTesting
    else {
        return
    }
    scrollView.contentView.scroll(to: CGPoint(x: 0, y: y))
    scrollView.reflectScrolledClipView(scrollView.contentView)
    for _ in 0..<6 {
        host.layoutSubtreeIfNeeded()
        await Task.yield()
    }
}

@MainActor
private func firstCardMenuScrollOverlay(
    in root: NSView
) -> WorkbenchScrollViewOverlayView? {
    for subview in root.subviews {
        if let match = subview as? WorkbenchScrollViewOverlayView {
            return match
        }
        if let match = firstCardMenuScrollOverlay(in: subview) {
            return match
        }
    }
    return nil
}

@MainActor
@Test
func libraryCardMenuOpensAboveACardWithNoRoomBelowItOnScreen() async throws {
    // The anchor is 700pt down a 2400pt page shown through an 800pt window, so
    // the page has plenty of room below it and the reader has almost none.
    let (host, window, _) = await hostCardMenu(anchor: CGPoint(x: 100, y: 700))
    defer { window.contentView = nil }

    let frame = try #require(openCardMenuFrame(in: host))
    #expect(frame.height > 0)
    #expect(frame.maxY <= 700)
}

@MainActor
@Test
func libraryCardMenuKeepsItsSideAndOffsetWhileThePageScrolls() async throws {
    let (host, window, _) = await hostCardMenu(anchor: CGPoint(x: 100, y: 700))
    defer { window.contentView = nil }

    let opened = try #require(openCardMenuFrame(in: host))
    await scrollCardMenuPage(host, to: 300)

    // The menu travels with its card, which here means it does not move within
    // the page at all. Re-deciding would drop it below the anchor, because
    // scrolling puts room under it.
    let afterScroll = try #require(openCardMenuFrame(in: host))
    #expect(abs(afterScroll.minY - opened.minY) < 0.5)
    #expect(abs(afterScroll.minX - opened.minX) < 0.5)
}

@MainActor
@Test
func libraryCardMenuKeepsItsSideAfterBeingOpenedASecondTime() async throws {
    let (host, window, opener) = await hostCardMenu(anchor: CGPoint(x: 100, y: 700))
    defer { window.contentView = nil }

    // Opened again on another card, the way a reader moves from one cover to the
    // next. The second menu holds the same items, so it is exactly the same size.
    opener.open?(opener.items, CGPoint(x: 200, y: 720))
    for _ in 0..<6 {
        host.layoutSubtreeIfNeeded()
        await Task.yield()
    }

    let opened = try #require(openCardMenuFrame(in: host))
    #expect(opened.maxY <= 720)

    await scrollCardMenuPage(host, to: 300)
    let afterScroll = try #require(openCardMenuFrame(in: host))
    #expect(abs(afterScroll.minY - opened.minY) < 0.5)
}

@MainActor
@Test
func libraryCardMenuLeavesTheViewportWithItsCard() async throws {
    let (host, window, _) = await hostCardMenu(anchor: CGPoint(x: 100, y: 700))
    defer { window.contentView = nil }

    let opened = try #require(openCardMenuFrame(in: host))
    await scrollCardMenuPage(host, to: 1_500)

    let afterScroll = try #require(openCardMenuFrame(in: host))
    #expect(abs(afterScroll.minY - opened.minY) < 0.5)
}

@MainActor
@Test
func libraryCardMenuOpenedOnAScrolledPageKeepsItsSide() async throws {
    let (host, window, opener) = await hostCardMenu(anchor: CGPoint(x: 100, y: 700))
    defer { window.contentView = nil }

    await scrollCardMenuPage(host, to: 400)
    opener.open?(opener.items, CGPoint(x: 150, y: 1_150))
    for _ in 0..<6 {
        host.layoutSubtreeIfNeeded()
        await Task.yield()
    }

    // The window onto the page is 400...1200, so the anchor has almost nothing
    // below it on screen even though the page runs on to 2400.
    let opened = try #require(openCardMenuFrame(in: host))
    #expect(opened.maxY <= 1_150)

    await scrollCardMenuPage(host, to: 700)
    let afterScroll = try #require(openCardMenuFrame(in: host))
    #expect(abs(afterScroll.minY - opened.minY) < 0.5)
}
