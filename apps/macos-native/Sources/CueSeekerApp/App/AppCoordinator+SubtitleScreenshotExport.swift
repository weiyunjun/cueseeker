import AppKit
import Foundation
import UniformTypeIdentifiers

@MainActor
enum SubtitleCollageSavePanel {
    static func destinationURL(defaultFileName: String) -> URL? {
        let panel = NSSavePanel()
        panel.title = L("playback.collage.export")
        panel.nameFieldStringValue = defaultFileName
        if let pngType = UTType(filenameExtension: "png") {
            panel.allowedContentTypes = [pngType]
        }
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false

        guard panel.runModal() == .OK else {
            return nil
        }
        return panel.url
    }
}
