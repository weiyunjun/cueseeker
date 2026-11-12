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
        let outsideAboveAtMidX = textView.convert(CGPoint(x: 120, y: -6), to: nil)
        let outsideRightBelowLine = textView.convert(CGPoint(x: 240, y: 26), to: nil)

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

        // Strict top clamping: coordinates strictly above first line clamp to offset 0 (no horizontal tolerance band).
        window.sendEvent(
            makeMouseEvent(
                type: .leftMouseDragged,
                locationInWindow: outsideAboveAtMidX,
                windowNumber: window.windowNumber
            )
        )
        #expect(!textView.hasSelection)

        // Dragging past the right/bottom edge clamps strictly to the end of the text.
        window.sendEvent(
            makeMouseEvent(
                type: .leftMouseDragged,
                locationInWindow: outsideRightBelowLine,
                windowNumber: window.windowNumber
            )
        )
        #expect(textView.selectedText == "Episode_01_Final.mkv")

        window.sendEvent(
            makeMouseEvent(
                type: .leftMouseUp,
                locationInWindow: outsideRightBelowLine,
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

            selectableView.clearSelection(notifyCoordinator: true)
            #expect(!selectableView.responds(to: #selector(NSResponder.selectAll(_:))))
            _ = window.makeFirstResponder(selectableView)
            #expect(!AppDelegate.canPerformSelectAll(in: window))
            #expect(!AppDelegate.performSelectAll(in: window))
            #expect(!selectableView.hasSelection)
        }
    }

    @Test
    func topLeftDiagonalDragIntoContinuousFlowProjectsInitialStartSkipsControlsAndPreservesGrabClick() {
        WorkbenchStaticTextSelectionCoordinator.shared.clearSelection()
        defer { WorkbenchStaticTextSelectionCoordinator.shared.clearSelection() }

        let (window, rootView) = makeTestWindow(size: CGSize(width: 420, height: 260))
        var pathTapCount = 0

        let coverBox = NSView(frame: CGRect(x: 16, y: 120, width: 88, height: 110))
        rootView.addSubview(coverBox)

        func makeNode(
            text: String,
            frame: CGRect,
            pointer: PointerShape = .iBeam,
            onTap: (() -> Void)? = nil
        ) -> WorkbenchSelectableTextNSView {
            let view = WorkbenchSelectableTextNSView(frame: frame)
            view.configure(
                text: text,
                font: .systemFont(ofSize: 13, weight: .regular),
                textColor: .labelColor,
                alignment: .left,
                lineLimit: 1,
                truncatesTail: true,
                isSelectable: true,
                preferredPointerShape: pointer,
                showsUnderline: false,
                onTap: onTap,
                interfaceLayerContext: InterfaceLayerContext()
            )
            rootView.addSubview(view)
            return view
        }

        let titleView = makeNode(text: "Episode 01", frame: CGRect(x: 120, y: 206, width: 220, height: 22))
        _ = makeNode(text: "Japanese · 24m", frame: CGRect(x: 120, y: 178, width: 220, height: 20))
        let pathView = makeNode(
            text: "/Media/Anime/Episode_01.mkv",
            frame: CGRect(x: 120, y: 150, width: 260, height: 20),
            pointer: .grab,
            onTap: { pathTapCount += 1 }
        )
        let progressView = makeNode(text: "52% · 12:30", frame: CGRect(x: 120, y: 122, width: 160, height: 20))

        let playButton = NSButton(title: "Play", target: nil, action: nil)
        playButton.frame = CGRect(x: 300, y: 120, width: 68, height: 28)
        rootView.addSubview(playButton)
        rootView.layoutSubtreeIfNeeded()

        // 1. Diagonal drag from top-left blank space above/left of Cover Summary into Grab path and Progress.
        let topLeftBlank = CGPoint(x: 24, y: 248)
        let overGrabPath = pathView.convert(CGPoint(x: 110, y: 10), to: nil)
        let pastBottomRight = CGPoint(x: 390, y: 96)

        window.sendEvent(makeMouseEvent(type: .leftMouseDown, locationInWindow: topLeftBlank, windowNumber: window.windowNumber))
        window.sendEvent(makeMouseEvent(type: .leftMouseDragged, locationInWindow: overGrabPath, windowNumber: window.windowNumber))

        #expect(WorkbenchStaticTextSelectionCoordinator.shared.activeDraggingPointerShape == .iBeam)
        #expect(titleView.selectedText == "Episode 01")
        #expect(WorkbenchStaticTextSelectionCoordinator.shared.selectedText?.hasPrefix("Episode 01\nJapanese · 24m\n/Media") == true)

        window.sendEvent(makeMouseEvent(type: .leftMouseDragged, locationInWindow: pastBottomRight, windowNumber: window.windowNumber))
        window.sendEvent(makeMouseEvent(type: .leftMouseUp, locationInWindow: pastBottomRight, windowNumber: window.windowNumber))

        #expect(progressView.selectedText == "52% · 12:30")
        #expect(
            WorkbenchStaticTextSelectionCoordinator.shared.selectedText
                == "Episode 01\nJapanese · 24m\n/Media/Anime/Episode_01.mkv\n52% · 12:30"
        )
        #expect(pathTapCount == 0)

        // 2. Press directly above first line at mid-X (no horizontal tolerance band above first line): starts at offset 0.
        let aboveFirstLineMidX = CGPoint(x: 210, y: 248)
        let midTitle = titleView.convert(CGPoint(x: 46, y: 10), to: nil)
        window.sendEvent(makeMouseEvent(type: .leftMouseDown, locationInWindow: aboveFirstLineMidX, windowNumber: window.windowNumber))
        window.sendEvent(makeMouseEvent(type: .leftMouseDragged, locationInWindow: midTitle, windowNumber: window.windowNumber))
        window.sendEvent(makeMouseEvent(type: .leftMouseUp, locationInWindow: midTitle, windowNumber: window.windowNumber))
        #expect(titleView.selectedText?.hasPrefix("Ep") == true)

        // 3. Stationary single click on Grab clickable path clears selection and triggers tap action.
        let clickDown = makeMouseEvent(type: .leftMouseDown, locationInWindow: overGrabPath, windowNumber: window.windowNumber)
        let clickUp = makeMouseEvent(type: .leftMouseUp, locationInWindow: overGrabPath, windowNumber: window.windowNumber)
        WorkbenchStaticTextSelectionCoordinator.shared.handleWindowLeftMouseDown(window: window, event: clickDown)
        pathView.mouseDown(with: clickDown)
        pathView.mouseUp(with: clickUp)
        _ = WorkbenchStaticTextSelectionCoordinator.shared.handleWindowLeftMouseUp(window: window, event: clickUp)
        #expect(pathTapCount == 1)
        #expect(!WorkbenchStaticTextSelectionCoordinator.shared.hasSelection)
    }

    @Test
    func draggingFromClickControlCancelsPressedStateSuppressesClickAndExemptsNativeDragControls() {
        WorkbenchStaticTextSelectionCoordinator.shared.clearSelection()
        defer { WorkbenchStaticTextSelectionCoordinator.shared.clearSelection() }

        final class ClickTrackingView: NSView {
            var isPressed = false
            var clickCount = 0

            override func mouseDown(with event: NSEvent) {
                isPressed = bounds.contains(convert(event.locationInWindow, from: nil))
            }

            override func mouseDragged(with event: NSEvent) {
                isPressed = bounds.contains(convert(event.locationInWindow, from: nil))
            }

            override func mouseUp(with event: NSEvent) {
                if isPressed && bounds.contains(convert(event.locationInWindow, from: nil)) {
                    clickCount += 1
                }
                isPressed = false
            }
        }

        final class PressProbe: ObservableObject {
            @Published var isPressed = false
        }

        struct PressableButtonHarness: View {
            @ObservedObject var probe: PressProbe
            var body: some View {
                Button(action: {}) {
                    Text("Play")
                        .frame(width: 80, height: 28)
                }
                .buttonStyle(PressableButtonStyle(isPressed: $probe.isPressed))
            }
        }

        let (window, rootView) = makeTestWindow(size: CGSize(width: 400, height: 240))
        let textView = WorkbenchSelectableTextNSView(frame: CGRect(x: 24, y: 150, width: 220, height: 24))
        textView.configure(
            text: "Selectable Summary Line",
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

        let clickControl = ClickTrackingView(frame: CGRect(x: 24, y: 90, width: 96, height: 28))
        rootView.addSubview(clickControl)

        let probe = PressProbe()
        let pressableHost = CueSeekerHostingView(rootView: PressableButtonHarness(probe: probe))
        pressableHost.frame = CGRect(x: 140, y: 90, width: 80, height: 28)
        rootView.addSubview(pressableHost)

        let nativeDragRegion = CueSeekerNativeDragRegionView(frame: CGRect(x: 24, y: 40, width: 96, height: 28))
        nativeDragRegion.isActive = true
        rootView.addSubview(nativeDragRegion)

        let titlebarDrag = DraggableNSView(frame: CGRect(x: 140, y: 40, width: 96, height: 28))
        rootView.addSubview(titlebarDrag)

        let editableField = NSTextField(frame: CGRect(x: 256, y: 40, width: 110, height: 24))
        editableField.isEditable = true
        editableField.stringValue = "Input"
        rootView.addSubview(editableField)

        rootView.layoutSubtreeIfNeeded()
        pressableHost.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.02))

        func dispatchOffscreenMouseEvent(_ event: NSEvent, to target: NSView) {
            switch event.type {
            case .leftMouseDown:
                WorkbenchStaticTextSelectionCoordinator.shared.handleWindowLeftMouseDown(window: window, event: event)
                target.mouseDown(with: event)
            case .leftMouseDragged:
                switch WorkbenchStaticTextSelectionCoordinator.shared.handleWindowLeftMouseDragged(window: window, event: event) {
                case .passthrough:
                    target.mouseDragged(with: event)
                case .consume:
                    break
                case .redirect(let redirected):
                    target.mouseDragged(with: redirected)
                }
            case .leftMouseUp:
                switch WorkbenchStaticTextSelectionCoordinator.shared.handleWindowLeftMouseUp(window: window, event: event) {
                case .passthrough:
                    target.mouseUp(with: event)
                case .consume:
                    break
                case .redirect(let redirected):
                    target.mouseUp(with: redirected)
                }
            default:
                break
            }
        }

        // 1. Plain click on ClickTrackingView without entering text still fires click.
        let buttonPoint = clickControl.convert(CGPoint(x: 48, y: 14), to: nil)
        dispatchOffscreenMouseEvent(makeMouseEvent(type: .leftMouseDown, locationInWindow: buttonPoint, windowNumber: window.windowNumber), to: clickControl)
        #expect(clickControl.isPressed)
        dispatchOffscreenMouseEvent(makeMouseEvent(type: .leftMouseUp, locationInWindow: buttonPoint, windowNumber: window.windowNumber), to: clickControl)
        #expect(!clickControl.isPressed)
        #expect(clickControl.clickCount == 1)

        // 2. Press on click control (below last text line) and drag upward into text:
        //    anchor clamps strictly to end of last line, pressed state cancels immediately, and release suppresses click.
        probe.isPressed = true
        dispatchOffscreenMouseEvent(makeMouseEvent(type: .leftMouseDown, locationInWindow: buttonPoint, windowNumber: window.windowNumber), to: clickControl)
        #expect(clickControl.isPressed)
        #expect(probe.isPressed)

        let midTextPoint = textView.convert(CGPoint(x: 60, y: 12), to: nil)
        dispatchOffscreenMouseEvent(makeMouseEvent(type: .leftMouseDragged, locationInWindow: midTextPoint, windowNumber: window.windowNumber), to: clickControl)
        RunLoop.main.run(until: Date().addingTimeInterval(0.02))

        #expect(!clickControl.isPressed)
        #expect(!probe.isPressed)
        #expect(textView.selectedText?.hasSuffix("Summary Line") == true)

        dispatchOffscreenMouseEvent(makeMouseEvent(type: .leftMouseUp, locationInWindow: buttonPoint, windowNumber: window.windowNumber), to: clickControl)
        #expect(clickControl.clickCount == 1)

        // 3. Native drag / editable controls never arm or enter static text selection when dragged across text.
        WorkbenchStaticTextSelectionCoordinator.shared.clearSelection()
        for exemptedView: NSView in [nativeDragRegion, titlebarDrag, editableField] {
            let startPoint = exemptedView.convert(
                CGPoint(x: exemptedView.bounds.midX, y: exemptedView.bounds.midY),
                to: nil
            )
            #expect(
                SubtitleTableTextSelectionHitTesting.ownsDragOrTextInputGesture(
                    exemptedView,
                    atWindowPoint: startPoint,
                    in: window
                )
            )
            window.sendEvent(makeMouseEvent(type: .leftMouseDown, locationInWindow: startPoint, windowNumber: window.windowNumber))
            window.sendEvent(makeMouseEvent(type: .leftMouseDragged, locationInWindow: midTextPoint, windowNumber: window.windowNumber))
            window.sendEvent(makeMouseEvent(type: .leftMouseUp, locationInWindow: midTextPoint, windowNumber: window.windowNumber))
            #expect(!WorkbenchStaticTextSelectionCoordinator.shared.hasSelection)
        }
    }

    @Test
    func clipboardSerializationJoinsHorizontalPeersWithTabAndVerticalRowsWithNewlineAndValidatesCopyMenu() {
        WorkbenchStaticTextSelectionCoordinator.shared.clearSelection()
        defer { WorkbenchStaticTextSelectionCoordinator.shared.clearSelection() }

        let (window, rootView) = makeTestWindow(size: CGSize(width: 400, height: 140))

        func makeCell(text: String, frame: CGRect) -> WorkbenchSelectableTextNSView {
            let view = WorkbenchSelectableTextNSView(frame: frame)
            view.configure(
                text: text,
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
            rootView.addSubview(view)
            return view
        }

        let row1Left = makeCell(text: "Location", frame: CGRect(x: 20, y: 80, width: 100, height: 22))
        let row1Right = makeCell(text: "/Users/demo/Videos", frame: CGRect(x: 140, y: 80, width: 220, height: 22))
        _ = makeCell(text: "Duration", frame: CGRect(x: 20, y: 44, width: 100, height: 22))
        let row2Right = makeCell(text: "00:24:15", frame: CGRect(x: 140, y: 44, width: 220, height: 22))
        rootView.layoutSubtreeIfNeeded()

        let copyItem = NSMenuItem(title: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        #expect(!window.validateMenuItem(copyItem))

        // 1. Selecting a single peer node emits no stray tab.
        row1Left.selectAllText()
        #expect(WorkbenchStaticTextSelectionCoordinator.shared.selectedText == "Location")
        #expect(window.validateMenuItem(copyItem))

        // 2. Dragging across two horizontal peer nodes on the same visual row joins with \t.
        let r1Start = row1Left.convert(CGPoint(x: 1, y: 10), to: nil)
        let r1End = row1Right.convert(CGPoint(x: 200, y: 10), to: nil)
        row1Left.mouseDown(with: makeMouseEvent(type: .leftMouseDown, locationInWindow: r1Start, windowNumber: window.windowNumber))
        row1Left.mouseDragged(with: makeMouseEvent(type: .leftMouseDragged, locationInWindow: r1End, windowNumber: window.windowNumber))
        row1Left.mouseUp(with: makeMouseEvent(type: .leftMouseUp, locationInWindow: r1End, windowNumber: window.windowNumber))
        #expect(WorkbenchStaticTextSelectionCoordinator.shared.selectedText == "Location\t/Users/demo/Videos")

        // 3. Dragging across both rows joins peers with \t and rows with \n.
        let r2End = row2Right.convert(CGPoint(x: 180, y: 10), to: nil)
        row1Left.mouseDown(with: makeMouseEvent(type: .leftMouseDown, locationInWindow: r1Start, windowNumber: window.windowNumber))
        row1Left.mouseDragged(with: makeMouseEvent(type: .leftMouseDragged, locationInWindow: r2End, windowNumber: window.windowNumber))
        row1Left.mouseUp(with: makeMouseEvent(type: .leftMouseUp, locationInWindow: r2End, windowNumber: window.windowNumber))

        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally() }
        #expect(WorkbenchStaticTextSelectionCoordinator.shared.copySelection(in: window, to: pasteboard))
        #expect(pasteboard.string(forType: .string) == "Location\t/Users/demo/Videos\nDuration\t00:24:15")
        #expect(window.validateMenuItem(copyItem))

        WorkbenchStaticTextSelectionCoordinator.shared.clearSelection()
        #expect(!window.validateMenuItem(copyItem))
    }

    @Test
    func truncatedEllipsisSingleLineMultiLineAndFullCopyTextRestoreUnderlyingStringWhenSelectedToEnd() {
        WorkbenchStaticTextSelectionCoordinator.shared.clearSelection()
        defer { WorkbenchStaticTextSelectionCoordinator.shared.clearSelection() }

        let (window, rootView) = makeTestWindow(size: CGSize(width: 360, height: 220))

        // 1. Single-line TextKit tail-truncated path.
        let fullPath = "/Volumes/Archive/Season_01/Episode_01_Director_Cut.mkv"
        let singleLineTruncated = WorkbenchSelectableTextNSView(frame: CGRect(x: 20, y: 170, width: 92, height: 22))
        singleLineTruncated.configure(
            text: fullPath,
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
        rootView.addSubview(singleLineTruncated)

        // 2. Multi-line TextKit tail-truncated paragraph (lineLimit: 2).
        let fullMultiline = "First line of episode synopsis with details that wrap onto a second line and continue well past the third and fourth lines."
        let multiLineTruncated = WorkbenchSelectableTextNSView(frame: CGRect(x: 20, y: 110, width: 150, height: 42))
        multiLineTruncated.configure(
            text: fullMultiline,
            font: .systemFont(ofSize: 13, weight: .regular),
            textColor: .labelColor,
            alignment: .left,
            lineLimit: 2,
            truncatesTail: true,
            isSelectable: true,
            preferredPointerShape: .iBeam,
            showsUnderline: false,
            onTap: nil,
            interfaceLayerContext: InterfaceLayerContext()
        )
        rootView.addSubview(multiLineTruncated)

        // 3. Pre-truncated Cover Summary / Excerpt cue preview with fullCopyText.
        let fullCuePreview = "#1 / 8  Opening subtitle line\nSecond subtitle line"
        let cuePreviewView = WorkbenchSelectableTextNSView(frame: CGRect(x: 20, y: 60, width: 220, height: 22))
        cuePreviewView.configure(
            text: "#1 / 8  Opening subtitle line...",
            fullCopyText: fullCuePreview,
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
        rootView.addSubview(cuePreviewView)
        rootView.layoutSubtreeIfNeeded()

        // Single-line partial drag selects prefix; dragging past ellipsis restores full path.
        let sStart = singleLineTruncated.convert(CGPoint(x: 1, y: 10), to: nil)
        let sMid = singleLineTruncated.convert(CGPoint(x: 34, y: 10), to: nil)
        let sEnd = singleLineTruncated.convert(CGPoint(x: 120, y: 10), to: nil)
        singleLineTruncated.mouseDown(with: makeMouseEvent(type: .leftMouseDown, locationInWindow: sStart, windowNumber: window.windowNumber))
        singleLineTruncated.mouseDragged(with: makeMouseEvent(type: .leftMouseDragged, locationInWindow: sMid, windowNumber: window.windowNumber))
        singleLineTruncated.mouseUp(with: makeMouseEvent(type: .leftMouseUp, locationInWindow: sMid, windowNumber: window.windowNumber))
        #expect(singleLineTruncated.selectedText != fullPath)
        #expect(singleLineTruncated.selectedText?.hasPrefix("/Vol") == true)

        singleLineTruncated.mouseDown(with: makeMouseEvent(type: .leftMouseDown, locationInWindow: sStart, windowNumber: window.windowNumber))
        singleLineTruncated.mouseDragged(with: makeMouseEvent(type: .leftMouseDragged, locationInWindow: sEnd, windowNumber: window.windowNumber))
        singleLineTruncated.mouseUp(with: makeMouseEvent(type: .leftMouseUp, locationInWindow: sEnd, windowNumber: window.windowNumber))
        #expect(singleLineTruncated.selectedText == fullPath)

        // Multi-line truncated drag to end of second visible line restores full untruncated string.
        let mStart = multiLineTruncated.convert(CGPoint(x: 1, y: 6), to: nil)
        let mEnd = multiLineTruncated.convert(CGPoint(x: 170, y: 34), to: nil)
        multiLineTruncated.mouseDown(with: makeMouseEvent(type: .leftMouseDown, locationInWindow: mStart, windowNumber: window.windowNumber))
        multiLineTruncated.mouseDragged(with: makeMouseEvent(type: .leftMouseDragged, locationInWindow: mEnd, windowNumber: window.windowNumber))
        multiLineTruncated.mouseUp(with: makeMouseEvent(type: .leftMouseUp, locationInWindow: mEnd, windowNumber: window.windowNumber))
        #expect(multiLineTruncated.selectedText == fullMultiline)

        // Pre-truncated fullCopyText: partial prefix vs full selection to visible end.
        let cStart = cuePreviewView.convert(CGPoint(x: 1, y: 10), to: nil)
        let cPrefix = cuePreviewView.convert(CGPoint(x: 38, y: 10), to: nil)
        let cEnd = cuePreviewView.convert(CGPoint(x: 240, y: 10), to: nil)
        cuePreviewView.mouseDown(with: makeMouseEvent(type: .leftMouseDown, locationInWindow: cStart, windowNumber: window.windowNumber))
        cuePreviewView.mouseDragged(with: makeMouseEvent(type: .leftMouseDragged, locationInWindow: cPrefix, windowNumber: window.windowNumber))
        cuePreviewView.mouseUp(with: makeMouseEvent(type: .leftMouseUp, locationInWindow: cPrefix, windowNumber: window.windowNumber))
        #expect(cuePreviewView.selectedText != fullCuePreview)
        #expect(cuePreviewView.selectedText?.hasPrefix("#1") == true)

        cuePreviewView.mouseDown(with: makeMouseEvent(type: .leftMouseDown, locationInWindow: cStart, windowNumber: window.windowNumber))
        cuePreviewView.mouseDragged(with: makeMouseEvent(type: .leftMouseDragged, locationInWindow: cEnd, windowNumber: window.windowNumber))
        cuePreviewView.mouseUp(with: makeMouseEvent(type: .leftMouseUp, locationInWindow: cEnd, windowNumber: window.windowNumber))
        #expect(cuePreviewView.selectedText == fullCuePreview)
    }

    @Test
    func viewportEdgeAutoScrollInScrollViewScrollsDownwardAndPreservesPinnedHeaderOrderAndInitialAnchor() {
        WorkbenchStaticTextSelectionCoordinator.shared.clearSelection()
        defer { WorkbenchStaticTextSelectionCoordinator.shared.clearSelection() }

        final class FlippedDocumentView: NSView {
            override var isFlipped: Bool { true }
        }

        let (window, rootView) = makeTestWindow(size: CGSize(width: 340, height: 180))

        let pinnedHeader = WorkbenchSelectableTextNSView(frame: CGRect(x: 20, y: 136, width: 260, height: 22))
        pinnedHeader.configure(
            text: "Pinned File Header",
            font: .systemFont(ofSize: 13, weight: .semibold),
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
        rootView.addSubview(pinnedHeader)

        let scrollView = NSScrollView(frame: CGRect(x: 20, y: 20, width: 260, height: 96))
        let documentView = FlippedDocumentView(frame: CGRect(x: 0, y: 0, width: 260, height: 240))
        var rows: [WorkbenchSelectableTextNSView] = []
        for index in 0..<10 {
            let row = WorkbenchSelectableTextNSView(
                frame: CGRect(x: 0, y: CGFloat(index) * 24, width: 260, height: 22)
            )
            row.configure(
                text: "Row \(index)",
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
            documentView.addSubview(row)
            rows.append(row)
        }
        scrollView.documentView = documentView
        rootView.addSubview(scrollView)
        rootView.layoutSubtreeIfNeeded()
        scrollView.contentView.scroll(to: .zero)
        scrollView.reflectScrolledClipView(scrollView.contentView)

        // 1. Begin drag at Row 0 start, drag into bottom edge auto-scroll zone, and step auto-scroll.
        let row0Start = rows[0].convert(CGPoint(x: 1, y: 10), to: nil)
        let scrollWindowRect = scrollView.contentView.convert(scrollView.contentView.bounds, to: nil)
        let bottomEdgeZonePoint = CGPoint(x: scrollWindowRect.maxX - 8, y: scrollWindowRect.minY + 4)

        rows[0].mouseDown(with: makeMouseEvent(type: .leftMouseDown, locationInWindow: row0Start, windowNumber: window.windowNumber))
        rows[0].mouseDragged(with: makeMouseEvent(type: .leftMouseDragged, locationInWindow: bottomEdgeZonePoint, windowNumber: window.windowNumber))

        var scrolledSteps = 0
        for _ in 0..<12 {
            if WorkbenchStaticTextSelectionCoordinator.shared.stepAutoScrollForTesting() {
                scrolledSteps += 1
            }
        }
        rows[0].mouseUp(with: makeMouseEvent(type: .leftMouseUp, locationInWindow: bottomEdgeZonePoint, windowNumber: window.windowNumber))

        #expect(scrolledSteps > 0)
        #expect(scrollView.documentVisibleRect.minY > 40)
        #expect(rows[0].selectedText == "Row 0")
        let scrolledSelection = WorkbenchStaticTextSelectionCoordinator.shared.selectedText ?? ""
        #expect(scrolledSelection.hasPrefix("Row 0\nRow 1\nRow 2\nRow 3\nRow 4"))

        // 2. Even after Row 0..2 have scrolled above the pinned header's unclipped Y,
        //    dragging from Pinned Header into visible scrolled rows orders Pinned Header strictly first.
        let headerStart = pinnedHeader.convert(CGPoint(x: 1, y: 10), to: nil)
        let visibleScrollMid = CGPoint(x: scrollWindowRect.maxX - 8, y: scrollWindowRect.midY)
        pinnedHeader.mouseDown(with: makeMouseEvent(type: .leftMouseDown, locationInWindow: headerStart, windowNumber: window.windowNumber))
        pinnedHeader.mouseDragged(with: makeMouseEvent(type: .leftMouseDragged, locationInWindow: visibleScrollMid, windowNumber: window.windowNumber))
        pinnedHeader.mouseUp(with: makeMouseEvent(type: .leftMouseUp, locationInWindow: visibleScrollMid, windowNumber: window.windowNumber))

        let headerSelection = WorkbenchStaticTextSelectionCoordinator.shared.selectedText ?? ""
        #expect(headerSelection.hasPrefix("Pinned File Header\nRow "))
    }

    @Test
    func scopeIsolationAndSubtitleTableMutualExclusionPreventCrossLayerOrCrossComponentInterference() {
        WorkbenchStaticTextSelectionCoordinator.shared.clearSelection()
        defer { WorkbenchStaticTextSelectionCoordinator.shared.clearSelection() }

        final class TableTargetSpy: SubtitleTableExternalTextSelectionTarget {
            var externalTextSelectionWindowRect: CGRect? = CGRect(x: 12, y: 12, width: 320, height: 90)
            var canBeginExternalTextSelection = true
            private(set) var beginCount = 0

            func beginExternalTextSelection(startWindowPoint: CGPoint, currentWindowPoint: CGPoint) -> Bool {
                beginCount += 1
                return true
            }

            func updateExternalTextSelection(windowPoint: CGPoint) -> Bool { true }
            func endExternalTextSelection(windowPoint: CGPoint) -> Bool { true }
            func cancelExternalTextSelection() {}
        }

        let (window, rootView) = makeTestWindow(size: CGSize(width: 360, height: 240))

        // Covered lower dialog node vs active top dialog node.
        let coveredDialogText = WorkbenchSelectableTextNSView(frame: CGRect(x: 24, y: 184, width: 220, height: 22))
        coveredDialogText.configure(
            text: "Covered Lower Dialog",
            font: .systemFont(ofSize: 13),
            textColor: .labelColor,
            alignment: .left,
            lineLimit: 1,
            truncatesTail: true,
            isSelectable: true,
            preferredPointerShape: .iBeam,
            showsUnderline: false,
            onTap: nil,
            interfaceLayerContext: InterfaceLayerContext(layer: .dialog),
            isDialogCovered: true
        )
        rootView.addSubview(coveredDialogText)

        let topDialogText = WorkbenchSelectableTextNSView(frame: CGRect(x: 24, y: 146, width: 220, height: 22))
        topDialogText.configure(
            text: "Top Confirmation Message",
            font: .systemFont(ofSize: 13),
            textColor: .labelColor,
            alignment: .left,
            lineLimit: 1,
            truncatesTail: true,
            isSelectable: true,
            preferredPointerShape: .iBeam,
            showsUnderline: false,
            onTap: nil,
            interfaceLayerContext: InterfaceLayerContext(layer: .dialog),
            isDialogCovered: false
        )
        rootView.addSubview(topDialogText)
        rootView.layoutSubtreeIfNeeded()

        // 1. Top-to-bottom sweep only selects active top dialog node, ignoring covered lower dialog.
        let topSweepStart = CGPoint(x: 12, y: 224)
        let sweepIntoTable = CGPoint(x: 260, y: 48)
        let tableSpy = TableTargetSpy()
        let tableSession = SubtitleTableExternalTextSelectionSession()
        tableSession.bind(tableSpy)
        #expect(tableSession.arm(startWindowPoint: topSweepStart))

        window.sendEvent(makeMouseEvent(type: .leftMouseDown, locationInWindow: topSweepStart, windowNumber: window.windowNumber))
        let overTopDialog = topDialogText.convert(CGPoint(x: 180, y: 10), to: nil)
        window.sendEvent(makeMouseEvent(type: .leftMouseDragged, locationInWindow: overTopDialog, windowNumber: window.windowNumber))

        #expect(WorkbenchStaticTextSelectionCoordinator.shared.isDraggingSelection)
        #expect(!coveredDialogText.hasSelection)
        #expect(topDialogText.hasSelection)

        // 2. Continuing that active static-text drag into SubtitleTable rect does NOT let table session hijack.
        #expect(!tableSession.drag(windowPoint: sweepIntoTable))
        #expect(tableSession.phase == .idle)
        #expect(tableSpy.beginCount == 0)

        window.sendEvent(makeMouseEvent(type: .leftMouseDragged, locationInWindow: sweepIntoTable, windowNumber: window.windowNumber))
        window.sendEvent(makeMouseEvent(type: .leftMouseUp, locationInWindow: sweepIntoTable, windowNumber: window.windowNumber))
        #expect(WorkbenchStaticTextSelectionCoordinator.shared.selectedText == "Top Confirmation Message")

        // 3. Starting selection in another surface (.cueSeekerClearTextSelection) clears static text selection.
        NotificationCenter.default.post(name: .cueSeekerClearTextSelection, object: nil)
        #expect(!WorkbenchStaticTextSelectionCoordinator.shared.hasSelection)
    }
}
