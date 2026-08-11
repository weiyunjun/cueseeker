#if DEBUG
import AppKit
import Foundation

enum DebugE2ECommand: Equatable {
    case capture(name: String)
    case click(x: CGFloat, y: CGFloat)

    init(line: String) throws {
        let payload: Payload
        do {
            payload = try JSONDecoder().decode(
                Payload.self,
                from: Data(line.utf8)
            )
        } catch {
            throw DebugE2EError.invalidCommand("Command must be one JSON object")
        }

        switch payload.action {
        case "capture":
            guard let name = payload.name,
                  payload.x == nil,
                  payload.y == nil
            else {
                throw DebugE2EError.invalidCommand(
                    "capture requires name and no coordinates"
                )
            }
            self = .capture(name: name)
        case "click":
            guard payload.name == nil,
                  let x = payload.x,
                  let y = payload.y
            else {
                throw DebugE2EError.invalidCommand(
                    "click requires x and y and no name"
                )
            }
            self = .click(x: CGFloat(x), y: CGFloat(y))
        default:
            throw DebugE2EError.invalidCommand(
                "Unsupported action: \(payload.action)"
            )
        }
    }

    private struct Payload: Decodable {
        let action: String
        let name: String?
        let x: Double?
        let y: Double?
    }
}

enum DebugE2EError: Error, CustomStringConvertible {
    case invalidCommand(String)
    case invalidCaptureName
    case mainWindowUnavailable
    case captureUnavailable(String)
    case screenshotEncodingFailed
    case invalidClickCoordinate
    case eventCreationFailed

    var description: String {
        switch self {
        case .invalidCommand(let message):
            message
        case .invalidCaptureName:
            "Capture name must contain only letters, numbers, hyphens, or underscores"
        case .mainWindowUnavailable:
            "The CueSeeker main window is unavailable"
        case .captureUnavailable(let message):
            message
        case .screenshotEncodingFailed:
            "The current CueSeeker window could not be encoded as PNG"
        case .invalidClickCoordinate:
            "Click coordinates must be finite and inside the window content bounds"
        case .eventCreationFailed:
            "The AppKit mouse events could not be created"
        }
    }
}

struct DebugE2EScreenshotResult {
    let url: URL
    let pixelWidth: Int
    let pixelHeight: Int
}

@MainActor
enum DebugE2EScreenshotWriter {
    static func capture(
        window: NSWindow,
        directory: URL,
        name: String
    ) throws -> DebugE2EScreenshotResult {
        let allowedCharacters = CharacterSet.alphanumerics.union(
            CharacterSet(charactersIn: "-_")
        )
        guard !name.isEmpty,
              name.unicodeScalars.allSatisfy(allowedCharacters.contains)
        else {
            throw DebugE2EError.invalidCaptureName
        }
        guard let contentView = window.contentView else {
            throw DebugE2EError.mainWindowUnavailable
        }

        contentView.layoutSubtreeIfNeeded()
        contentView.displayIfNeeded()
        let bounds = contentView.bounds
        guard bounds.width > 0,
              bounds.height > 0,
              let bitmap = contentView.bitmapImageRepForCachingDisplay(in: bounds)
        else {
            throw DebugE2EError.captureUnavailable(
                "The CueSeeker window has no drawable content"
            )
        }

        contentView.cacheDisplay(in: bounds, to: bitmap)
        guard let png = bitmap.representation(using: .png, properties: [:]) else {
            throw DebugE2EError.screenshotEncodingFailed
        }

        let outputURL = directory
            .appendingPathComponent(name)
            .appendingPathExtension("png")
        try png.write(to: outputURL, options: .atomic)
        return DebugE2EScreenshotResult(
            url: outputURL,
            pixelWidth: bitmap.pixelsWide,
            pixelHeight: bitmap.pixelsHigh
        )
    }
}

@MainActor
enum DebugE2EClickDispatcher {
    static func windowPoint(
        x: CGFloat,
        y: CGFloat,
        contentView: NSView
    ) throws -> NSPoint {
        let bounds = contentView.bounds
        guard x.isFinite,
              y.isFinite,
              x >= 0,
              y >= 0,
              x < bounds.width,
              y < bounds.height
        else {
            throw DebugE2EError.invalidClickCoordinate
        }

        let localPoint = NSPoint(
            x: bounds.minX + x,
            y: contentView.isFlipped
                ? bounds.minY + y
                : bounds.maxY - y
        )
        return contentView.convert(localPoint, to: nil)
    }

