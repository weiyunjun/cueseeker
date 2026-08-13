#if DEBUG
import AppKit
import Carbon.HIToolbox
import CoreGraphics
import Foundation
@preconcurrency import ScreenCaptureKit

enum DebugE2ECommand: Equatable {
    case inspect
    case capture(name: String)
    case click(x: CGFloat, y: CGFloat, sceneID: String)
    case scroll(x: CGFloat, y: CGFloat, deltaY: Int32, sceneID: String)
    case keyPress(key: String, modifiers: [String], sceneID: String)

    init(line: String) throws {
        let payload: Payload
        do {
            payload = try JSONDecoder().decode(Payload.self, from: Data(line.utf8))
        } catch {
            throw DebugE2EError.invalidCommand("Command must be one JSON object")
        }

        switch payload.action {
        case "inspect":
            guard payload.name == nil,
                  payload.x == nil,
                  payload.y == nil,
                  payload.deltaY == nil,
                  payload.key == nil,
                  payload.modifiers == nil,
                  payload.sceneID == nil
            else {
                throw DebugE2EError.invalidCommand("inspect takes no arguments")
            }
            self = .inspect
        case "capture":
            guard let name = payload.name,
                  payload.x == nil,
                  payload.y == nil,
                  payload.deltaY == nil,
                  payload.key == nil,
                  payload.modifiers == nil,
                  payload.sceneID == nil
            else {
                throw DebugE2EError.invalidCommand(
                    "capture requires name and no coordinates"
                )
            }
            self = .capture(name: name)
        case "click":
            guard payload.name == nil,
                  let x = payload.x,
                  let y = payload.y,
                  payload.deltaY == nil,
                  payload.key == nil,
                  payload.modifiers == nil,
                  let sceneID = payload.sceneID
            else {
                throw DebugE2EError.invalidCommand(
                    "click requires x, y, and sceneID"
                )
            }
            self = .click(x: CGFloat(x), y: CGFloat(y), sceneID: sceneID)
        case "scroll":
            guard payload.name == nil,
                  let x = payload.x,
                  let y = payload.y,
                  let deltaY = payload.deltaY,
                  deltaY != 0,
                  payload.key == nil,
                  payload.modifiers == nil,
                  let sceneID = payload.sceneID
            else {
                throw DebugE2EError.invalidCommand(
                    "scroll requires x, y, a nonzero integer deltaY, and sceneID"
                )
            }
            self = .scroll(
                x: CGFloat(x),
                y: CGFloat(y),
                deltaY: deltaY,
                sceneID: sceneID
            )
        case "keyPress":
            guard payload.name == nil,
                  payload.x == nil,
                  payload.y == nil,
                  payload.deltaY == nil,
                  let key = payload.key,
                  let modifiers = payload.modifiers,
                  let sceneID = payload.sceneID
            else {
                throw DebugE2EError.invalidCommand(
                    "keyPress requires key, modifiers, and sceneID"
                )
            }
            self = .keyPress(
                key: key,
                modifiers: modifiers,
                sceneID: sceneID
            )
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
        let deltaY: Int32?
        let key: String?
        let modifiers: [String]?
        let sceneID: String?
    }
}

enum DebugE2EError: Error, CustomStringConvertible {
    case invalidCommand(String)
    case invalidCaptureName
    case noVisibleWindows
    case windowsSpanMultipleDisplays
    case screenRecordingPermissionRequired
    case captureUnavailable(String)
    case screenshotEncodingFailed
    case screenshotSaveFailed(String)
    case invalidClickCoordinate
    case invalidScrollCoordinate
    case invalidScrollDelta
    case sceneChanged
    case eventCreationFailed
    case scrollEventCreationFailed
    case unsupportedKey(String)
    case unsupportedModifier(String)
    case keyWindowUnavailable
    case keyboardEventCreationFailed

