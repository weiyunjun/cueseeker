import AppKit
import CueSeekerPlayback
import ImageIO
import UniformTypeIdentifiers

enum PlaybackScreenshotPasteboardError: Error {
    case pngEncodingFailed
    case pasteboardWriteFailed
}

enum PlaybackScreenshotPasteboardWriter {
    static func pngData(
        for image: CGImage
    ) throws -> Data {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data,
            UTType.png.identifier as CFString,
            1,
            nil
        ) else {
            throw PlaybackScreenshotPasteboardError.pngEncodingFailed
        }

        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw PlaybackScreenshotPasteboardError.pngEncodingFailed
        }
        return data as Data
    }

    @MainActor
    static func write(
        _ pngData: Data,
        to pasteboard: NSPasteboard = .general
    ) throws {
        pasteboard.clearContents()
        guard pasteboard.setData(pngData, forType: .png) else {
            throw PlaybackScreenshotPasteboardError.pasteboardWriteFailed
        }
    }
}
