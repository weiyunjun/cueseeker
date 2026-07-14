import Foundation
import CueSeekerCore

enum PlaybackNavigationCommand: Equatable {
    case back
    case forward
}

@MainActor
extension AppCoordinator {
    static let playbackNavigationHistoryLimit = 10_000

    func recordPlaybackNavigationEntry(_ payload: PlaybackNavigationPayload) {
        recordPlaybackNavigationEntry(payload, limit: Self.playbackNavigationHistoryLimit)
    }

    func recordPlaybackNavigationEntry(
        _ payload: PlaybackNavigationPayload,
        limit: Int
    ) {
        guard let database = subtitleDatabase else {
            return
        }

        do {
            let currentEntryID = try database.playbackNavigationCurrentEntryID()
            if let currentEntryID {
                try database.deletePlaybackNavigationEntries(after: currentEntryID)
            }

            let activeKind = playbackNavigationEntryKind(for: activePlaybackSource)
            let nextEntry: PlaybackNavigationEntry
            if activeKind == payload.kind,
               let currentEntryID,
               let updatedEntry = try database.updatePlaybackNavigationEntry(
                id: currentEntryID,
                payload: payload
               ) {
                nextEntry = updatedEntry
            } else {
                nextEntry = try database.appendPlaybackNavigationEntry(payload)
            }

            try database.setPlaybackNavigationCurrentEntryID(nextEntry.id)
            try database.prunePlaybackNavigationEntries(keepingLatest: limit)
        } catch {
            print("Failed to record playback navigation history: \(error)")
        }
    }

    func playbackNavigationPayload(for video: LibraryVideo) -> PlaybackNavigationPayload {
        .library(PlaybackNavigationLibraryPayload(videoPath: video.videoPath))
    }

    func playbackNavigationPayload(
        for result: SubtitleSearchResult,
        searchQuery: String? = nil,
        scopePaths: [String]? = nil
    ) -> PlaybackNavigationPayload {
        let indexRevision = (try? subtitleDatabase?.playbackNavigationIndexRevision()) ?? 0
        let resolvedScopePaths = scopePaths
            ?? indexing.selectedFolders.map { $0.standardizedFileURL.path }
        return .search(
            PlaybackNavigationSearchPayload(
                query: searchQuery
                    ?? search.searchQuery.trimmingCharacters(
                        in: .whitespacesAndNewlines
                    ),
                scopePaths: resolvedScopePaths,
                entryID: result.entryID,
                subtitlePath: result.subtitlePath,
                videoPath: result.videoPath,
                startMilliseconds: result.startMilliseconds,
                endMilliseconds: result.endMilliseconds,
                indexRevision: indexRevision
            )
        )
    }

    func playbackNavigationPayload(for shiori: Shiori) -> PlaybackNavigationPayload {
        .shiori(
            PlaybackNavigationShioriPayload(
                id: shiori.id,
                subtitlePath: shiori.subtitlePath,
                startMilliseconds: shiori.startMilliseconds,
                endMilliseconds: shiori.endMilliseconds
            )
        )
    }

    @discardableResult
    func executePlaybackNavigationCommand(
        _ command: PlaybackNavigationCommand
    ) -> Bool {
        guard let database = subtitleDatabase else {
            return false
        }

        do {
            guard let currentEntryID = try database.playbackNavigationCurrentEntryID() else {
                return false
            }
            let entries = try database.playbackNavigationEntries()
            guard let currentIndex = entries.firstIndex(where: { $0.id == currentEntryID }) else {
                return false
            }

            let targetIndex: Int
            switch command {
            case .back:
                targetIndex = currentIndex - 1
            case .forward:
                targetIndex = currentIndex + 1
            }

            guard entries.indices.contains(targetIndex) else {
                return false
            }

            let target = entries[targetIndex]
            switch target.payload {
            case .library(let payload):
                return restoreLibraryNavigationEntry(payload, targetEntryID: target.id)
            case .shiori(let payload):
                return restoreShioriNavigationEntry(payload, targetEntryID: target.id)
            case .search(let payload):
                return restoreSearchNavigationEntry(payload, targetEntryID: target.id)
            }
        } catch {
            return false
        }
    }

