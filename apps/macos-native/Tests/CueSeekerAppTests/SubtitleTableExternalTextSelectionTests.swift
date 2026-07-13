import AppKit
import Testing
@testable import CueSeekerApp

@MainActor
@Test
func subtitleTableExternalTextSelectionPolicyAllowsOnlyExplicitWorkbenchBackground() {
    let tableFrame = CGRect(x: 12, y: 140, width: 476, height: 340)
    let policy = SubtitleTableExternalTextSelectionStartPolicy(
        allowedFrame: CGRect(x: 0, y: 0, width: 500, height: 500),
        excludedFrames: [
            CGRect(x: 0, y: 0, width: 500, height: 80),
            CGRect(x: 12, y: 100, width: 80, height: 28),
            CGRect(x: 100, y: 100, width: 180, height: 28),
            CGRect(x: 420, y: 100, width: 68, height: 28),
        ],
        requiredFramesAreReady: true,
        isBlocked: false
    )

    #expect(policy.allowsStart(at: CGPoint(x: 350, y: 114), tableFrame: tableFrame))
    #expect(policy.allowsStart(at: CGPoint(x: 6, y: 200), tableFrame: tableFrame))
    #expect(!policy.allowsStart(at: CGPoint(x: 250, y: 40), tableFrame: tableFrame))
    #expect(!policy.allowsStart(at: CGPoint(x: 40, y: 114), tableFrame: tableFrame))
    #expect(!policy.allowsStart(at: CGPoint(x: 160, y: 114), tableFrame: tableFrame))
    #expect(!policy.allowsStart(at: CGPoint(x: 450, y: 114), tableFrame: tableFrame))
    #expect(!policy.allowsStart(at: CGPoint(x: 250, y: 200), tableFrame: tableFrame))
    #expect(!policy.allowsStart(at: CGPoint(x: 520, y: 114), tableFrame: tableFrame))
}

@MainActor
@Test
func subtitleTableExternalTextSelectionPolicyPassesThroughUntilFramesAreReadyOrWhileBlocked() {
    let tableFrame = CGRect(x: 12, y: 140, width: 476, height: 340)
    let point = CGPoint(x: 350, y: 114)
    let missingFrames = SubtitleTableExternalTextSelectionStartPolicy(
        allowedFrame: CGRect(x: 0, y: 0, width: 500, height: 500),
        excludedFrames: [],
        requiredFramesAreReady: false,
        isBlocked: false
    )
    let blocked = SubtitleTableExternalTextSelectionStartPolicy(
        allowedFrame: CGRect(x: 0, y: 0, width: 500, height: 500),
        excludedFrames: [],
        requiredFramesAreReady: true,
        isBlocked: true
    )

    #expect(!missingFrames.allowsStart(at: point, tableFrame: tableFrame))
    #expect(!blocked.allowsStart(at: point, tableFrame: tableFrame))
    #expect(!blocked.allowsStart(at: point, tableFrame: nil))
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
    let readyPolicy = SubtitleTableExternalTextSelectionStartPolicy(
        allowedFrame: CGRect(x: 0, y: 0, width: 500, height: 500),
        excludedFrames: [],
        requiredFramesAreReady: true,
        isBlocked: false
    )
    let blockedPolicy = SubtitleTableExternalTextSelectionStartPolicy(
        allowedFrame: CGRect(x: 0, y: 0, width: 500, height: 500),
        excludedFrames: [],
        requiredFramesAreReady: true,
        isBlocked: true
    )
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
    let allowedFrame = CGRect(x: 0, y: 0, width: 500, height: 500)
    let tableFrame = CGRect(x: 12, y: 140, width: 476, height: 340)
    let countFrame = CGRect(x: 12, y: 100, width: 80, height: 28)
    let actionFrame = CGRect(x: 100, y: 100, width: 180, height: 28)
    let viewFrame = CGRect(x: 420, y: 100, width: 68, height: 28)
    let policy = SubtitleTableExternalTextSelectionStartPolicy(
        allowedFrame: allowedFrame,
        excludedFrames: [
            CGRect(x: 0, y: 0, width: 500, height: 80),
            countFrame,
            actionFrame,
            viewFrame,
        ],
        requiredFramesAreReady: true,
        isBlocked: false
    )
    let target = SubtitleTableExternalTextSelectionTargetSpy()
    let session = SubtitleTableExternalTextSelectionSession()
    let monitor = SubtitleTableExternalTextSelectionEventMonitor.MonitoringView(
        frame: allowedFrame
    )
    let window = NSWindow(
        contentRect: allowedFrame,
        styleMask: [.borderless],
        backing: .buffered,
        defer: false
    )
    window.contentView = monitor
    monitor.frame = allowedFrame
    target.windowRect = monitor.convert(tableFrame, to: nil)
    session.bind(target)
    monitor.update(session: session, startPolicy: policy)
    defer { monitor.tearDown() }

    let utilityGap = CGPoint(x: 350, y: 114)
    monitor.routeForTesting(externalSelectionMouseEvent(
        type: .leftMouseDown,
        localPoint: utilityGap,
        in: monitor,
        window: window
    ))
    #expect(session.phase == .armed)
    monitor.routeForTesting(externalSelectionMouseEvent(
        type: .leftMouseUp,
        localPoint: utilityGap,
        in: monitor,
        window: window
    ))
    #expect(session.phase == .idle)

    for excludedPoint in [
        CGPoint(x: countFrame.midX, y: countFrame.midY),
        CGPoint(x: actionFrame.midX, y: actionFrame.midY),
        CGPoint(x: viewFrame.midX, y: viewFrame.midY),
        CGPoint(x: tableFrame.midX, y: tableFrame.midY),
    ] {
        monitor.routeForTesting(externalSelectionMouseEvent(
            type: .leftMouseDown,
            localPoint: excludedPoint,
            in: monitor,
            window: window
        ))
        #expect(session.phase == .idle)
    }

    monitor.routeForTesting(externalSelectionMouseEvent(
        type: .leftMouseDown,
        localPoint: utilityGap,
        in: monitor,
        window: window
    ))
    monitor.routeForTesting(externalSelectionMouseEvent(
        type: .leftMouseDragged,
        localPoint: CGPoint(x: 360, y: 120),
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

    #expect(session.arm(startWindowPoint: monitor.convert(utilityGap, to: nil)))
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
