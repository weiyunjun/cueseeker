import AppKit
import Foundation
import CueSeekerCore

@MainActor
extension AppCoordinator {
    func exportSearchResultsToAnki(_ selection: [(result: SubtitleSearchResult, row: SubtitleTableRow)]) {
        openAnkiExportDialog(selection.map { result, row in
            Self.ankiExportItem(
                for: result,
                row: row,
                deckDisplayTitle: result.displayTitle
            )
        })
    }

    func exportExcerptsToAnki(_ selection: [(excerpt: Excerpt, row: SubtitleTableRow)]) {
        openAnkiExportDialog(selection.map { excerpt, row in
            Self.ankiExportItem(
                for: excerpt,
                row: row,
                deckDisplayTitle: excerpt.displayTitle
            )
        })
    }

    /// The card takes its Display Title, Time Range, Cue Group lines and Deep
    /// Link from the table row, so it shows what the row shows.
    nonisolated static func ankiExportItem(
        for result: SubtitleSearchResult,
        row: SubtitleTableRow,
        deckDisplayTitle: String
    ) -> AnkiExportItem {
        AnkiExportItem(
            deckDisplayTitle: deckDisplayTitle,
            videoPath: result.videoPath,
            startMilliseconds: result.startMilliseconds,
            endMilliseconds: result.endMilliseconds,
            text: result.content,
            displayTitle: row.displayTitle,
            timeRange: row.timeRange,
            cueGroupOtherTexts: row.additionalCueTexts,
            cueID: row.primaryCueID,
            subtitlePath: result.subtitlePath
        )
    }

    nonisolated static func ankiExportItem(
        for excerpt: Excerpt,
        row: SubtitleTableRow,
        deckDisplayTitle: String
    ) -> AnkiExportItem {
        AnkiExportItem(
            deckDisplayTitle: deckDisplayTitle,
            videoPath: excerpt.videoPath,
            startMilliseconds: excerpt.startMilliseconds,
            endMilliseconds: excerpt.endMilliseconds,
            text: excerpt.content,
            displayTitle: row.displayTitle,
            timeRange: row.timeRange,
            cueGroupOtherTexts: row.additionalCueTexts,
            cueID: row.primaryCueID,
            subtitlePath: excerpt.subtitlePath
        )
    }

    /// Opens the dialog on the choices the reader left it with last time.
    private func openAnkiExportDialog(_ items: [AnkiExportItem]) {
        guard !items.isEmpty else {
            return
        }

        // Each card's audio comes from its video's default audio track.
        var audioTrackIndexes: [String: Int] = [:]
        let items = items.map { item in
            var item = item
            let index = audioTrackIndexes[item.videoPath]
                ?? defaultAudioTrackIndex(forVideoPath: item.videoPath)
            audioTrackIndexes[item.videoPath] = index
            item.audioTrackIndex = index
            return item
        }

        tasks.ankiExportSession = AnkiExportSession(
            items: items,
            options: settings.ankiExportOptions,
            folderURL: ankiExportFolderURL(),
            onOptionsChange: { [weak self] options in
                self?.settings.ankiExportOptions = options
            }
        )
    }

    /// The folder last chosen, or Downloads when none was or it is gone.
    private func ankiExportFolderURL() -> URL {
        var isDirectory: ObjCBool = false
        guard let path = settings.ankiExportFolderPath,
              FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory),
              isDirectory.boolValue
        else {
            return URL.downloadsDirectory
        }
        return URL(fileURLWithPath: path, isDirectory: true)
    }

    func closeAnkiExportDialog() {
        tasks.ankiExportSession = nil
    }

    func beginChoosingAnkiExportFolder(_ session: AnkiExportSession) {
        guard tasks.ankiExportSession?.id == session.id else {
            return
        }

        let panel = NSOpenPanel()
        panel.title = L("anki_export.choose_folder")
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.directoryURL = session.folderURL

        let completion: (NSApplication.ModalResponse) -> Void = { [weak self, weak session] response in
            guard let self,
                  let session,
                  response == .OK,
                  let folderURL = panel.url,
                  self.tasks.ankiExportSession?.id == session.id
            else {
                return
            }
            session.folderURL = folderURL
            self.settings.ankiExportFolderPath = folderURL.path
        }

        if let window = NSApplication.shared.keyWindow ?? NSApplication.shared.mainWindow {
            panel.beginSheetModal(for: window, completionHandler: completion)
        } else {
            completion(panel.runModal())
        }
    }

    /// Queues the export. A file already at the destination is replaced only
    /// once the reader says so in the system's own warning.
    func confirmAnkiExport(_ session: AnkiExportSession) {
        guard tasks.ankiExportSession?.id == session.id else {
            return
        }

        let destinationURL = session.destinationURL
        guard FileManager.default.fileExists(atPath: destinationURL.path) else {
            enqueueAnkiExport(session, to: destinationURL)
            return
        }

        let alert = NSAlert()
        alert.alertStyle = .critical
        alert.messageText = L("anki_export.replace.title", destinationURL.lastPathComponent)
        alert.informativeText = L(
            "anki_export.replace.message",
            FileManager.default.displayName(atPath: session.folderURL.path)
        )
        // Added first, so it stands on the right; Return does not press it, so
        // no key replaces a file by accident.
        let replaceButton = alert.addButton(withTitle: L("anki_export.replace.confirm"))
        replaceButton.hasDestructiveAction = true
        replaceButton.keyEquivalent = ""
        let cancelButton = alert.addButton(withTitle: L("common.cancel"))
        cancelButton.keyEquivalent = "\u{1b}"

        let completion: (NSApplication.ModalResponse) -> Void = { [weak self, weak session] response in
            guard let self, let session, response == .alertFirstButtonReturn else {
                return
            }
            self.enqueueAnkiExport(session, to: destinationURL)
        }

        if let window = NSApplication.shared.keyWindow ?? NSApplication.shared.mainWindow {
            alert.beginSheetModal(for: window, completionHandler: completion)
        } else {
            completion(alert.runModal())
        }
    }

    private func enqueueAnkiExport(_ session: AnkiExportSession, to destinationURL: URL) {
        guard tasks.ankiExportSession?.id == session.id else {
            return
        }

        tasks.ankiExportSession = nil
        tasks.enqueueAnkiExport(
            items: session.items,
            options: session.options,
            destinationURL: destinationURL
        )
    }

    // MARK: - The task

    /// Hands the queue the export runner configured with the debug task delay.
    func configureAnkiExportRunner() {
        tasks.runExport = { items, options, destinationURL, onItemExported in
            await AppCoordinator.waitForDebugTaskDelay()
            try await TaskQueueStore.ankiExportRunner(
                items,
                options,
                destinationURL,
                onItemExported
            )
        }
    }
}
