import AppKit
import SwiftUI
import Testing
@testable import CueSeekerApp

@MainActor
@Test
func subtitleTableExternalTextSelectionPolicyUsesInteractionSemantics() {
    let policy = SubtitleTableExternalTextSelectionStartPolicy(isBlocked: false)
    let allowed = SubtitleTableExternalTextSelectionStartContext(
        isInsideWindowContent: true,
        isInsideTable: false,
        isInteractive: false
    )

    #expect(policy.allowsStart(allowed))
    #expect(!policy.allowsStart(SubtitleTableExternalTextSelectionStartContext(
        isInsideWindowContent: false,
        isInsideTable: false,
        isInteractive: false
    )))
    #expect(!policy.allowsStart(SubtitleTableExternalTextSelectionStartContext(
        isInsideWindowContent: true,
        isInsideTable: true,
        isInteractive: false
    )))
    #expect(!policy.allowsStart(SubtitleTableExternalTextSelectionStartContext(
        isInsideWindowContent: true,
        isInsideTable: false,
        isInteractive: true
    )))
    #expect(!SubtitleTableExternalTextSelectionStartPolicy(isBlocked: true).allowsStart(allowed))
}

@MainActor
@Test
func subtitleTableTextSelectionHitTestingDistinguishesControlsFromPlainContent() throws {
    let plain = NSView(frame: CGRect(x: 0, y: 0, width: 40, height: 40))
    #expect(!SubtitleTableTextSelectionHitTesting.isInteractive(plain))

    let button = NSButton(frame: CGRect(x: 0, y: 0, width: 40, height: 40))
    let buttonChild = NSView(frame: button.bounds)
    button.addSubview(buttonChild)
    #expect(SubtitleTableTextSelectionHitTesting.isInteractive(button))
    #expect(SubtitleTableTextSelectionHitTesting.isInteractive(buttonChild))

    button.isEnabled = false
    #expect(!SubtitleTableTextSelectionHitTesting.isInteractive(button))
    #expect(!SubtitleTableTextSelectionHitTesting.isInteractive(buttonChild))

    let textView = NSTextView(frame: CGRect(x: 0, y: 0, width: 40, height: 40))
    textView.isSelectable = true
    #expect(SubtitleTableTextSelectionHitTesting.isInteractive(textView))

    let titlebar = DraggableNSView(frame: CGRect(x: 0, y: 0, width: 40, height: 40))
    #expect(SubtitleTableTextSelectionHitTesting.isInteractive(titlebar))

    let host = NSHostingView(
        rootView: HStack {
            Text("Count Summary")
            Button("View") {}
        }
        .frame(width: 300, height: 80)
    )
    host.frame = CGRect(x: 0, y: 0, width: 300, height: 80)
    let window = NSWindow(
        contentRect: host.frame,
        styleMask: [.borderless],
        backing: .buffered,
        defer: false
    )
    window.contentView = host
    host.layoutSubtreeIfNeeded()
    let swiftUIButton = try #require(firstDescendant(in: host, matching: { $0 is NSControl }))
    let buttonPoint = host.convert(
        CGPoint(x: swiftUIButton.bounds.midX, y: swiftUIButton.bounds.midY),
        from: swiftUIButton
    )
    #expect(SubtitleTableTextSelectionHitTesting.isInteractive(host.hitTest(buttonPoint)))
    #expect(!SubtitleTableTextSelectionHitTesting.isInteractive(host.hitTest(CGPoint(x: 4, y: 4))))

    let markedHost = NSHostingView(
        rootView: Button("Plain") {}
            .buttonStyle(.plain)
            .frame(width: 120, height: 40)
            .subtitleTableTextSelectionInteractiveRegion()
            .frame(width: 300, height: 80)
    )
    markedHost.frame = CGRect(x: 0, y: 0, width: 300, height: 80)
    let markedWindow = NSWindow(
        contentRect: markedHost.frame,
        styleMask: [.borderless],
        backing: .buffered,
        defer: false
    )
    markedWindow.contentView = markedHost
    markedHost.layoutSubtreeIfNeeded()
    let marker = try #require(firstDescendant(in: markedHost, matching: {
        $0 is SubtitleTableTextSelectionInteractiveRegionView
    }))
    let markerPoint = marker.convert(
        CGPoint(x: marker.bounds.midX, y: marker.bounds.midY),
        to: nil
    )
    let markedHitTestPoint = markedHost.superview?.convert(markerPoint, from: nil)
        ?? markedHost.convert(markerPoint, from: nil)
    #expect(SubtitleTableTextSelectionHitTesting.isInteractive(
        markedHost.hitTest(markedHitTestPoint),
        atWindowPoint: markerPoint,
        in: markedHost
    ))

    let outsideMarkerPoint = markedHost.convert(CGPoint(x: 4, y: 4), to: nil)
    #expect(!marker.convert(marker.bounds, to: nil).contains(outsideMarkerPoint))
    let outsideMarkerHitTestPoint = markedHost.superview?.convert(
        outsideMarkerPoint,
        from: nil
    ) ?? markedHost.convert(outsideMarkerPoint, from: nil)
    #expect(!SubtitleTableTextSelectionHitTesting.isInteractive(
        markedHost.hitTest(outsideMarkerHitTestPoint),
        atWindowPoint: outsideMarkerPoint,
        in: markedHost
    ))
}

