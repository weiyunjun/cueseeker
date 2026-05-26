import Foundation
import CueSeekerCore

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

    func playbackNavigationPayload(for result: SubtitleSearchResult) -> PlaybackNavigationPayload {
        let indexRevision = (try? subtitleDatabase?.playbackNavigationIndexRevision()) ?? 0
        let scopePaths = indexing.selectedFolders.map { $0.standardizedFileURL.path }
        return .search(
            PlaybackNavigationSearchPayload(
                query: search.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines),
                scopePaths: scopePaths,
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
