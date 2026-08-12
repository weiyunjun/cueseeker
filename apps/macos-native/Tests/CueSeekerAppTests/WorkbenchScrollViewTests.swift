import AppKit
import SwiftUI
import Testing
@testable import CueSeekerApp

@MainActor
@Test
func workbenchScrollViewBindsOverlayToItsExactViewport() async throws {
    let host = NSHostingView(
        rootView: WorkbenchScrollView {
            Color.clear
                .frame(maxWidth: .infinity)
                .frame(height: 900)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    )
    host.frame = CGRect(x: 0, y: 0, width: 300, height: 200)
    let window = NSWindow(
        contentRect: host.frame,
        styleMask: [.borderless],
        backing: .buffered,
        defer: false
    )
    window.contentView = host

    await settleWorkbenchScrollView(host)

    let overlay = try #require(
        firstWorkbenchSubview(
            of: WorkbenchScrollViewOverlayView.self,
            in: host
        )
    )
    let scrollView = try #require(overlay.targetScrollViewForTesting)

    #expect(!scrollView.hasVerticalScroller)
    #expect(!scrollView.hasHorizontalScroller)
    #expect(overlay.isPresented)
    #expect(overlay.presentationProvider()?.vertical != nil)
    expectSameWorkbenchRect(
        overlay.convert(overlay.bounds, to: host),
        scrollView.convert(scrollView.bounds, to: host)
    )
    #expect(!isWorkbenchDescendant(overlay, of: scrollView))

    overlay.onDrag(TableScrollbarDragEvent(
        axis: .vertical,
        phase: .changed,
        positionFraction: 0.5
    ))
    let draggedPresentation = try #require(
        overlay.presentationProvider()?.vertical
    )
    #expect(abs(draggedPresentation.positionFraction - 0.5) < 0.01)

    window.setContentSize(NSSize(width: 520, height: 260))
    host.frame = CGRect(x: 0, y: 0, width: 520, height: 260)
    await settleWorkbenchScrollView(host)

    expectSameWorkbenchRect(
        overlay.convert(overlay.bounds, to: host),
        scrollView.convert(scrollView.bounds, to: host)
    )
}

@MainActor
@Test
func workbenchScrollViewOmitsThumbWithoutRealOverflow() async throws {
    let host = NSHostingView(
        rootView: WorkbenchScrollView {
            Color.clear
                .frame(maxWidth: .infinity)
                .frame(height: 80)
        }
        .frame(width: 300, height: 200)
    )
    host.frame = CGRect(x: 0, y: 0, width: 300, height: 200)
    let window = NSWindow(
        contentRect: host.frame,
        styleMask: [.borderless],
        backing: .buffered,
        defer: false
    )
    window.contentView = host

    await settleWorkbenchScrollView(host)

    let overlay = try #require(
        firstWorkbenchSubview(
            of: WorkbenchScrollViewOverlayView.self,
            in: host
        )
    )
    #expect(overlay.targetScrollViewForTesting != nil)
    #expect(!overlay.isPresented)
    #expect(overlay.presentationProvider()?.vertical == nil)
    #expect(overlay.presentationProvider()?.horizontal == nil)
}

@MainActor
private func settleWorkbenchScrollView(_ host: NSView) async {
    for _ in 0..<3 {
        host.layoutSubtreeIfNeeded()
        await Task.yield()
    }
}

@MainActor
private func firstWorkbenchSubview<ViewType: NSView>(
    of type: ViewType.Type,
    in root: NSView
) -> ViewType? {
    for subview in root.subviews {
        if let match = subview as? ViewType {
            return match
        }
        if let match = firstWorkbenchSubview(of: type, in: subview) {
            return match
        }
    }
    return nil
}

@MainActor
private func isWorkbenchDescendant(_ view: NSView, of ancestor: NSView) -> Bool {
    var current = view.superview
    while let candidate = current {
        if candidate === ancestor {
            return true
        }
        current = candidate.superview
    }
    return false
}

private func expectSameWorkbenchRect(
    _ actual: CGRect,
    _ expected: CGRect,
    tolerance: CGFloat = 0.5
) {
    #expect(abs(actual.minX - expected.minX) <= tolerance)
    #expect(abs(actual.minY - expected.minY) <= tolerance)
    #expect(abs(actual.width - expected.width) <= tolerance)
    #expect(abs(actual.height - expected.height) <= tolerance)
}