@MainActor
@Test
func subtitleTableTextSelectionHitTestingUsesTopmostSemanticSurface() throws {
    let layeredHost = NSHostingView(
        rootView: ZStack(alignment: .topLeading) {
            Color.clear
                .subtitleTableTextSelectionInteractiveRegion()

            VStack(alignment: .leading, spacing: 0) {
                Button("Action") {}
                    .buttonStyle(.plain)
                    .subtitleTableTextSelectionInteractiveRegion()
                Spacer(minLength: 0)
            }
            .padding(10)
            .frame(width: 160, height: 100, alignment: .topLeading)
            .background(Color.gray.opacity(0.2))
            .subtitleTableTextSelectionNonInteractiveRegion(cornerRadius: 16)
            .offset(x: 60, y: 40)
        }
        .frame(width: 300, height: 200)
    )
    layeredHost.frame = CGRect(x: 0, y: 0, width: 300, height: 200)
    let window = NSWindow(
        contentRect: layeredHost.frame,
        styleMask: [.borderless],
        backing: .buffered,
        defer: false
    )
    window.contentView = layeredHost
    layeredHost.layoutSubtreeIfNeeded()

    let markers = descendants(in: layeredHost).compactMap {
        $0 as? SubtitleTableTextSelectionInteractiveRegionView
    }
    let passiveMarker = try #require(markers.first(where: { !$0.isActive }))
    let interactiveMarkers = markers.filter(\.isActive)
    let fullSurfaceMarker = try #require(interactiveMarkers.max(by: {
        $0.bounds.width * $0.bounds.height < $1.bounds.width * $1.bounds.height
    }))
    let actionMarker = try #require(interactiveMarkers.min(by: {
        $0.bounds.width * $0.bounds.height < $1.bounds.width * $1.bounds.height
    }))
    let passiveRect = passiveMarker.convert(passiveMarker.bounds, to: nil)
    let actionRect = actionMarker.convert(actionMarker.bounds, to: nil)
    let fullSurfaceRect = fullSurfaceMarker.convert(fullSurfaceMarker.bounds, to: nil)
    let panelBlankPoint = CGPoint(
        x: passiveRect.maxX - 4,
        y: passiveRect.midY
    )
    let roundedCornerPoint = CGPoint(
        x: passiveRect.minX + 1,
        y: passiveRect.minY + 1
    )
    let outsidePanelPoint = try #require(point(
        in: fullSurfaceRect,
        excluding: [passiveRect]
    ))

    #expect(!actionRect.contains(panelBlankPoint))
    #expect(!isInteractiveWindowPoint(
        panelBlankPoint,
        in: layeredHost
    ))
    #expect(isInteractiveWindowPoint(
        CGPoint(x: actionRect.midX, y: actionRect.midY),
        in: layeredHost
    ))
    #expect(isInteractiveWindowPoint(
        outsidePanelPoint,
        in: layeredHost
    ))
    #expect(isInteractiveWindowPoint(
        roundedCornerPoint,
        in: layeredHost
    ))
}