    var code: String {
        switch self {
        case .invalidCommand:
            "invalidCommand"
        case .invalidCaptureName:
            "invalidCaptureName"
        case .noVisibleWindows:
            "noVisibleWindows"
        case .windowsSpanMultipleDisplays:
            "windowsSpanMultipleDisplays"
        case .screenRecordingPermissionRequired:
            "screenRecordingPermissionRequired"
        case .captureUnavailable:
            "captureUnavailable"
        case .screenshotEncodingFailed:
            "screenshotEncodingFailed"
        case .screenshotSaveFailed:
            "screenshotSaveFailed"
        case .invalidClickCoordinate:
            "invalidClickCoordinate"
        case .invalidScrollCoordinate:
            "invalidScrollCoordinate"
        case .invalidScrollDelta:
            "invalidScrollDelta"
        case .sceneChanged:
            "sceneChanged"
        case .eventCreationFailed:
            "eventCreationFailed"
        case .scrollEventCreationFailed:
            "scrollEventCreationFailed"
        case .unsupportedKey:
            "unsupportedKey"
        case .unsupportedModifier:
            "unsupportedModifier"
        case .keyWindowUnavailable:
            "keyWindowUnavailable"
        case .keyboardEventCreationFailed:
            "keyboardEventCreationFailed"
        }
    }

    var description: String {
        switch self {
        case .invalidCommand(let message):
            message
        case .invalidCaptureName:
            "Capture name must contain only letters, numbers, hyphens, or underscores"
        case .noVisibleWindows:
            "CueSeeker has no visible windows to capture"
        case .windowsSpanMultipleDisplays:
            "All visible CueSeeker windows must be fully contained by one display"
        case .screenRecordingPermissionRequired:
            "Screen Recording permission is required; grant it in System Settings and restart CueSeeker"
        case .captureUnavailable(let message):
            message
        case .screenshotEncodingFailed:
            "The current CueSeeker scene could not be encoded as PNG"
        case .screenshotSaveFailed(let message):
            "The current CueSeeker scene could not be saved: \(message)"
        case .invalidClickCoordinate:
            "Click coordinates must be finite and hit a visible CueSeeker window"
        case .invalidScrollCoordinate:
            "Scroll coordinates must be finite and hit a visible CueSeeker window"
        case .invalidScrollDelta:
            "Scroll deltaY must be a nonzero integer"
        case .sceneChanged:
            "The CueSeeker scene changed; inspect the scene before continuing"
        case .eventCreationFailed:
            "The AppKit mouse events could not be created"
        case .scrollEventCreationFailed:
            "The AppKit scroll-wheel event could not be created"
        case .unsupportedKey(let key):
            "Unsupported key: \(key)"
        case .unsupportedModifier(let modifier):
            "Unsupported modifier: \(modifier)"
        case .keyWindowUnavailable:
            "CueSeeker must be active with a visible key window in the current scene"
        case .keyboardEventCreationFailed:
            "The AppKit keyboard events could not be created"
        }
    }
}

struct DebugE2EWindowLayout: Equatable {
    let windowNumber: Int
    let title: String
    let kind: String
    let order: Int
    let frame: CGRect

    var json: [String: Any] {
        [
            "windowNumber": windowNumber,
            "title": title,
            "kind": kind,
            "order": order,
            "x": frame.minX,
            "y": frame.minY,
            "width": frame.width,
            "height": frame.height,
        ]
    }
}

@MainActor
struct DebugE2EScene {
    let windows: [NSWindow]
    let bounds: CGRect
    let screenFrame: CGRect
    let displayID: CGDirectDisplayID
    let scale: CGFloat
    let layouts: [DebugE2EWindowLayout]
    let id: String

    var width: CGFloat { bounds.width }
    var height: CGFloat { bounds.height }
    var pixelWidth: Int { Int((width * scale).rounded()) }
    var pixelHeight: Int { Int((height * scale).rounded()) }

    var sourceRect: CGRect {
        CGRect(
            x: bounds.minX - screenFrame.minX,
            y: screenFrame.maxY - bounds.maxY,
            width: bounds.width,
            height: bounds.height
        )
    }

    var json: [String: Any] {
        [
            "sceneID": id,
            "width": width,
            "height": height,
            "pixelWidth": pixelWidth,
            "pixelHeight": pixelHeight,
            "scale": scale,
            "displayID": displayID,
            "windows": layouts.map(\.json),
        ]
    }

