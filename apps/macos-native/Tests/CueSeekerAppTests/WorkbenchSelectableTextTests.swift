import AppKit
import SwiftUI
import Testing
@testable import CueSeekerApp

@Suite(.serialized)
@MainActor
struct WorkbenchSelectableTextTests {
    private func makeTestWindow(
        size: CGSize = CGSize(width: 360, height: 120)
    ) -> (CueSeekerMainWindow, NSView) {
        _ = NSApplication.shared
        let window = CueSeekerMainWindow(
            contentRect: CGRect(origin: .zero, size: size),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        let rootView = NSView(frame: CGRect(origin: .zero, size: size))
        window.contentView = rootView
        return (window, rootView)
    }

    private func makeMouseEvent(
        type: NSEvent.EventType,
        locationInWindow: CGPoint,
        clickCount: Int = 1,
        windowNumber: Int = 0
    ) -> NSEvent {
        NSEvent.mouseEvent(
            with: type,
            location: locationInWindow,
            modifierFlags: [],
            timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: windowNumber,
            context: nil,
            eventNumber: 1,
            clickCount: clickCount,
            pressure: type == .leftMouseUp ? 0 : 1
        )!
    }

    @Test
    func dragDoubleAndTripleClickSelectTextAndCopyWritesToPasteboard() {
        WorkbenchStaticTextSelectionCoordinator.shared.clearSelection()
        defer { WorkbenchStaticTextSelectionCoordinator.shared.clearSelection() }

        let (window, rootView) = makeTestWindow()
        let textView = WorkbenchSelectableTextNSView(
            frame: CGRect(x: 20, y: 20, width: 260, height: 24)
        )
        textView.configure(
            text: "Episode_01_Final.mkv",
            font: .systemFont(ofSize: 13, weight: .regular),
            textColor: .labelColor,
            alignment: .left,
            lineLimit: 1,
            truncatesTail: true,
            isSelectable: true,
            preferredPointerShape: .iBeam,
            showsUnderline: false,
            onTap: nil,
            interfaceLayerContext: InterfaceLayerContext()
        )
        rootView.addSubview(textView)
        rootView.layoutSubtreeIfNeeded()

        // 1. Double-click selects word and copies to pasteboard.
        let wordPoint = textView.convert(CGPoint(x: 16, y: 10), to: nil)
        textView.mouseDown(
            with: makeMouseEvent(
                type: .leftMouseDown,
                locationInWindow: wordPoint,
                clickCount: 2,
                windowNumber: window.windowNumber
            )
        )
        textView.mouseUp(
            with: makeMouseEvent(
                type: .leftMouseUp,
                locationInWindow: wordPoint,
                clickCount: 2,
                windowNumber: window.windowNumber
            )
        )
        #expect(textView.hasSelection)
        #expect(textView.selectedText?.isEmpty == false)

        // 2. Triple-click selects the entire string and copies via coordinator.
        textView.mouseDown(
            with: makeMouseEvent(
                type: .leftMouseDown,
                locationInWindow: wordPoint,
                clickCount: 3,
                windowNumber: window.windowNumber
            )
        )
        textView.mouseUp(
            with: makeMouseEvent(
                type: .leftMouseUp,
                locationInWindow: wordPoint,
                clickCount: 3,
                windowNumber: window.windowNumber
            )
        )
        #expect(textView.selectedText == "Episode_01_Final.mkv")

        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally() }
        #expect(WorkbenchStaticTextSelectionCoordinator.shared.copyActiveSelection(to: pasteboard))
        #expect(pasteboard.string(forType: .string) == "Episode_01_Final.mkv")

        // 3. Drag selection selects partial character range.
        let dragStart = textView.convert(CGPoint(x: 2, y: 10), to: nil)
        let dragEnd = textView.convert(CGPoint(x: 55, y: 10), to: nil)
        textView.mouseDown(
            with: makeMouseEvent(
                type: .leftMouseDown,
                locationInWindow: dragStart,
                clickCount: 1,
                windowNumber: window.windowNumber
            )
        )
        textView.mouseDragged(
            with: makeMouseEvent(
                type: .leftMouseDragged,
                locationInWindow: dragEnd,
                clickCount: 1,
                windowNumber: window.windowNumber
            )
        )
        textView.mouseUp(
            with: makeMouseEvent(
                type: .leftMouseUp,
                locationInWindow: dragEnd,
                clickCount: 1,
                windowNumber: window.windowNumber
            )
        )
        #expect(textView.hasSelection)
        #expect(textView.selectedText?.hasPrefix("Epi") == true)
        #expect(textView.selectedText != "Episode_01_Final.mkv")
    }

