import AppKit
import CueSeekerPlayback

enum PlaybackScreenshotPasteboardError: Error {
    case pngEncodingFailed
    case pasteboardWriteFailed
}

@MainActor
enum PlaybackScreenshotPasteboardWriter {
    static func write(
        _ screenshot: PlaybackScreenshotImage,
        to pasteboard: NSPasteboard = .general
    ) throws {
        let representation = NSBitmapImageRep(cgImage: screenshot.image)
        guard let pngData = representation.representation(using: .png, properties: [:]) else {
            throw PlaybackScreenshotPasteboardError.pngEncodingFailed
        }

        pasteboard.clearContents()
        guard pasteboard.setData(pngData, forType: .png) else {
            throw PlaybackScreenshotPasteboardError.pasteboardWriteFailed
        }
    }
}