    static func current(
        mainWindow: NSWindow,
        application: NSApplication = .shared
    ) throws -> DebugE2EScene {
        let eligibleWindows = application.windows.filter {
            $0.isVisible
                && !$0.isMiniaturized
                && $0.alphaValue > 0
                && $0.windowNumber > 0
        }
        let windowsByNumber = Dictionary(
            uniqueKeysWithValues: eligibleWindows.map { ($0.windowNumber, $0) }
        )
        var windows: [NSWindow] = []
        var orderedWindowNumbers: Set<Int> = []
        func append(_ window: NSWindow?) {
            guard let window,
                  windowsByNumber[window.windowNumber] != nil,
                  orderedWindowNumbers.insert(window.windowNumber).inserted
            else {
                return
            }
            windows.append(window)
        }

        append(application.keyWindow)
        application.orderedWindows.forEach(append)

        let windowInfo = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] ?? []
        let processID = ProcessInfo.processInfo.processIdentifier
        windowInfo.forEach { info in
            guard let ownerPID = info[kCGWindowOwnerPID as String] as? NSNumber,
                  ownerPID.int32Value == processID,
                  let number = info[kCGWindowNumber as String] as? NSNumber
            else {
                return
            }
            append(windowsByNumber[number.intValue])
        }
        eligibleWindows
            .sorted { $0.orderedIndex < $1.orderedIndex }
            .forEach(append)
        guard !windows.isEmpty, windows.contains(where: { $0 === mainWindow }) else {
            throw DebugE2EError.noVisibleWindows
        }

        let screens = try windows.map { window -> (NSScreen, CGDirectDisplayID) in
            guard let screen = window.screen,
                  let number = screen.deviceDescription[
                    NSDeviceDescriptionKey("NSScreenNumber")
                  ] as? NSNumber
            else {
                throw DebugE2EError.windowsSpanMultipleDisplays
            }
            return (screen, CGDirectDisplayID(number.uint32Value))
        }
        guard let firstScreen = screens.first,
              screens.allSatisfy({ $0.1 == firstScreen.1 }),
              windows.allSatisfy({ firstScreen.0.frame.contains($0.frame) })
        else {
            throw DebugE2EError.windowsSpanMultipleDisplays
        }

        let bounds = windows.dropFirst().reduce(windows[0].frame) {
            $0.union($1.frame)
        }
        let layouts = windows.enumerated().map { order, window in
            DebugE2EWindowLayout(
                windowNumber: window.windowNumber,
                title: window.title,
                kind: window === mainWindow
                    ? "main"
                    : (window.isSheet ? "sheet" : "window"),
                order: order,
                frame: CGRect(
                    x: window.frame.minX - bounds.minX,
                    y: bounds.maxY - window.frame.maxY,
                    width: window.frame.width,
                    height: window.frame.height
                )
            )
        }
        let signature = layouts.map {
            String(
                format: "%d:%d:%.2f:%.2f:%.2f:%.2f",
                $0.windowNumber,
                $0.order,
                $0.frame.minX,
                $0.frame.minY,
                $0.frame.width,
                $0.frame.height
            )
        }.joined(separator: "|")

        return DebugE2EScene(
            windows: windows,
            bounds: bounds,
            screenFrame: firstScreen.0.frame,
            displayID: firstScreen.1,
            scale: firstScreen.0.backingScaleFactor,
            layouts: layouts,
            id: stableIdentifier("\(firstScreen.1)|\(signature)")
        )
    }

    func screenPoint(x: CGFloat, y: CGFloat) throws -> NSPoint {
        guard x.isFinite,
              y.isFinite,
              x >= 0,
              y >= 0,
              x < width,
              y < height
        else {
            throw DebugE2EError.invalidClickCoordinate
        }
        return NSPoint(x: bounds.minX + x, y: bounds.maxY - y)
    }

    func frontmostWindow(at screenPoint: NSPoint) throws -> NSWindow {
        guard let window = windows.first(where: {
            !$0.ignoresMouseEvents && $0.frame.contains(screenPoint)
        }) else {
            throw DebugE2EError.invalidClickCoordinate
        }
        return window
    }

