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

    /// Asks where the package goes, then hands the export to the queue.
    ///
    /// The destination is chosen here rather than when the task reaches the
    /// front, so a queued task can already name the file and folder it is going
    /// to write, and so the reader is asked once, while they are still looking
    /// at the selection they just exported.
    private func exportAnkiItems(_ items: [AnkiExportItem]) {
        guard !items.isEmpty, let destinationURL = ankiExportDestinationURL() else {
            return
        }

        tasks.enqueueAnkiExport(items: items, destinationURL: destinationURL)
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
