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

        // Underline rect at 2x Retina scale is positioned below the text vertical center (near bottom baseline).
        let underlineRects = statusView.underlineRects(backingScaleFactor: 2.0)
        #expect(underlineRects.count == 1)
        if let underlineRect = underlineRects.first {
            #expect(underlineRect.minY > statusView.bounds.midY + 4)
        }

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

        // 3. Clicking outside in window clears secondView (and sends mouseUp to end external drag session).
        window.sendEvent(
            makeMouseEvent(
                type: .leftMouseDown,
                locationInWindow: CGPoint(x: 320, y: 100),
                windowNumber: window.windowNumber
            )
        )
        window.sendEvent(
            makeMouseEvent(
                type: .leftMouseUp,
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

    @Test
    func draggingFromNonInteractiveAreaIntoAndAcrossSelectableTextProjectsStartAndSelectsCharacters() {
        WorkbenchStaticTextSelectionCoordinator.shared.clearSelection()
        defer { WorkbenchStaticTextSelectionCoordinator.shared.clearSelection() }

        let (window, rootView) = makeTestWindow()
        var tapCount = 0
        let textView = WorkbenchSelectableTextNSView(
            frame: CGRect(x: 80, y: 40, width: 200, height: 22)
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
            onTap: {
                tapCount += 1
            },
            interfaceLayerContext: InterfaceLayerContext()
        )
        rootView.addSubview(textView)
        rootView.layoutSubtreeIfNeeded()

        // 1. Press in left blank margin and drag into the middle of the text.
        let outsideLeft = textView.convert(CGPoint(x: -40, y: 10), to: nil)
        let midText = textView.convert(CGPoint(x: 50, y: 10), to: nil)
        let outsideRightWithVerticalDrift = textView.convert(CGPoint(x: 240, y: -4), to: nil)

        window.sendEvent(
            makeMouseEvent(
                type: .leftMouseDown,
                locationInWindow: outsideLeft,
                windowNumber: window.windowNumber
            )
        )
        #expect(!textView.hasSelection)

        window.sendEvent(
            makeMouseEvent(
                type: .leftMouseDragged,
                locationInWindow: midText,
                windowNumber: window.windowNumber
            )
        )
        #expect(textView.hasSelection)
        #expect(textView.selectedText?.hasPrefix("Epi") == true)
        #expect(textView.selectedText != "Episode_01_Final.mkv")
        #expect(WorkbenchStaticTextSelectionCoordinator.shared.activeDraggingPointerShape == .iBeam)

        // Continue dragging past the right edge with slight vertical drift selects the full text.
        window.sendEvent(
            makeMouseEvent(
                type: .leftMouseDragged,
                locationInWindow: outsideRightWithVerticalDrift,
                windowNumber: window.windowNumber
            )
        )
        #expect(textView.selectedText == "Episode_01_Final.mkv")

        window.sendEvent(
            makeMouseEvent(
                type: .leftMouseUp,
                locationInWindow: outsideRightWithVerticalDrift,
                windowNumber: window.windowNumber
            )
        )
        #expect(textView.selectedText == "Episode_01_Final.mkv")
        #expect(WorkbenchStaticTextSelectionCoordinator.shared.activeDraggingPointerShape == nil)
        #expect(tapCount == 0)

        // 2. Fast right-to-left sweep across the entire text from right blank space to left blank space.
        let outsideRight = textView.convert(CGPoint(x: 240, y: 10), to: nil)
        window.sendEvent(
            makeMouseEvent(
                type: .leftMouseDown,
                locationInWindow: outsideRight,
                windowNumber: window.windowNumber
            )
        )
        window.sendEvent(
            makeMouseEvent(
                type: .leftMouseDragged,
                locationInWindow: outsideLeft,
                windowNumber: window.windowNumber
            )
        )
        window.sendEvent(
            makeMouseEvent(
                type: .leftMouseUp,
                locationInWindow: outsideLeft,
                windowNumber: window.windowNumber
            )
        )
        #expect(textView.selectedText == "Episode_01_Final.mkv")
        #expect(tapCount == 0)
    }

    @Test
    func multilineSelectableTextWithCustomLineHeightSizesOverlayBoundsToFullLineHeightWithoutClippingSelectionRects() {
        WorkbenchStaticTextSelectionCoordinator.shared.clearSelection()
        defer { WorkbenchStaticTextSelectionCoordinator.shared.clearSelection() }

        let cjkText = String(repeating: "这是一个列表你知道吗", count: 10)
        let font = NSFont.systemFont(
            ofSize: WorkbenchControlMetrics.redesignFontSizeBody,
            weight: .regular
        )
        let lineHeight = WorkbenchControlMetrics.redesignLineHeightCoverSummaryDescription
        let textWidth: CGFloat = 392
        let expectedHeight = WorkbenchSelectableTextNSView.measuredMultilineHeight(
            for: cjkText,
            font: font,
            lineHeight: lineHeight,
            width: textWidth
        )
        #expect(expectedHeight == lineHeight * 4)
        #expect(WorkbenchSelectableTextNSView.resolvedBaselineOffset(for: font, lineHeight: lineHeight) > 0)

        let (window, rootView) = makeTestWindow(size: CGSize(width: 440, height: 140))
        let hostingView = NSHostingView(
            rootView: WorkbenchSelectableText(
                cjkText,
                fontSize: WorkbenchControlMetrics.redesignFontSizeBody,
                weight: .regular,
                lineLimit: nil,
                lineHeight: lineHeight,
                alignment: .leading,
                isSelectable: true
            )
            .frame(width: textWidth, height: expectedHeight, alignment: .topLeading)
        )
        hostingView.frame = CGRect(x: 12, y: 8, width: textWidth, height: expectedHeight)
        rootView.addSubview(hostingView)
        rootView.layoutSubtreeIfNeeded()

        func findSelectableTextNSView(in view: NSView) -> WorkbenchSelectableTextNSView? {
            if let match = view as? WorkbenchSelectableTextNSView {
                return match
            }
            for subview in view.subviews {
                if let found = findSelectableTextNSView(in: subview) {
                    return found
                }
            }
            return nil
        }

        let selectableView = findSelectableTextNSView(in: hostingView)
        #expect(selectableView != nil)
        if let selectableView {
            _ = window
            #expect(selectableView.bounds.width == textWidth)
            #expect(selectableView.bounds.height == expectedHeight)

            selectableView.selectAllText()
            let lineRects = selectableView.lineUsedRects()
            #expect(lineRects.count == 4)
            for (index, lineRect) in lineRects.enumerated() {
                #expect(abs(lineRect.minY - CGFloat(index) * lineHeight) < 0.5)
                #expect(abs(lineRect.height - lineHeight) < 0.5)
                let clipped = lineRect.intersection(selectableView.bounds)
                #expect(abs(clipped.height - lineRect.height) < 0.1)
            }

            let selectionRects = selectableView.selectionRects(
                forUTF16Range: NSRange(location: 0, length: (cjkText as NSString).length)
            )
            #expect(!selectionRects.isEmpty)
            for rect in selectionRects {
                let clipped = rect.intersection(selectableView.bounds)
                #expect(abs(clipped.height - rect.height) < 0.1)
            }
            if let lastRect = selectionRects.last {
                #expect(abs(lastRect.maxY - expectedHeight) < 0.5)
            }
        }
    }
}