    private static func stableIdentifier(_ value: String) -> String {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in value.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return String(hash, radix: 16)
    }
}

struct DebugE2EScreenshotResult {
    let url: URL
    let pixelWidth: Int
    let pixelHeight: Int
}

@MainActor
enum DebugE2ESceneCapture {
    static var authorizationMode: String {
        if #available(macOS 14.4, *) {
            return "currentProcess"
        }
        return "screenRecording"
    }

    static func capture(scene: DebugE2EScene) async throws -> CGImage {
        guard #available(macOS 14.0, *) else {
            throw DebugE2EError.captureUnavailable(
                "Real UI capture requires macOS 14 or newer"
            )
        }

        let content: SCShareableContent
        do {
            if #available(macOS 14.4, *) {
                content = try await SCShareableContent.currentProcess
            } else {
                guard CGPreflightScreenCaptureAccess() else {
                    throw DebugE2EError.screenRecordingPermissionRequired
                }
                content = try await SCShareableContent.excludingDesktopWindows(
                    true,
                    onScreenWindowsOnly: true
                )
            }
        } catch let error as DebugE2EError {
            throw error
        } catch {
            throw DebugE2EError.captureUnavailable(String(describing: error))
        }
        let processID = ProcessInfo.processInfo.processIdentifier
        guard let display = content.displays.first(where: {
            $0.displayID == scene.displayID
        }) else {
            throw DebugE2EError.captureUnavailable(
                "ScreenCaptureKit could not resolve the CueSeeker scene"
            )
        }
        let requiredWindowIDs = Set(scene.windows.map {
            CGWindowID($0.windowNumber)
        })
        let captureWindowsByID: [CGWindowID: SCWindow] = Dictionary(
            uniqueKeysWithValues: content.windows.compactMap {
                window -> (CGWindowID, SCWindow)? in
                guard window.owningApplication?.processID == processID,
                      window.isOnScreen,
                      requiredWindowIDs.contains(window.windowID)
                else {
                    return nil
                }
                return (window.windowID, window)
            }
        )
        let captureWindows = scene.windows.compactMap {
            captureWindowsByID[CGWindowID($0.windowNumber)]
        }
        guard Set(captureWindows.map(\.windowID)) == requiredWindowIDs else {
            throw DebugE2EError.captureUnavailable(
                "ScreenCaptureKit could not capture every visible CueSeeker window"
            )
        }

        let filter = SCContentFilter(
            display: display,
            including: captureWindows
        )
        let configuration = SCStreamConfiguration()
        configuration.sourceRect = scene.sourceRect
        configuration.width = scene.pixelWidth
        configuration.height = scene.pixelHeight
        configuration.showsCursor = false
        configuration.scalesToFit = false

        do {
            return try await SCScreenshotManager.captureImage(
                contentFilter: filter,
                configuration: configuration
            )
        } catch {
            throw DebugE2EError.captureUnavailable(String(describing: error))
        }
    }
}

enum DebugE2EScreenshotWriter {
    static func write(
        image: CGImage,
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
        let bitmap = NSBitmapImageRep(cgImage: image)
        guard let png = bitmap.representation(using: .png, properties: [:]) else {
            throw DebugE2EError.screenshotEncodingFailed
        }
        let outputURL = directory
            .appendingPathComponent(name)
            .appendingPathExtension("png")
        do {
            try png.write(to: outputURL, options: .atomic)
        } catch {
            throw DebugE2EError.screenshotSaveFailed(String(describing: error))
        }
        return DebugE2EScreenshotResult(
            url: outputURL,
            pixelWidth: image.width,
            pixelHeight: image.height
        )
    }
}

@MainActor
enum DebugE2EClickDispatcher {
    static func click(
        x: CGFloat,
        y: CGFloat,
        scene: DebugE2EScene,
        postEvents: (NSEvent, NSEvent) -> Void = { mouseDown, mouseUp in
            NSApplication.shared.postEvent(mouseDown, atStart: false)
            NSApplication.shared.postEvent(mouseUp, atStart: false)
        }
    ) throws {
        let screenPoint = try scene.screenPoint(x: x, y: y)
        let window = try scene.frontmostWindow(at: screenPoint)
        let location = window.convertPoint(fromScreen: screenPoint)
        NSApplication.shared.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
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

        postEvents(mouseDown, mouseUp)
    }
}