@MainActor
@Test
func subtitleTableExternalTextSelectionSessionArmsOutsideAndBeginsOnlyAfterEnteringTable() {
    let target = SubtitleTableExternalTextSelectionTargetSpy()
    let session = SubtitleTableExternalTextSelectionSession()
    session.bind(target)
    let start = CGPoint(x: 10, y: 200)
    let outsideTable = CGPoint(x: 8, y: 220)
    let insideBeforeThreshold = CGPoint(x: 12.5, y: 200)
    let insideTable = CGPoint(x: 80, y: 220)
    let outsideAfterSelection = CGPoint(x: 510, y: 260)

    #expect(session.arm(startWindowPoint: start))
    #expect(session.phase == .armed)
    #expect(!session.drag(windowPoint: outsideTable))
    #expect(session.phase == .armed)
    #expect(target.beginCalls.isEmpty)

    #expect(!session.drag(windowPoint: insideBeforeThreshold))
    #expect(session.phase == .armed)
    #expect(target.beginCalls.isEmpty)

    #expect(session.drag(windowPoint: insideTable))
    #expect(session.phase == .selecting)
    #expect(target.beginCalls.count == 1)
    #expect(target.beginCalls[0].start == start)
    #expect(target.beginCalls[0].current == insideTable)

    #expect(session.drag(windowPoint: outsideAfterSelection))
    #expect(target.updatePoints == [outsideAfterSelection])
    #expect(session.end(windowPoint: outsideAfterSelection))
    #expect(target.endPoints == [outsideAfterSelection])
    #expect(session.phase == .idle)
}

@MainActor
@Test
func subtitleTableExternalTextSelectionSessionEndsArmedGestureWithoutStartingSelection() {
    let target = SubtitleTableExternalTextSelectionTargetSpy()
    let session = SubtitleTableExternalTextSelectionSession()
    session.bind(target)

    #expect(session.arm(startWindowPoint: CGPoint(x: 4, y: 200)))
    #expect(!session.end(windowPoint: CGPoint(x: 8, y: 210)))
    #expect(session.phase == .idle)
    #expect(target.beginCalls.isEmpty)
    #expect(target.endPoints.isEmpty)
}

@MainActor
@Test
func subtitleTableExternalTextSelectionSessionRejectsUnavailableTargetAndUnbindsByIdentity() {
    let first = SubtitleTableExternalTextSelectionTargetSpy()
    let second = SubtitleTableExternalTextSelectionTargetSpy()
    let session = SubtitleTableExternalTextSelectionSession()
    session.bind(first)
    first.canBegin = false

    #expect(!session.arm(startWindowPoint: .zero))
    first.canBegin = true
    first.windowRect = nil
    #expect(!session.arm(startWindowPoint: .zero))

    session.bind(second)
    session.unbind(first)
    #expect(session.arm(startWindowPoint: CGPoint(x: 4, y: 200)))
    #expect(session.drag(windowPoint: CGPoint(x: 80, y: 220)))
    session.unbind(second)
    #expect(second.cancelCount == 1)
    #expect(session.phase == .idle)
    #expect(session.targetWindowRect == nil)
}

@MainActor
@Test
func subtitleTableExternalTextSelectionMonitorCancelsForBlockedOrDetachedLifecycle() {
    let readyPolicy = SubtitleTableExternalTextSelectionStartPolicy(isBlocked: false)
    let blockedPolicy = SubtitleTableExternalTextSelectionStartPolicy(isBlocked: true)
    let target = SubtitleTableExternalTextSelectionTargetSpy()
    let session = SubtitleTableExternalTextSelectionSession()
    let monitor = SubtitleTableExternalTextSelectionEventMonitor.MonitoringView()
    session.bind(target)
    monitor.update(session: session, startPolicy: readyPolicy)
    #expect(session.arm(startWindowPoint: CGPoint(x: 4, y: 200)))
    #expect(session.drag(windowPoint: CGPoint(x: 80, y: 220)))

    monitor.update(session: session, startPolicy: blockedPolicy)
    #expect(session.phase == .idle)
    #expect(target.cancelCount == 1)

    monitor.update(session: session, startPolicy: readyPolicy)
    #expect(session.arm(startWindowPoint: CGPoint(x: 4, y: 200)))
    #expect(session.drag(windowPoint: CGPoint(x: 80, y: 220)))
    monitor.viewDidMoveToWindow()
    #expect(session.phase == .idle)
    #expect(target.cancelCount == 2)
}

