import AppKit
import Foundation
import UniformTypeIdentifiers
import CueSeekerCore

@MainActor
extension AppCoordinator {
    func exportSearchResultGroupToAnki(_ group: SearchResultFileGroup) {
        let items = group.results.map { result in
            AnkiExportItem(
                deckDisplayTitle: group.subtitleDisplayTitle,
                videoPath: result.videoPath,
                startMilliseconds: result.startMilliseconds,
                endMilliseconds: result.endMilliseconds,
                textLines: subtitleDisplayLines(content: result.content, cueLines: result.cueLines)
            )
        }
        exportAnkiItems(items)
    }

    func exportShioriGroupToAnki(_ group: ShioriFileGroup) {
        let items = group.shioris.map { shiori in
            AnkiExportItem(
                deckDisplayTitle: group.subtitleDisplayTitle,
                videoPath: shiori.videoPath,
                startMilliseconds: shiori.startMilliseconds,
                endMilliseconds: shiori.endMilliseconds,
                textLines: subtitleDisplayLines(content: shiori.content, cueLines: shiori.cueLines)
            )
        }
        exportAnkiItems(items)
    }

    func exportSearchResultsToAnki(_ results: [SubtitleSearchResult]) {
        let items = results.map { result in
            AnkiExportItem(
                deckDisplayTitle: displayTitle(for: result),
                videoPath: result.videoPath,
                startMilliseconds: result.startMilliseconds,
                endMilliseconds: result.endMilliseconds,
                textLines: subtitleDisplayLines(content: result.content, cueLines: result.cueLines)
            )
        }
        exportAnkiItems(items)
    }

    func exportShiorisToAnki(_ shioris: [Shiori]) {
        let items = shioris.map { shiori in
            AnkiExportItem(
                deckDisplayTitle: SubtitleDisplayTitleResolver.displayTitle(forSubtitlePath: shiori.subtitlePath),
                videoPath: shiori.videoPath,
                startMilliseconds: shiori.startMilliseconds,
                endMilliseconds: shiori.endMilliseconds,
                textLines: subtitleDisplayLines(content: shiori.content, cueLines: shiori.cueLines)
            )
        }
        exportAnkiItems(items)
    }

    private func exportAnkiItems(_ items: [AnkiExportItem]) {
        guard !items.isEmpty, let destinationURL = ankiExportDestinationURL() else {
            return
        }

        Task {
            do {
                try await AnkiPackageExporter.export(
                    items: items,
                    to: destinationURL
                )
            } catch {
                print("Failed to export Anki package: \(error)")
            }
        }
    }

    private func ankiExportDestinationURL() -> URL? {
        let panel = NSSavePanel()
        panel.title = "Export Anki Package"
        panel.nameFieldStringValue = AnkiPackageExporter.defaultFileName()
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

    private func displayTitle(for result: SubtitleSearchResult) -> String {
        guard !result.displayTitle.isEmpty else {
            return SubtitleDisplayTitleResolver.displayTitle(forSubtitlePath: result.subtitlePath)
        }
        return result.displayTitle
    }
}