    static func click(
        x: CGFloat,
        y: CGFloat,
        window: NSWindow,
        routeMouseDown: (NSEvent) -> NSEvent =
            CueSeekerPointerEventRouter.routeLeftMouseDown
    ) throws {
        guard let contentView = window.contentView else {
            throw DebugE2EError.mainWindowUnavailable
        }
        let location = try windowPoint(x: x, y: y, contentView: contentView)
        let timestamp = ProcessInfo.processInfo.systemUptime
        guard let mouseDown = NSEvent.mouseEvent(
            with: .leftMouseDown,
            location: location,
            modifierFlags: [],
            timestamp: timestamp,
            windowNumber: window.windowNumber,
            context: nil,
            eventNumber: 0,
            clickCount: 1,
            pressure: 1
        ),
        let mouseUp = NSEvent.mouseEvent(
            with: .leftMouseUp,
            location: location,
            modifierFlags: [],
            timestamp: timestamp + 0.001,
            windowNumber: window.windowNumber,
            context: nil,
            eventNumber: 0,
            clickCount: 1,
            pressure: 0
        ) else {
            throw DebugE2EError.eventCreationFailed
        }

        window.sendEvent(routeMouseDown(mouseDown))
        window.sendEvent(mouseUp)
    }
}

@MainActor
final class DebugE2EController {
    typealias CapturePreparation = @MainActor () throws -> (() -> Void)?

    private weak var window: NSWindow?
    private let artifactDirectory: URL
    private let prepareCapture: CapturePreparation
    private var inputTask: Task<Void, Never>?

    static func isRequested(
        arguments: [String] = ProcessInfo.processInfo.arguments
    ) -> Bool {
        arguments.contains("--cueseeker-debug-e2e")
    }

    init(
        window: NSWindow,
        prepareCapture: @escaping CapturePreparation = { nil }
    ) throws {
        self.window = window
        self.prepareCapture = prepareCapture
        artifactDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "CueSeeker-Debug-E2E-\(ProcessInfo.processInfo.processIdentifier)",
                isDirectory: true
            )
        try FileManager.default.createDirectory(
            at: artifactDirectory,
            withIntermediateDirectories: true
        )
    }

    func start() {
        guard let window, let contentView = window.contentView else {
            Self.write([
                "status": "error",
                "message": DebugE2EError.mainWindowUnavailable.description,
            ])
            return
        }

        Self.write([
            "status": "ready",
            "width": contentView.bounds.width,
            "height": contentView.bounds.height,
            "scale": window.backingScaleFactor,
            "artifactDirectory": artifactDirectory.path,
        ])

        inputTask = Task.detached(priority: .utility) { [weak self] in
            while !Task.isCancelled, let line = readLine() {
                await self?.receive(line)
            }
        }
    }

    static func reportStartupError(_ error: Error) {
        write([
            "status": "error",
            "message": String(describing: error),
        ])
    }

    private func receive(_ line: String) {
        do {
            guard let window else {
                throw DebugE2EError.mainWindowUnavailable
            }
            switch try DebugE2ECommand(line: line) {
            case .capture(let name):
                let cleanup = try prepareCapture()
                defer { cleanup?() }
                let result = try DebugE2EScreenshotWriter.capture(
                    window: window,
                    directory: artifactDirectory,
                    name: name
                )
                Self.write([
                    "status": "ok",
                    "action": "capture",
                    "path": result.url.path,
                    "pixelWidth": result.pixelWidth,
                    "pixelHeight": result.pixelHeight,
                ])
            case .click(let x, let y):
                try DebugE2EClickDispatcher.click(x: x, y: y, window: window)
                Self.write([
                    "status": "ok",
                    "action": "click",
                    "x": x,
                    "y": y,
                ])
            }
        } catch {
            Self.write([
                "status": "error",
                "message": String(describing: error),
            ])
        }
    }

    private static func write(_ payload: [String: Any]) {
        guard JSONSerialization.isValidJSONObject(payload),
              let json = try? JSONSerialization.data(
                withJSONObject: payload,
                options: [.sortedKeys]
              )
        else {
            return
        }
        var output = Data("CUESEEKER_E2E ".utf8)
        output.append(json)
        output.append(Data("\n".utf8))
        FileHandle.standardOutput.write(output)
    }
}
#endif