    @Test
    func clickableStatusTextDistinguishesSingleClickFromDragAndProvidesGrabPointerShape() {
        WorkbenchStaticTextSelectionCoordinator.shared.clearSelection()
        defer { WorkbenchStaticTextSelectionCoordinator.shared.clearSelection() }

        let (window, rootView) = makeTestWindow()
        var tapCount = 0
        let statusView = WorkbenchSelectableTextNSView(
            frame: CGRect(x: 20, y: 20, width: 220, height: 22)
        )
        statusView.configure(
            text: "Last Updated 2026-11-09 21:30",
            font: .systemFont(ofSize: 13, weight: .medium),
            textColor: .secondaryLabelColor,
            alignment: .left,
            lineLimit: 1,
            truncatesTail: true,
            isSelectable: true,
            preferredPointerShape: .grab,
            showsUnderline: true,
            onTap: {
                tapCount += 1
            },
            interfaceLayerContext: InterfaceLayerContext()
        )
        rootView.addSubview(statusView)

        let clickPoint = statusView.convert(CGPoint(x: 24, y: 10), to: nil)
        #expect(statusView.pointerShape(atWindowPoint: clickPoint) == .grab)

        // Single click without drag fires onTap and leaves no selection.
        statusView.mouseDown(
            with: makeMouseEvent(
                type: .leftMouseDown,
                locationInWindow: clickPoint,
                windowNumber: window.windowNumber
            )
        )
        statusView.mouseUp(
            with: makeMouseEvent(
                type: .leftMouseUp,
                locationInWindow: clickPoint,
                windowNumber: window.windowNumber
            )
        )
        #expect(tapCount == 1)
        #expect(!statusView.hasSelection)

        // Dragging selects text and does NOT fire onTap on release.
        let dragEnd = statusView.convert(CGPoint(x: 120, y: 10), to: nil)
        statusView.mouseDown(
            with: makeMouseEvent(
                type: .leftMouseDown,
                locationInWindow: clickPoint,
                windowNumber: window.windowNumber
            )
        )
        statusView.mouseDragged(
            with: makeMouseEvent(
                type: .leftMouseDragged,
                locationInWindow: dragEnd,
                windowNumber: window.windowNumber
            )
        )
        statusView.mouseUp(
            with: makeMouseEvent(
                type: .leftMouseUp,
                locationInWindow: dragEnd,
                windowNumber: window.windowNumber
            )
        )
        #expect(tapCount == 1)
        #expect(statusView.hasSelection)
        #expect(statusView.selectedText?.isEmpty == false)
    }

    @Test
    func globalSingleSelectionClearsOnSecondViewSelectionOutsideClickMenuOpenAndLayerFreeze() {
        WorkbenchStaticTextSelectionCoordinator.shared.clearSelection()
        defer { WorkbenchStaticTextSelectionCoordinator.shared.clearSelection() }

        let (window, rootView) = makeTestWindow()
        let firstView = WorkbenchSelectableTextNSView(
            frame: CGRect(x: 20, y: 20, width: 140, height: 22)
        )
        firstView.configure(
            text: "First Value",
            font: .systemFont(ofSize: 13),
            textColor: .labelColor,
            alignment: .left,
            lineLimit: 1,
            truncatesTail: true,
            isSelectable: true,
            preferredPointerShape: .iBeam,
            showsUnderline: false,
            onTap: nil,
            interfaceLayerContext: InterfaceLayerContext()
        )
        let secondView = WorkbenchSelectableTextNSView(
            frame: CGRect(x: 20, y: 60, width: 140, height: 22)
        )
        secondView.configure(
            text: "Second Value",
            font: .systemFont(ofSize: 13),
            textColor: .labelColor,
            alignment: .left,
            lineLimit: 1,
            truncatesTail: true,
            isSelectable: true,
            preferredPointerShape: .iBeam,
            showsUnderline: false,
            onTap: nil,
            interfaceLayerContext: InterfaceLayerContext()
        )
        rootView.addSubview(firstView)
        rootView.addSubview(secondView)

        firstView.selectAllText()
        #expect(firstView.hasSelection)
        #expect(WorkbenchStaticTextSelectionCoordinator.shared.selectedText == "First Value")

        // Selecting in secondView clears firstView.
        secondView.selectAllText()
        #expect(!firstView.hasSelection)
        #expect(secondView.hasSelection)
        #expect(WorkbenchStaticTextSelectionCoordinator.shared.selectedText == "Second Value")

        // Clicking outside in window clears secondView.
        window.sendEvent(
            makeMouseEvent(
                type: .leftMouseDown,
                locationInWindow: CGPoint(x: 320, y: 100),
                windowNumber: window.windowNumber
            )
        )
        #expect(!secondView.hasSelection)
        #expect(!WorkbenchStaticTextSelectionCoordinator.shared.hasSelection)

        // Menu open notification (.cueSeekerClearTextSelection) clears selection.
        firstView.selectAllText()
        #expect(firstView.hasSelection)
        NotificationCenter.default.post(name: .cueSeekerClearTextSelection, object: nil)
        #expect(!firstView.hasSelection)

        // Freezing or covering the layer clears selection and reverts pointer shape to .arrow.
        firstView.selectAllText()
        #expect(firstView.hasSelection)
        firstView.configure(
            text: "First Value",
            font: .systemFont(ofSize: 13),
            textColor: .labelColor,
            alignment: .left,
            lineLimit: 1,
            truncatesTail: true,
            isSelectable: true,
            preferredPointerShape: .iBeam,
            showsUnderline: false,
            onTap: nil,
            interfaceLayerContext: InterfaceLayerContext(
                layer: .workbenchPage,
                coveredLayers: [.workbenchPage],
                frozenLayers: [.workbenchPage]
            )
        )
        #expect(!firstView.hasSelection)
        let firstPoint = firstView.convert(CGPoint(x: 10, y: 10), to: nil)
        #expect(firstView.pointerShape(atWindowPoint: firstPoint) == .arrow)
    }
}
