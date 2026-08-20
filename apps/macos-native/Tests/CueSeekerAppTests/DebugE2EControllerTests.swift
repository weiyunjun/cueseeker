#if DEBUG
import AppKit
import Carbon.HIToolbox
import ImageIO
import Testing
@testable import CueSeekerApp

@Suite(.serialized)
struct DebugE2EControllerTests {
    @Test
    func commandParsesSupportedActions() throws {
        #expect(try DebugE2ECommand(line: #"{"action":"inspect"}"#) == .inspect)
        #expect(
            try DebugE2ECommand(line: #"{"action":"capture","name":"before-click"}"#)
                == .capture(name: "before-click")
        )
        #expect(
            try DebugE2ECommand(
                line: #"{"action":"click","x":120.5,"y":84,"sceneID":"abc"}"#
            ) == .click(x: 120.5, y: 84, sceneID: "abc")
        )
        #expect(
            try DebugE2ECommand(
                line: #"{"action":"scroll","x":120.5,"y":84,"deltaY":-3,"sceneID":"abc"}"#
            ) == .scroll(x: 120.5, y: 84, deltaY: -3, sceneID: "abc")
        )
        #expect(
            try DebugE2ECommand(
                line: #"{"action":"keyPress","key":"enter","modifiers":[],"sceneID":"abc"}"#
            ) == .keyPress(key: "enter", modifiers: [], sceneID: "abc")
        )
        #expect(throws: DebugE2EError.self) {
            try DebugE2ECommand(line: #"{"action":"click","x":120,"y":84}"#)
        }
        #expect(throws: DebugE2EError.self) {
            try DebugE2ECommand(
                line: #"{"action":"scroll","x":120,"y":84,"deltaY":0,"sceneID":"abc"}"#
            )
        }
        #expect(throws: DebugE2EError.self) {
            try DebugE2ECommand(
                line: #"{"action":"keyPress","key":"enter","sceneID":"abc"}"#
            )
        }
        #expect(
            try DebugE2ECommand(
                line: #"{"action":"setWidth","width":1100,"sceneID":"abc"}"#
            ) == .setWidth(width: 1100, sceneID: "abc")
        )
        #expect(throws: DebugE2EError.self) {
            try DebugE2ECommand(line: #"{"action":"setWidth","width":1100}"#)
        }
        #expect(throws: DebugE2EError.self) {
            try DebugE2ECommand(
                line: #"{"action":"setWidth","width":0,"sceneID":"abc"}"#
            )
        }
        #expect(throws: DebugE2EError.self) {
            try DebugE2ECommand(
                line: #"{"action":"setWidth","width":-320,"sceneID":"abc"}"#
            )
        }
        #expect(throws: DebugE2EError.self) {
            try DebugE2ECommand(line: #"{"action":"setWidth","sceneID":"abc"}"#)
        }
        #expect(throws: DebugE2EError.self) {
            try DebugE2ECommand(line: #"{"action":"unknown"}"#)
        }
    }

    @Test
    @MainActor
    func setWidthResizesMainWindowAndInvalidatesScene() throws {
        let screen = try #require(NSScreen.main)
        let window = makeWindow(
            frame: NSRect(
                x: screen.frame.minX + 80,
                y: screen.frame.minY + 100,
                width: 300,
                height: 200
            )
        )
        window.orderFront(nil)
        defer { window.orderOut(nil) }

        let scene = try DebugE2EScene.current(mainWindow: window)
        let topLeft = NSPoint(x: window.frame.minX, y: window.frame.maxY)

        try DebugE2EWindowSizeDispatcher.setWidth(460, window: window)

        #expect(window.frame.width == 460)
        #expect(window.frame.height == 200)
        #expect(window.frame.minX == topLeft.x)
        #expect(window.frame.maxY == topLeft.y)

        let resizedScene = try DebugE2EScene.current(mainWindow: window)
        #expect(resizedScene.width == 460)
        #expect(resizedScene.id != scene.id)

        #expect(throws: DebugE2EError.self) {
            try DebugE2EWindowSizeDispatcher.setWidth(0, window: window)
        }
        #expect(throws: DebugE2EError.self) {
            try DebugE2EWindowSizeDispatcher.setWidth(.nan, window: window)
        }
        #expect(window.frame.width == 460)
    }

    @Test
    func keyStrokeResolvesSupportedKeysAndModifiers() throws {
        let letter = try DebugE2EKeyStroke(
            key: "A",
            modifiers: ["shift", "command", "shift"]
        )
        #expect(letter.key == "a")
        #expect(letter.keyCode == UInt16(kVK_ANSI_A))
        #expect(letter.characters == "A")
        #expect(letter.charactersIgnoringModifiers == "A")
        #expect(letter.modifiers == ["command", "shift"])
        #expect(letter.modifierFlags == [.command, .shift])

        let digit = try DebugE2EKeyStroke(key: "1", modifiers: ["shift"])
        #expect(digit.keyCode == UInt16(kVK_ANSI_1))
        #expect(digit.characters == "!")

        let enter = try DebugE2EKeyStroke(key: "enter", modifiers: [])
        #expect(enter.keyCode == UInt16(kVK_Return))
        #expect(enter.characters == "\r")

        let arrow = try DebugE2EKeyStroke(
            key: "leftArrow",
            modifiers: ["function"]
        )
        #expect(arrow.key == "leftArrow")
        #expect(arrow.keyCode == UInt16(kVK_LeftArrow))
        #expect(arrow.modifierFlags == [.function])

        #expect(throws: DebugE2EError.self) {
            try DebugE2EKeyStroke(key: "f1", modifiers: [])
        }
        #expect(throws: DebugE2EError.self) {
            try DebugE2EKeyStroke(key: "a", modifiers: ["capsLock"])
        }
    }

    @Test
    @MainActor
    func sceneUsesVisibleWindowUnionAndTopLeftCoordinates() throws {
        let screen = try #require(NSScreen.main)
        let mainWindow = makeWindow(
            frame: NSRect(
                x: screen.frame.minX + 80,
                y: screen.frame.minY + 100,
                width: 300,
                height: 200
            )
        )
        let secondWindow = makeWindow(
            frame: NSRect(
                x: screen.frame.minX + 330,
                y: screen.frame.minY + 180,
                width: 180,
                height: 120
            )
        )
        mainWindow.orderFront(nil)
        secondWindow.orderFront(nil)
        defer {
            secondWindow.orderOut(nil)
            mainWindow.orderOut(nil)
        }

        let scene = try DebugE2EScene.current(mainWindow: mainWindow)
        #expect(scene.bounds == mainWindow.frame.union(secondWindow.frame))
        #expect(scene.layouts.contains(where: { $0.windowNumber == mainWindow.windowNumber }))
        #expect(scene.layouts.contains(where: { $0.windowNumber == secondWindow.windowNumber }))
        #expect(
            try scene.screenPoint(x: 0, y: 0)
                == NSPoint(x: scene.bounds.minX, y: scene.bounds.maxY)
        )

        let firstID = scene.id
        secondWindow.setFrameOrigin(
            NSPoint(x: secondWindow.frame.minX + 10, y: secondWindow.frame.minY)
        )
        let movedScene = try DebugE2EScene.current(mainWindow: mainWindow)
        #expect(movedScene.id != firstID)
    }

    @Test
    @MainActor
    func clickTargetsFrontmostWindowInScene() throws {
        let backView = DebugE2EClickRecordingView(
            frame: NSRect(x: 0, y: 0, width: 200, height: 160)
        )
        let frontView = DebugE2EClickRecordingView(
            frame: NSRect(x: 0, y: 0, width: 140, height: 100)
        )
        let backWindow = makeWindow(
            frame: NSRect(x: 100, y: 100, width: 200, height: 160),
            contentView: backView
        )
        let frontWindow = makeWindow(
            frame: NSRect(x: 130, y: 130, width: 140, height: 100),
            contentView: frontView
        )
        backWindow.orderFront(nil)
        frontWindow.orderFront(nil)
        defer {
            frontWindow.orderOut(nil)
            backWindow.orderOut(nil)
        }
        let bounds = backWindow.frame.union(frontWindow.frame)
        let scene = DebugE2EScene(
            windows: [frontWindow, backWindow],
            bounds: bounds,
            screenFrame: bounds,
            displayID: 0,
            scale: 1,
            layouts: [],
            id: "scene"
        )
        let clickScreenPoint = NSPoint(x: 160, y: 170)

        try DebugE2EClickDispatcher.click(
            x: clickScreenPoint.x - bounds.minX,
            y: bounds.maxY - clickScreenPoint.y,
            scene: scene,
            postEvents: { mouseDown, mouseUp in
                mouseDown.window?.sendEvent(mouseDown)
                mouseUp.window?.sendEvent(mouseUp)
            }
        )

        #expect(frontView.mouseDownLocations.count == 1)
        #expect(frontView.mouseUpLocations.count == 1)
        #expect(backView.mouseDownLocations.isEmpty)
        #expect(backView.mouseUpLocations.isEmpty)
    }

    @Test
    @MainActor
    func scrollTargetsFrontmostWindowInBothDirections() throws {
        let screen = try #require(NSScreen.main)
        let displayNumber = try #require(
            screen.deviceDescription[
                NSDeviceDescriptionKey("NSScreenNumber")
            ] as? NSNumber
        )
        let backView = DebugE2EScrollRecordingView(
            frame: NSRect(x: 0, y: 0, width: 200, height: 160)
        )
        let frontView = DebugE2EScrollRecordingView(
            frame: NSRect(x: 0, y: 0, width: 140, height: 100)
        )
        let backWindow = makeWindow(
            frame: NSRect(
                x: screen.frame.minX + 100,
                y: screen.frame.minY + 100,
                width: 200,
                height: 160
            ),
            contentView: backView
        )
        let frontWindow = makeWindow(
            frame: NSRect(
                x: screen.frame.minX + 130,
                y: screen.frame.minY + 130,
                width: 140,
                height: 100
            ),
            contentView: frontView
        )
        backWindow.orderFront(nil)
        frontWindow.orderFront(nil)
        defer {
            frontWindow.orderOut(nil)
            backWindow.orderOut(nil)
        }
        let bounds = backWindow.frame.union(frontWindow.frame)
        let scene = DebugE2EScene(
            windows: [frontWindow, backWindow],
            bounds: bounds,
            screenFrame: screen.frame,
            displayID: CGDirectDisplayID(displayNumber.uint32Value),
            scale: screen.backingScaleFactor,
            layouts: [],
            id: "scene"
        )
        let scrollScreenPoint = NSPoint(
            x: frontWindow.frame.midX,
            y: frontWindow.frame.midY
        )
        let x = scrollScreenPoint.x - bounds.minX
        let y = bounds.maxY - scrollScreenPoint.y

        for deltaY: Int32 in [2, -3] {
            try DebugE2EScrollDispatcher.scroll(
                x: x,
                y: y,
                deltaY: deltaY,
                scene: scene,
                postEvent: { event in
                    NSApplication.shared.sendEvent(event)
                }
            )
        }

        #expect(frontView.scrollEvents.map(\.scrollingDeltaY) == [2, -3])
        #expect(frontView.scrollEvents.allSatisfy { !$0.hasPreciseScrollingDeltas })
        #expect(backView.scrollEvents.isEmpty)
        #expect(throws: DebugE2EError.self) {
            try DebugE2EScrollDispatcher.scroll(
                x: x,
                y: y,
                deltaY: 0,
                scene: scene
            )
        }
        #expect(throws: DebugE2EError.self) {
            try DebugE2EScrollDispatcher.scroll(
                x: -1,
                y: y,
                deltaY: 1,
                scene: scene
            )
        }
    }

    @Test
    @MainActor
    func keyPressTravelsThroughWindowFirstResponder() throws {
        let view = DebugE2EKeyRecordingView(
            frame: NSRect(x: 0, y: 0, width: 200, height: 120)
        )
        let window = makeWindow(
            frame: NSRect(x: 100, y: 100, width: 200, height: 120),
            styleMask: [.titled],
            contentView: view
        )
        window.makeKeyAndOrderFront(nil)
        #expect(window.makeFirstResponder(view))
        defer { window.orderOut(nil) }
        let keyStroke = try DebugE2EKeyStroke(
            key: "q",
            modifiers: ["command"]
        )

        try DebugE2EKeyboardDispatcher.keyPress(
            keyStroke,
            window: window,
            postEvents: { keyDown, keyUp in
                window.sendEvent(keyDown)
                window.sendEvent(keyUp)
            }
        )

        #expect(view.keyDownEvents.count == 1)
        #expect(view.keyUpEvents.count == 1)
        #expect(view.keyDownEvents[0].keyCode == UInt16(kVK_ANSI_Q))
        #expect(view.keyDownEvents[0].charactersIgnoringModifiers == "q")
        #expect(view.keyDownEvents[0].modifierFlags.contains(.command))
        #expect(!view.keyDownEvents[0].isARepeat)
    }

    @Test
    func screenshotWriterProducesReadablePNG() throws {
        let image = try #require(makeImage(width: 40, height: 30))
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("CueSeeker-Debug-E2E-Tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: directory) }

        let result = try DebugE2EScreenshotWriter.write(
            image: image,
            directory: directory,
            name: "scene"
        )
        let data = try Data(contentsOf: result.url)
        let source = try #require(CGImageSourceCreateWithData(data as CFData, nil))
        let decodedImage = try #require(
            CGImageSourceCreateImageAtIndex(source, 0, nil)
        )

        #expect(decodedImage.width == 40)
        #expect(decodedImage.height == 30)
        #expect(throws: DebugE2EError.self) {
            try DebugE2EScreenshotWriter.write(
                image: image,
                directory: directory,
                name: "../outside"
            )
        }
        let fileURL = directory.appendingPathComponent("not-a-directory")
        try Data().write(to: fileURL)
        #expect(throws: DebugE2EError.self) {
            try DebugE2EScreenshotWriter.write(
                image: image,
                directory: fileURL,
                name: "unsavable"
            )
        }
    }

    @MainActor
    private func makeWindow(
        frame: NSRect,
        styleMask: NSWindow.StyleMask = [.borderless],
        contentView: NSView? = nil
    ) -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: frame.size),
            styleMask: styleMask,
            backing: .buffered,
            defer: false
        )
        window.setFrame(frame, display: false)
        if let contentView {
            window.contentView = contentView
        }
        return window
    }

    private func makeImage(width: Int, height: Int) -> CGImage? {
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }
        context.setFillColor(NSColor.systemRed.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()
    }
}

private final class DebugE2EClickRecordingView: NSView {
    private(set) var mouseDownLocations: [NSPoint] = []
    private(set) var mouseUpLocations: [NSPoint] = []

    override var isFlipped: Bool { true }

    override func mouseDown(with event: NSEvent) {
        mouseDownLocations.append(convert(event.locationInWindow, from: nil))
    }

    override func mouseUp(with event: NSEvent) {
        mouseUpLocations.append(convert(event.locationInWindow, from: nil))
    }
}

private final class DebugE2EKeyRecordingView: NSView {
    private(set) var keyDownEvents: [NSEvent] = []
    private(set) var keyUpEvents: [NSEvent] = []

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        keyDownEvents.append(event)
    }

    override func keyUp(with event: NSEvent) {
        keyUpEvents.append(event)
    }
}

private final class DebugE2EScrollRecordingView: NSView {
    private(set) var scrollEvents: [NSEvent] = []

    override func scrollWheel(with event: NSEvent) {
        scrollEvents.append(event)
    }
}
#endif
