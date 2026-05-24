import AppKit
import Foundation
import UniformTypeIdentifiers
import CueSeekerCore

@MainActor
extension AppCoordinator {
    func exportSearchResultGroupToAnki(_ group: SearchResultFileGroup) {
        let items = group.results.map { result in
            AnkiExportItem(
                videoPath: result.videoPath,
                startMilliseconds: result.startMilliseconds,
                endMilliseconds: result.endMilliseconds,
                textLines: subtitleDisplayLines(content: result.content, cueLines: result.cueLines)
            )
        }
        exportAnkiItems(items, displayTitle: group.subtitleDisplayTitle)
    }

    func exportShioriGroupToAnki(_ group: ShioriFileGroup) {
        let items = group.shioris.map { shiori in
            AnkiExportItem(
                videoPath: shiori.videoPath,
                startMilliseconds: shiori.startMilliseconds,
                endMilliseconds: shiori.endMilliseconds,
                textLines: subtitleDisplayLines(content: shiori.content, cueLines: shiori.cueLines)
            )
        }
        exportAnkiItems(items, displayTitle: group.subtitleDisplayTitle)
    }

    private func exportAnkiItems(_ items: [AnkiExportItem], displayTitle: String) {
        guard !items.isEmpty, let destinationURL = ankiExportDestinationURL(displayTitle: displayTitle) else {
            return
        }

        Task {
            do {
                try await AnkiPackageExporter.export(
                    deckDisplayTitle: displayTitle,
                    items: items,
                    to: destinationURL
                )
            } catch {
                print("Failed to export Anki package: \(error)")
            }
        }
    }

    private func ankiExportDestinationURL(displayTitle: String) -> URL? {
        let panel = NSSavePanel()
        panel.title = "Export Anki Package"
        panel.nameFieldStringValue = AnkiPackageExporter.defaultFileName(for: displayTitle)
        if let apkgType = UTType(filenameExtension: "apkg") {
            panel.allowedContentTypes = [apkgType]
        }
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false

        guard panel.runModal() == .OK else {
            return nil
        }

        return panel.url
    }
}
