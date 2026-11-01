import AppKit
import Foundation
import UniformTypeIdentifiers

@MainActor
enum SubtitleCollageSavePanel {
    static func destinationURL(defaultFileName: String) -> URL? {
        let startedAt = DebugInteractionLatencyProbe.now()
        let panel = NSSavePanel()
        panel.title = L("playback.collage.export")
        panel.nameFieldStringValue = defaultFileName
        if let pngType = UTType(filenameExtension: "png") {
            panel.allowedContentTypes = [pngType]
        }
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        let panelPresentedAt = DebugInteractionLatencyProbe.now()

        let response = panel.runModal()
        DebugInteractionLatencyProbe.recordSystemFilePanel(
            panelType: "NSSavePanel",
            trigger: "export_subtitle_collage",
            mode: "modal",
            startedAt: startedAt,
            panelPresentedAt: panelPresentedAt,
            didSelect: response == .OK
        )
        guard response == .OK else {
            return nil
        }
        return panel.url
    }
}