@MainActor
enum DebugE2EScrollDispatcher {
    static func scroll(
        x: CGFloat,
        y: CGFloat,
        deltaY: Int32,
        scene: DebugE2EScene,
        postEvent: (NSEvent) -> Void = {
            NSApplication.shared.postEvent($0, atStart: false)
        }
    ) throws {
        guard deltaY != 0 else {
            throw DebugE2EError.invalidScrollDelta
        }

        let screenPoint: NSPoint
        let window: NSWindow
        do {
            screenPoint = try scene.screenPoint(x: x, y: y)
            window = try scene.frontmostWindow(at: screenPoint)
        } catch DebugE2EError.invalidClickCoordinate {
            throw DebugE2EError.invalidScrollCoordinate
        }

        let location = window.convertPoint(fromScreen: screenPoint)
        guard let mouseEvent = NSEvent.mouseEvent(
            with: .mouseMoved,
            location: location,
            modifierFlags: [],
            timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: window.windowNumber,
            context: nil,
            eventNumber: 0,
            clickCount: 0,
            pressure: 0
        ),
        let cgEvent = mouseEvent.cgEvent
        else {
            throw DebugE2EError.scrollEventCreationFailed
        }
        cgEvent.type = .scrollWheel
        cgEvent.setIntegerValueField(
            .scrollWheelEventDeltaAxis1,
            value: Int64(deltaY)
        )
        cgEvent.setIntegerValueField(
            .scrollWheelEventFixedPtDeltaAxis1,
            value: Int64(deltaY) << 16
        )
        cgEvent.setIntegerValueField(
            .scrollWheelEventPointDeltaAxis1,
            value: Int64(deltaY)
        )
        cgEvent.setIntegerValueField(
            .scrollWheelEventIsContinuous,
            value: 0
        )
        guard let event = NSEvent(cgEvent: cgEvent),
              event.window === window
        else {
            throw DebugE2EError.scrollEventCreationFailed
        }

        postEvent(event)
    }
}

struct DebugE2EKeyStroke: Equatable {
    let key: String
    let modifiers: [String]
    let modifierFlags: NSEvent.ModifierFlags
    let keyCode: UInt16
    let characters: String
    let charactersIgnoringModifiers: String

    init(key: String, modifiers: [String]) throws {
        let definition = try Self.definition(for: key)
        var requestedModifiers: Set<String> = []
        var flags: NSEvent.ModifierFlags = []
        for modifier in modifiers {
            let normalized = modifier.lowercased()
            guard let flag = Self.modifierFlags[normalized] else {
                throw DebugE2EError.unsupportedModifier(modifier)
            }
            requestedModifiers.insert(normalized)
            flags.insert(flag)
        }

        let characters = flags.contains(.shift)
            ? definition.shiftedCharacters
            : definition.characters
        self.key = definition.key
        self.modifiers = Self.modifierOrder.filter(
            requestedModifiers.contains
        )
        modifierFlags = flags
        keyCode = definition.keyCode
        self.characters = characters
        charactersIgnoringModifiers = characters
    }

    private struct Definition {
        let key: String
        let keyCode: UInt16
        let characters: String
        let shiftedCharacters: String
    }

    private static let modifierOrder = [
        "command",
        "option",
        "control",
        "shift",
        "function",
    ]

    private static let modifierFlags: [String: NSEvent.ModifierFlags] = [
        "command": .command,
        "option": .option,
        "control": .control,
        "shift": .shift,
        "function": .function,
    ]

