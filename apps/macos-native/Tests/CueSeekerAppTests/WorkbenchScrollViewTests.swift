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
@Test
func workbenchScrollViewUsesIndependentRealMetricsForBothAxes() async throws {
    let host = NSHostingView(
        rootView: WorkbenchScrollView([.vertical, .horizontal]) {
            Color.clear.frame(width: 900, height: 700)
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
    #expect(overlay.presentationProvider()?.vertical != nil)
    #expect(overlay.presentationProvider()?.horizontal != nil)

    overlay.onDrag(TableScrollbarDragEvent(
        axis: .horizontal,
        phase: .changed,
        positionFraction: 0.25
    ))
    overlay.onDrag(TableScrollbarDragEvent(
        axis: .vertical,
        phase: .changed,
        positionFraction: 0.75
    ))

    let presentation = try #require(overlay.presentationProvider())
    let horizontal = try #require(presentation.horizontal)
    let vertical = try #require(presentation.vertical)
    #expect(abs(horizontal.positionFraction - 0.25) < 0.01)
    #expect(abs(vertical.positionFraction - 0.75) < 0.01)
}

@MainActor
@Test
func workbenchScrollViewPreservesScrollViewReaderPositioning() async throws {
    let host = NSHostingView(
        rootView: WorkbenchScrollViewReaderFixture()
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
    try? await Task.sleep(for: .milliseconds(50))
    await settleWorkbenchScrollView(host)

    let overlay = try #require(
        firstWorkbenchSubview(
            of: WorkbenchScrollViewOverlayView.self,
            in: host
        )
    )
    let vertical = try #require(overlay.presentationProvider()?.vertical)
    #expect(vertical.positionFraction > 0.9)
}

@MainActor
@Test
func workbenchScrollViewRevealsTargetsAtTheNearestEdgeWithoutCentering()
    async throws
{
    let host = NSHostingView(
        rootView: WorkbenchScrollViewNearestEdgeFixture()
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
    try? await Task.sleep(for: .milliseconds(50))
    await settleWorkbenchScrollView(host)

    let overlay = try #require(
        firstWorkbenchSubview(
            of: WorkbenchScrollViewOverlayView.self,
            in: host
        )
    )
    let scrollView = try #require(overlay.targetScrollViewForTesting)
    #expect(abs(scrollView.contentView.bounds.origin.y - 640) < 2)
}

@MainActor
@Test
func workbenchScrollViewDoesNotMoveForAnAlreadyVisibleTarget() async throws {
    let host = NSHostingView(
        rootView: WorkbenchScrollViewVisibleTargetFixture()
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
    try? await Task.sleep(for: .milliseconds(80))
    await settleWorkbenchScrollView(host)

    let overlay = try #require(
        firstWorkbenchSubview(
            of: WorkbenchScrollViewOverlayView.self,
            in: host
        )
    )
    let scrollView = try #require(overlay.targetScrollViewForTesting)
    #expect(abs(scrollView.contentView.bounds.origin.y - 600) < 2)
}

private struct WorkbenchScrollViewReaderFixture: View {
    var body: some View {
        ScrollViewReader { proxy in
            WorkbenchScrollView {
                VStack(spacing: 0) {
                    Color.clear.frame(height: 800)
                    Color.clear
                        .frame(height: 40)
                        .id("target")
                }
                .frame(maxWidth: .infinity)
            }
            .task {
                await Task.yield()
                proxy.scrollTo("target", anchor: .bottom)
            }
        }
    }
}

private struct WorkbenchScrollViewNearestEdgeFixture: View {
    var body: some View {
        ScrollViewReader { proxy in
            WorkbenchScrollView {
                VStack(spacing: 0) {
                    Color.clear.frame(height: 800)
                    Color.clear
                        .frame(height: 40)
                        .id("target")
                    Color.clear.frame(height: 800)
                }
                .frame(maxWidth: .infinity)
            }
            .task {
                await Task.yield()
                proxy.scrollTo("target")
            }
        }
    }
}

private struct WorkbenchScrollViewVisibleTargetFixture: View {
    var body: some View {
        ScrollViewReader { proxy in
            WorkbenchScrollView {
                VStack(spacing: 0) {
                    Color.clear.frame(height: 600)
                    Color.clear
                        .frame(height: 1)
                        .id("anchor")
                    Color.clear.frame(height: 49)
                    Color.clear
                        .frame(height: 40)
                        .id("visible")
                    Color.clear.frame(height: 800)
                }
                .frame(maxWidth: .infinity)
            }
            .task {
                await Task.yield()
                proxy.scrollTo("anchor", anchor: .top)
                try? await Task.sleep(for: .milliseconds(20))
                proxy.scrollTo("visible")
            }
        }
    }
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