@MainActor
@Test
func subtitleTableExternalTextSelectionMonitorRoutesWindowCoordinatesWithoutTakingControls() throws {
    let contentFrame = CGRect(x: 0, y: 0, width: 500, height: 500)
    let tableFrame = CGRect(x: 120, y: 20, width: 368, height: 280)
    let countFrame = CGRect(x: 120, y: 330, width: 100, height: 28)
    let actionFrame = CGRect(x: 240, y: 330, width: 100, height: 28)
    let titlebarFrame = CGRect(x: 0, y: 455, width: 500, height: 45)
    let policy = SubtitleTableExternalTextSelectionStartPolicy(isBlocked: false)
    let target = SubtitleTableExternalTextSelectionTargetSpy()
    let session = SubtitleTableExternalTextSelectionSession()
    let monitor = SubtitleTableExternalTextSelectionEventMonitor.MonitoringView(
        frame: contentFrame
    )
    let window = NSWindow(
        contentRect: contentFrame,
        styleMask: [.borderless],
        backing: .buffered,
        defer: false
    )
    window.contentView = monitor
    monitor.frame = contentFrame
    let countSummary = NSView()
    countSummary.frame = countFrame
    monitor.addSubview(countSummary)
    let actionTarget = SubtitleTableExternalTextSelectionControlTarget()
    let actionButton = NSButton(
        title: "View",
        target: actionTarget,
        action: #selector(SubtitleTableExternalTextSelectionControlTarget.activate)
    )
    actionButton.frame = actionFrame
    monitor.addSubview(actionButton)
    let titlebar = DraggableNSView(frame: titlebarFrame)
    monitor.addSubview(titlebar)
    target.windowRect = monitor.convert(tableFrame, to: nil)
    session.bind(target)
    monitor.update(session: session, startPolicy: policy)
    defer { monitor.tearDown() }

    #expect(monitor.startContextForTesting(
        atWindowPoint: monitor.convert(
            CGPoint(x: actionFrame.midX, y: actionFrame.midY),
            to: nil
        )
    )?.isInteractive == true)
    #expect(monitor.startContextForTesting(
        atWindowPoint: monitor.convert(
            CGPoint(x: titlebarFrame.midX, y: titlebarFrame.midY),
            to: nil
        )
    )?.isInteractive == true)

    for allowedPoint in [
        CGPoint(x: countFrame.midX, y: countFrame.midY),
        CGPoint(x: countFrame.minX - 12, y: countFrame.midY),
        CGPoint(x: 30, y: 350),
        CGPoint(x: 380, y: 344),
    ] {
        monitor.routeForTesting(externalSelectionMouseEvent(
            type: .leftMouseDown,
            localPoint: allowedPoint,
            in: monitor,
            window: window
        ))
        #expect(session.phase == .armed)
        monitor.routeForTesting(externalSelectionMouseEvent(
            type: .leftMouseUp,
            localPoint: allowedPoint,
            in: monitor,
            window: window
        ))
        #expect(session.phase == .idle)
    }

    for blockedPoint in [
        CGPoint(x: actionFrame.midX, y: actionFrame.midY),
        CGPoint(x: titlebarFrame.midX, y: titlebarFrame.midY),
        CGPoint(x: tableFrame.midX, y: tableFrame.midY),
    ] {
        monitor.routeForTesting(externalSelectionMouseEvent(
            type: .leftMouseDown,
            localPoint: blockedPoint,
            in: monitor,
            window: window
        ))
        #expect(session.phase == .idle)
    }

    let countPoint = CGPoint(x: countFrame.midX, y: countFrame.midY)
    monitor.routeForTesting(externalSelectionMouseEvent(
        type: .leftMouseDown,
        localPoint: countPoint,
        in: monitor,
        window: window
    ))
    monitor.routeForTesting(externalSelectionMouseEvent(
        type: .leftMouseDragged,
        localPoint: CGPoint(x: countPoint.x + 10, y: countPoint.y),
        in: monitor,
        window: window
    ))
    #expect(session.phase == .armed)
    monitor.routeForTesting(externalSelectionMouseEvent(
        type: .leftMouseDragged,
        localPoint: CGPoint(x: tableFrame.midX, y: tableFrame.midY),
        in: monitor,
        window: window
    ))
    #expect(session.phase == .selecting)
    #expect(target.beginCalls.count == 1)
    monitor.routeForTesting(externalSelectionMouseEvent(
        type: .leftMouseUp,
        localPoint: CGPoint(x: tableFrame.midX, y: tableFrame.midY),
        in: monitor,
        window: window
    ))
    #expect(session.phase == .idle)
    #expect(target.endPoints.count == 1)

    #expect(session.arm(startWindowPoint: monitor.convert(countPoint, to: nil)))
    let otherWindow = NSWindow(
        contentRect: CGRect(x: 0, y: 0, width: 100, height: 100),
        styleMask: [.borderless],
        backing: .buffered,
        defer: false
    )
    monitor.routeForTesting(NSEvent.mouseEvent(
        with: .leftMouseDown,
        location: .zero,
        modifierFlags: [],
        timestamp: 0,
        windowNumber: otherWindow.windowNumber,
        context: nil,
        eventNumber: 0,
        clickCount: 1,
        pressure: 1
    )!)
    #expect(session.phase == .idle)
    #expect(target.beginCalls.count == 1)
}

