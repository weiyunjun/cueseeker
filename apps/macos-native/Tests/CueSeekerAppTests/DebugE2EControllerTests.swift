#if DEBUG
import AppKit
import ImageIO
import Testing
@testable import CueSeekerApp

@Suite(.serialized)
struct DebugE2EControllerTests {
    @Test
    func commandParsesSupportedActions() throws {
        #expect(
            try DebugE2ECommand(line: #"{"action":"capture","name":"before-click"}"#)
                == .capture(name: "before-click")
        )
        #expect(
            try DebugE2ECommand(line: #"{"action":"click","x":120.5,"y":84}"#)
                == .click(x: 120.5, y: 84)
        )
        #expect(throws: DebugE2EError.self) {
            try DebugE2ECommand(line: #"{"action":"click","x":120}"#)
        }
        #expect(throws: DebugE2EError.self) {
            try DebugE2ECommand(line: #"{"action":"unknown"}"#)
        }
    }

    @Test
    @MainActor
    func coordinatesUseContentTopLeftLogicalPoints() throws {
        let contentView = DebugE2EFlippedView(
            frame: NSRect(x: 0, y: 0, width: 300, height: 200)
        )
        let window = NSWindow(
            contentRect: contentView.bounds,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.contentView = contentView

        let point = try DebugE2EClickDispatcher.windowPoint(
            x: 25,
            y: 40,
            contentView: contentView
        )
        let converted = contentView.convert(point, from: nil)
        #expect(converted.x == 25)
        #expect(converted.y == 40)
        #expect(throws: DebugE2EError.self) {
            try DebugE2EClickDispatcher.windowPoint(
                x: 300,
                y: 40,
                contentView: contentView
            )
        }
    }

    @Test
    @MainActor
    func clickTravelsThroughAppKitHitTesting() throws {
        let contentView = DebugE2EClickRecordingView(
            frame: NSRect(x: 0, y: 0, width: 300, height: 200)
        )
        let window = NSWindow(
            contentRect: contentView.bounds,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.contentView = contentView
        window.orderFront(nil)

        try DebugE2EClickDispatcher.click(
            x: 25,
            y: 40,
            window: window,
            routeMouseDown: { $0 }
        )

        #expect(contentView.mouseDownLocations == [NSPoint(x: 25, y: 40)])
        #expect(contentView.mouseUpLocations == [NSPoint(x: 25, y: 40)])
    }

    @Test
    @MainActor
    func screenshotWriterProducesReadablePNG() throws {
        let contentView = DebugE2EDrawingView(
            frame: NSRect(x: 0, y: 0, width: 40, height: 30)
        )
        let window = NSWindow(
            contentRect: contentView.bounds,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.contentView = contentView

        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("CueSeeker-Debug-E2E-Tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: directory) }

        let result = try DebugE2EScreenshotWriter.capture(
            window: window,
            directory: directory,
            name: "window"
        )
        let data = try Data(contentsOf: result.url)
        let source = try #require(CGImageSourceCreateWithData(data as CFData, nil))
        let image = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))

        #expect(image.width == result.pixelWidth)
        #expect(image.height == result.pixelHeight)
        #expect(image.width > 0)
        #expect(image.height > 0)
        #expect(throws: DebugE2EError.self) {
            try DebugE2EScreenshotWriter.capture(
                window: window,
                directory: directory,
                name: "../outside"
            )
        }
    }
}

private class DebugE2EFlippedView: NSView {
    override var isFlipped: Bool { true }
}

private final class DebugE2EClickRecordingView: DebugE2EFlippedView {
    private(set) var mouseDownLocations: [NSPoint] = []
    private(set) var mouseUpLocations: [NSPoint] = []

    override func mouseDown(with event: NSEvent) {
        mouseDownLocations.append(convert(event.locationInWindow, from: nil))
    }

    override func mouseUp(with event: NSEvent) {
        mouseUpLocations.append(convert(event.locationInWindow, from: nil))
    }
}

private final class DebugE2EDrawingView: DebugE2EFlippedView {
    override func draw(_ dirtyRect: NSRect) {
        NSColor.systemRed.setFill()
        dirtyRect.fill()
    }
}
#endif
