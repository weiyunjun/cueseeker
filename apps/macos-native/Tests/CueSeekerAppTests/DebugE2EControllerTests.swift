#if DEBUG
import AppKit
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
        #expect(throws: DebugE2EError.self) {
            try DebugE2ECommand(line: #"{"action":"click","x":120,"y":84}"#)
        }
        #expect(throws: DebugE2EError.self) {
            try DebugE2ECommand(line: #"{"action":"unknown"}"#)
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
        contentView: NSView? = nil
    ) -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: frame.size),
            styleMask: [.borderless],
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
#endif