@MainActor
private final class SubtitleTableExternalTextSelectionTargetSpy: SubtitleTableExternalTextSelectionTarget {
    var windowRect: CGRect? = CGRect(x: 12, y: 140, width: 476, height: 340)
    var canBegin = true
    var beginResult = true
    var updateResult = true
    var endResult = true
    private(set) var beginCalls: [(start: CGPoint, current: CGPoint)] = []
    private(set) var updatePoints: [CGPoint] = []
    private(set) var endPoints: [CGPoint] = []
    private(set) var cancelCount = 0

    var externalTextSelectionWindowRect: CGRect? {
        windowRect
    }

    var canBeginExternalTextSelection: Bool {
        canBegin
    }

    func beginExternalTextSelection(
        startWindowPoint: CGPoint,
        currentWindowPoint: CGPoint
    ) -> Bool {
        beginCalls.append((startWindowPoint, currentWindowPoint))
        return beginResult
    }

    func updateExternalTextSelection(windowPoint: CGPoint) -> Bool {
        updatePoints.append(windowPoint)
        return updateResult
    }

    func endExternalTextSelection(windowPoint: CGPoint) -> Bool {
        endPoints.append(windowPoint)
        return endResult
    }

    func cancelExternalTextSelection() {
        cancelCount += 1
    }
}

@MainActor
private final class SubtitleTableExternalTextSelectionControlTarget: NSObject {
    @objc func activate() {}
}

@MainActor
private func firstDescendant(
    in root: NSView,
    matching predicate: (NSView) -> Bool
) -> NSView? {
    for subview in root.subviews {
        if predicate(subview) {
            return subview
        }
        if let match = firstDescendant(in: subview, matching: predicate) {
            return match
        }
    }
    return nil
}

@MainActor
private func descendants(in root: NSView) -> [NSView] {
    root.subviews.flatMap { [$0] + descendants(in: $0) }
}

@MainActor
private func point(in rect: CGRect, excluding excludedRects: [CGRect]) -> CGPoint? {
    for x in stride(from: rect.minX + 2, through: rect.maxX - 2, by: 4) {
        for y in stride(from: rect.minY + 2, through: rect.maxY - 2, by: 4) {
            let candidate = CGPoint(x: x, y: y)
            if !excludedRects.contains(where: { $0.contains(candidate) }) {
                return candidate
            }
        }
    }
    return nil
}

@MainActor
private func isInteractiveWindowPoint(
    _ point: CGPoint,
    in root: NSView
) -> Bool {
    let hitTestPoint = root.superview?.convert(point, from: nil)
        ?? root.convert(point, from: nil)
    return SubtitleTableTextSelectionHitTesting.isInteractive(
        root.hitTest(hitTestPoint),
        atWindowPoint: point,
        in: root
    )
}

@MainActor
private func externalSelectionMouseEvent(
    type: NSEvent.EventType,
    localPoint: CGPoint,
    in view: NSView,
    window: NSWindow
) -> NSEvent {
    NSEvent.mouseEvent(
        with: type,
        location: view.convert(localPoint, to: nil),
        modifierFlags: [],
        timestamp: 0,
        windowNumber: window.windowNumber,
        context: nil,
        eventNumber: 0,
        clickCount: 1,
        pressure: 1
    )!
}