    private static let letterKeyCodes: [String: UInt16] = [
        "a": UInt16(kVK_ANSI_A),
        "b": UInt16(kVK_ANSI_B),
        "c": UInt16(kVK_ANSI_C),
        "d": UInt16(kVK_ANSI_D),
        "e": UInt16(kVK_ANSI_E),
        "f": UInt16(kVK_ANSI_F),
        "g": UInt16(kVK_ANSI_G),
        "h": UInt16(kVK_ANSI_H),
        "i": UInt16(kVK_ANSI_I),
        "j": UInt16(kVK_ANSI_J),
        "k": UInt16(kVK_ANSI_K),
        "l": UInt16(kVK_ANSI_L),
        "m": UInt16(kVK_ANSI_M),
        "n": UInt16(kVK_ANSI_N),
        "o": UInt16(kVK_ANSI_O),
        "p": UInt16(kVK_ANSI_P),
        "q": UInt16(kVK_ANSI_Q),
        "r": UInt16(kVK_ANSI_R),
        "s": UInt16(kVK_ANSI_S),
        "t": UInt16(kVK_ANSI_T),
        "u": UInt16(kVK_ANSI_U),
        "v": UInt16(kVK_ANSI_V),
        "w": UInt16(kVK_ANSI_W),
        "x": UInt16(kVK_ANSI_X),
        "y": UInt16(kVK_ANSI_Y),
        "z": UInt16(kVK_ANSI_Z),
    ]

    private static let digitKeyCodes: [String: UInt16] = [
        "0": UInt16(kVK_ANSI_0),
        "1": UInt16(kVK_ANSI_1),
        "2": UInt16(kVK_ANSI_2),
        "3": UInt16(kVK_ANSI_3),
        "4": UInt16(kVK_ANSI_4),
        "5": UInt16(kVK_ANSI_5),
        "6": UInt16(kVK_ANSI_6),
        "7": UInt16(kVK_ANSI_7),
        "8": UInt16(kVK_ANSI_8),
        "9": UInt16(kVK_ANSI_9),
    ]

    private static let shiftedDigits: [String: String] = [
        "0": ")",
        "1": "!",
        "2": "@",
        "3": "#",
        "4": "$",
        "5": "%",
        "6": "^",
        "7": "&",
        "8": "*",
        "9": "(",
    ]

    private static func definition(for key: String) throws -> Definition {
        let normalized = key.lowercased()
        if let keyCode = letterKeyCodes[normalized] {
            return Definition(
                key: normalized,
                keyCode: keyCode,
                characters: normalized,
                shiftedCharacters: normalized.uppercased()
            )
        }
        if let keyCode = digitKeyCodes[normalized],
           let shiftedCharacter = shiftedDigits[normalized] {
            return Definition(
                key: normalized,
                keyCode: keyCode,
                characters: normalized,
                shiftedCharacters: shiftedCharacter
            )
        }

        switch normalized {
        case "enter":
            return Definition(
                key: "enter",
                keyCode: UInt16(kVK_Return),
                characters: "\r",
                shiftedCharacters: "\r"
            )
        case "escape":
            return Definition(
                key: "escape",
                keyCode: UInt16(kVK_Escape),
                characters: "\u{1b}",
                shiftedCharacters: "\u{1b}"
            )
        case "tab":
            return Definition(
                key: "tab",
                keyCode: UInt16(kVK_Tab),
                characters: "\t",
                shiftedCharacters: "\t"
            )
        case "space":
            return Definition(
                key: "space",
                keyCode: UInt16(kVK_Space),
                characters: " ",
                shiftedCharacters: " "
            )
        case "leftarrow":
            return Definition(
                key: "leftArrow",
                keyCode: UInt16(kVK_LeftArrow),
                characters: "\u{f702}",
                shiftedCharacters: "\u{f702}"
            )
        case "rightarrow":
            return Definition(
                key: "rightArrow",
                keyCode: UInt16(kVK_RightArrow),
                characters: "\u{f703}",
                shiftedCharacters: "\u{f703}"
            )
        case "uparrow":
            return Definition(
                key: "upArrow",
                keyCode: UInt16(kVK_UpArrow),
                characters: "\u{f700}",
                shiftedCharacters: "\u{f700}"
            )
        case "downarrow":
            return Definition(
                key: "downArrow",
                keyCode: UInt16(kVK_DownArrow),
                characters: "\u{f701}",
                shiftedCharacters: "\u{f701}"
            )
        default:
            throw DebugE2EError.unsupportedKey(key)
        }
    }
}

