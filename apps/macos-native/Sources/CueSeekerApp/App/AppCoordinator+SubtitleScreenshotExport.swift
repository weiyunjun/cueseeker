import AppKit
import CueSeekerCore
import CueSeekerPlayback
import Foundation
import UniformTypeIdentifiers

@MainActor
extension AppCoordinator {
    func exportSubtitleScreenshots(_ items: [SubtitleScreenshotExportItem]) {
        guard !items.isEmpty else {
            return
        }

        if items.count == 1 {
            guard let item = items.first,
                  let destinationURL = subtitleScreenshotDestinationURL(for: item)
            else {
                return
            }

            Task {
                do {
                    try await SubtitleScreenshotExporter.exportScreenshot(item: item, to: destinationURL)
                } catch {
                    print("Failed to export subtitle screenshot: \(error)")
                }
            }
            return
        }

        guard let directoryURL = subtitleScreenshotDirectoryURL() else {
            return
        }

        Task {
            do {
                try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
                try await SubtitleScreenshotExporter.exportScreenshots(items: items, toDirectory: directoryURL)
            } catch {
                print("Failed to export subtitle screenshots: \(error)")
            }
        }
    }

    func exportSubtitleCollage(_ items: [SubtitleScreenshotExportItem]) {
        guard SubtitleScreenshotExporter.canExportCollage(items),
              let destinationURL = subtitleCollageDestinationURL(for: items)
        else {
            return
        }

        Task {
            do {
                try await SubtitleScreenshotExporter.exportCollage(items: items, to: destinationURL)
            } catch {
                print("Failed to export subtitle collage: \(error)")
            }
        }
    }

    func subtitleScreenshotItem(for result: SubtitleSearchResult) -> SubtitleScreenshotExportItem {
        SubtitleScreenshotExportItem(
            displayTitle: subtitleScreenshotDisplayTitle(for: result),
            videoPath: result.videoPath,
            subtitlePath: result.subtitlePath,
            subtitleFormat: result.subtitleFormat,
            startMilliseconds: result.startMilliseconds,
            endMilliseconds: result.endMilliseconds,
            cueDisplayOrder: result.cueDisplayOrder,
            cueEventIndex: result.cueEventIndex,
            textLines: subtitleDisplayLines(content: result.content, cueLines: result.cueLines),
            subtitleSource: playbackSubtitleSource(for: result)
        )
    }

    func subtitleScreenshotItem(for shiori: Shiori, displayTitle: String) -> SubtitleScreenshotExportItem {
        SubtitleScreenshotExportItem(
            displayTitle: displayTitle,
            videoPath: shiori.videoPath,
            subtitlePath: shiori.subtitlePath,
            subtitleFormat: shiori.subtitleFormat,
            startMilliseconds: shiori.startMilliseconds,
            endMilliseconds: shiori.endMilliseconds,
            cueDisplayOrder: shiori.cueDisplayOrder,
            cueEventIndex: shiori.cueEventIndex,
            textLines: subtitleDisplayLines(content: shiori.content, cueLines: shiori.cueLines),
            subtitleSource: playbackSubtitleSource(for: shiori)
        )
    }

    private func subtitleScreenshotDestinationURL(for item: SubtitleScreenshotExportItem) -> URL? {
        let panel = NSSavePanel()
        panel.title = "Export Screenshot"
        panel.nameFieldStringValue = SubtitleScreenshotExporter.defaultScreenshotFileName(for: item)
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

    private func subtitleScreenshotDirectoryURL() -> URL? {
        let panel = NSSavePanel()
        panel.title = "Export Screenshots"
        panel.nameFieldStringValue = SubtitleScreenshotExporter.defaultScreenshotFolderName()
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false

        guard panel.runModal() == .OK else {
            return nil
        }
        return panel.url
    }

    private func subtitleCollageDestinationURL(for items: [SubtitleScreenshotExportItem]) -> URL? {
        let panel = NSSavePanel()
        panel.title = "Export Collage"
        panel.nameFieldStringValue = SubtitleScreenshotExporter.defaultCollageFileName(for: items)
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

    private func subtitleScreenshotDisplayTitle(for result: SubtitleSearchResult) -> String {
        guard !result.displayTitle.isEmpty else {
            return SubtitleDisplayTitleResolver.displayTitle(forSubtitlePath: result.subtitlePath)
        }
        return result.displayTitle
    }
}