    private func restoreLibraryNavigationEntry(
        _ payload: PlaybackNavigationLibraryPayload,
        targetEntryID: Int64
    ) -> Bool {
        guard let video = library.libraryVideos.first(where: { $0.videoPath == payload.videoPath }) else {
            return false
        }
        openLibraryVideo(video, recordsNavigationHistory: false)
        try? subtitleDatabase?.setPlaybackNavigationCurrentEntryID(targetEntryID)
        return true
    }

    private func restoreShioriNavigationEntry(
        _ payload: PlaybackNavigationShioriPayload,
        targetEntryID: Int64
    ) -> Bool {
        let target = shiori.shioris.first(where: { $0.id == payload.id })
            ?? restoredShiori(for: payload)
        guard let target else {
            return false
        }
        openShiori(target, recordsNavigationHistory: false)
        try? subtitleDatabase?.setPlaybackNavigationCurrentEntryID(targetEntryID)
        return true
    }

    private func restoredShiori(for payload: PlaybackNavigationShioriPayload) -> Shiori? {
        guard let database = subtitleDatabase else {
            return nil
        }

        do {
            if let shiori = try database.shiori(id: payload.id) {
                return shiori
            }
            return try database.shiori(
                subtitleFile: URL(fileURLWithPath: payload.subtitlePath),
                startMilliseconds: payload.startMilliseconds,
                endMilliseconds: payload.endMilliseconds
            )
        } catch {
            print("Failed to restore Shiori navigation entry: \(error)")
            return nil
        }
    }

    private func restoreSearchNavigationEntry(
        _ payload: PlaybackNavigationSearchPayload,
        targetEntryID: Int64
    ) -> Bool {
        guard let database = subtitleDatabase else {
            return false
        }

        let trimmedQuery = payload.query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            return false
        }

        let scopeURLs = payload.scopePaths.map { URL(fileURLWithPath: $0) }
        let languageFilter = settings.primarySearchLanguage.searchLanguageFilter
        let revisionUnchanged: Bool
        let results: [SubtitleSearchResult]
        do {
            let currentRevision = try database.playbackNavigationIndexRevision()
            revisionUnchanged = (currentRevision == payload.indexRevision)
            results = try database.search(
                trimmedQuery,
                limit: 200,
                offset: 0,
                under: scopeURLs.isEmpty ? nil : scopeURLs,
                languageFilter: languageFilter
            )
        } catch {
            return false
        }

        let targetResult: SubtitleSearchResult?
        if revisionUnchanged,
           let savedEntryID = payload.entryID,
           let savedResult = results.first(where: { $0.entryID == savedEntryID }) {
            targetResult = savedResult
        } else {
            targetResult = results.first
        }

        guard let result = targetResult else {
            return false
        }

        workbenchLayout.selectPanelMode(.search)
        search.searchQuery = trimmedQuery
        startSearch(query: trimmedQuery, cursor: .start, appending: false, debounce: false)
        openSearchResult(result, recordsNavigationHistory: false)
        try? database.setPlaybackNavigationCurrentEntryID(targetEntryID)
        return true
    }

    func playbackNavigationAvailability() -> (canMoveBack: Bool, canMoveForward: Bool) {
        guard let database = subtitleDatabase else {
            return (false, false)
        }

        do {
            guard let currentEntryID = try database.playbackNavigationCurrentEntryID() else {
                return (false, false)
            }
            let entries = try database.playbackNavigationEntries()
            guard let index = entries.firstIndex(where: { $0.id == currentEntryID }) else {
                return (false, false)
            }
            return (index > 0, index < entries.count - 1)
        } catch {
            return (false, false)
        }
    }

    private func playbackNavigationEntryKind(
        for source: ActivePlaybackSource
    ) -> PlaybackNavigationEntryKind? {
        switch source {
        case .library:
            .library
        case .search:
            .search
        case .shiori:
            .shiori
        case .none:
            nil
        }
    }
}