@MainActor
enum DebugE2EKeyboardDispatcher {
    static func keyPress(
        _ keyStroke: DebugE2EKeyStroke,
        window: NSWindow,
        postEvents: (NSEvent, NSEvent) -> Void = { keyDown, keyUp in
            NSApplication.shared.postEvent(keyDown, atStart: false)
            NSApplication.shared.postEvent(keyUp, atStart: false)
        }
    ) throws {
        let timestamp = ProcessInfo.processInfo.systemUptime
        guard let keyDown = NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: keyStroke.modifierFlags,
            timestamp: timestamp,
            windowNumber: window.windowNumber,
            context: nil,
            characters: keyStroke.characters,
            charactersIgnoringModifiers: keyStroke.charactersIgnoringModifiers,
            isARepeat: false,
            keyCode: keyStroke.keyCode
        ),
        let keyUp = NSEvent.keyEvent(
            with: .keyUp,
            location: .zero,
            modifierFlags: keyStroke.modifierFlags,
            timestamp: timestamp + 0.001,
            windowNumber: window.windowNumber,
            context: nil,
            characters: keyStroke.characters,
            charactersIgnoringModifiers: keyStroke.charactersIgnoringModifiers,
            isARepeat: false,
            keyCode: keyStroke.keyCode
        ) else {
            throw DebugE2EError.keyboardEventCreationFailed
        }

        postEvents(keyDown, keyUp)
    }
}

@MainActor
final class DebugE2EController {
    private weak var mainWindow: NSWindow?
    private let artifactDirectory: URL
    private var inputTask: Task<Void, Never>?
    private var interactionRevision: UInt64 = 0

    static func isRequested(
        arguments: [String] = ProcessInfo.processInfo.arguments
    ) -> Bool {
        arguments.contains("--cueseeker-debug-e2e")
    }

