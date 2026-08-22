import AppKit
import Foundation
import UniformTypeIdentifiers
import CueSeekerCore

@MainActor
extension AppCoordinator {
    func exportShioriGroupToAnki(_ group: ShioriFileGroup) {
        let items = group.shioris.map { shiori in
            Self.ankiExportItem(
                for: shiori,
                deckDisplayTitle: group.subtitleDisplayTitle
            )
        }
        exportAnkiItems(items)
    }

    func exportSearchResultsToAnki(_ results: [SubtitleSearchResult]) {
        let items = results.map { result in
            Self.ankiExportItem(
                for: result,
                deckDisplayTitle: displayTitle(for: result)
            )
        }
        exportAnkiItems(items)
    }

    func exportShiorisToAnki(_ shioris: [Shiori]) {
        let items = shioris.map { shiori in
            Self.ankiExportItem(
                for: shiori,
                deckDisplayTitle: SubtitleDisplayTitleResolver.displayTitle(
                    forSubtitlePath: shiori.subtitlePath
                )
            )
        }
        exportAnkiItems(items)
    }

    nonisolated static func ankiExportItem(
        for result: SubtitleSearchResult,
        deckDisplayTitle: String
    ) -> AnkiExportItem {
        AnkiExportItem(
            deckDisplayTitle: deckDisplayTitle,
            videoPath: result.videoPath,
            startMilliseconds: result.startMilliseconds,
            endMilliseconds: result.endMilliseconds,
            text: result.content
        )
    }

    nonisolated static func ankiExportItem(
        for shiori: Shiori,
        deckDisplayTitle: String
    ) -> AnkiExportItem {
        AnkiExportItem(
            deckDisplayTitle: deckDisplayTitle,
            videoPath: shiori.videoPath,
            startMilliseconds: shiori.startMilliseconds,
            endMilliseconds: shiori.endMilliseconds,
            text: shiori.content
        )
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
        panel.title = L("export.anki_package")
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