    init(mainWindow: NSWindow) throws {
        self.mainWindow = mainWindow
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
        startInput()
        guard #available(macOS 14.0, *) else {
            Self.report(
                error: DebugE2EError.captureUnavailable(
                    "Real UI capture requires macOS 14 or newer"
                )
            )
            return
        }
        if #available(macOS 14.4, *) {
            reportScene(status: "ready")
            return
        }
        guard CGPreflightScreenCaptureAccess() else {
            let granted = CGRequestScreenCaptureAccess()
            Self.write([
                "status": "error",
                "code": DebugE2EError.screenRecordingPermissionRequired.code,
                "message": DebugE2EError.screenRecordingPermissionRequired.description,
                "permissionGranted": granted,
                "restartRequired": granted,
                "artifactDirectory": artifactDirectory.path,
            ])
            return
        }
        reportScene(status: "ready")
    }

    static func reportStartupError(_ error: Error) {
        report(error: error)
    }

    private func startInput() {
        inputTask = Task.detached(priority: .utility) { [weak self] in
            while !Task.isCancelled, let line = readLine() {
                await self?.receive(line)
            }
        }
    }

    private func reportScene(status: String, action: String? = nil) {
        do {
            guard let mainWindow else {
                throw DebugE2EError.noVisibleWindows
            }
            let scene = try DebugE2EScene.current(mainWindow: mainWindow)
            var payload = scenePayload(scene)
            payload["status"] = status
            payload["artifactDirectory"] = artifactDirectory.path
            payload["captureAuthorization"] = DebugE2ESceneCapture.authorizationMode
            payload["screenRecordingPermissionGranted"] = CGPreflightScreenCaptureAccess()
            if let action {
                payload["action"] = action
            }
            Self.write(payload)
        } catch {
            Self.report(error: error)
        }
    }

    private func receive(_ line: String) async {
        do {
            guard let mainWindow else {
                throw DebugE2EError.noVisibleWindows
            }
            switch try DebugE2ECommand(line: line) {
            case .inspect:
                reportScene(status: "ok", action: "inspect")
            case .capture(let name):
                let scene = try DebugE2EScene.current(mainWindow: mainWindow)
                let image = try await DebugE2ESceneCapture.capture(scene: scene)
                let currentScene = try DebugE2EScene.current(mainWindow: mainWindow)
                guard currentScene.id == scene.id else {
                    throw DebugE2EError.sceneChanged
                }
                let result = try DebugE2EScreenshotWriter.write(
                    image: image,
                    directory: artifactDirectory,
                    name: name
                )
                var payload = scenePayload(currentScene)
                payload.merge([
                    "status": "ok",
                    "action": "capture",
                    "path": result.url.path,
                    "pixelWidth": result.pixelWidth,
                    "pixelHeight": result.pixelHeight,
                ], uniquingKeysWith: { _, new in new })
                Self.write(payload)
            case .click(let x, let y, let sceneID):
                let scene = try DebugE2EScene.current(mainWindow: mainWindow)
                guard commandSceneID(for: scene) == sceneID else {
                    throw DebugE2EError.sceneChanged
                }
                try DebugE2EClickDispatcher.click(x: x, y: y, scene: scene)
                try await Task.sleep(for: .milliseconds(50))
                interactionRevision &+= 1
                let currentScene = try DebugE2EScene.current(mainWindow: mainWindow)
                var payload = scenePayload(currentScene)
                payload.merge([
                    "status": "ok",
                    "action": "click",
                    "x": x,
                    "y": y,
                ], uniquingKeysWith: { _, new in new })
                Self.write(payload)
            case .scroll(let x, let y, let deltaY, let sceneID):
                let scene = try DebugE2EScene.current(mainWindow: mainWindow)
                guard commandSceneID(for: scene) == sceneID else {
                    throw DebugE2EError.sceneChanged
                }
                try DebugE2EScrollDispatcher.scroll(
                    x: x,
                    y: y,
                    deltaY: deltaY,
                    scene: scene
                )
                try await Task.sleep(for: .milliseconds(50))
                interactionRevision &+= 1
                let currentScene = try DebugE2EScene.current(mainWindow: mainWindow)
                var payload = scenePayload(currentScene)
                payload.merge([
                    "status": "ok",
                    "action": "scroll",
                    "x": x,
                    "y": y,
                    "deltaY": deltaY,
                ], uniquingKeysWith: { _, new in new })
                Self.write(payload)
            case .keyPress(let key, let modifiers, let sceneID):
                let scene = try DebugE2EScene.current(mainWindow: mainWindow)
                guard commandSceneID(for: scene) == sceneID else {
                    throw DebugE2EError.sceneChanged
                }
                guard NSApplication.shared.isActive,
                      let keyWindow = NSApplication.shared.keyWindow,
                      keyWindow.isVisible,
                      !keyWindow.isMiniaturized,
                      scene.windows.contains(where: { $0 === keyWindow })
                else {
                    throw DebugE2EError.keyWindowUnavailable
                }
                let keyStroke = try DebugE2EKeyStroke(
                    key: key,
                    modifiers: modifiers
                )
                try DebugE2EKeyboardDispatcher.keyPress(
                    keyStroke,
                    window: keyWindow
                )
                try await Task.sleep(for: .milliseconds(50))
                interactionRevision &+= 1
                let currentScene = try DebugE2EScene.current(
                    mainWindow: mainWindow
                )
                var payload = scenePayload(currentScene)
                payload.merge([
                    "status": "ok",
                    "action": "keyPress",
                    "key": keyStroke.key,
                    "modifiers": keyStroke.modifiers,
                ], uniquingKeysWith: { _, new in new })
                Self.write(payload)
            }
        } catch {
            Self.report(error: error)
        }
    }

    private func scenePayload(_ scene: DebugE2EScene) -> [String: Any] {
        var payload = scene.json
        payload["sceneID"] = commandSceneID(for: scene)
        return payload
    }

    private func commandSceneID(for scene: DebugE2EScene) -> String {
        "\(scene.id)-\(interactionRevision)"
    }

    private static func report(error: Error) {
        let debugError = error as? DebugE2EError
        write([
            "status": "error",
            "code": debugError?.code ?? "operationFailed",
            "message": String(describing: error),
        ])
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
