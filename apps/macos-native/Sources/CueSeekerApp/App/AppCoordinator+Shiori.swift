import AppKit
import Foundation
import CueSeekerCore
import CueSeekerPlayback

@MainActor
extension AppCoordinator {
    func hydrateShiorisAsync() {
        guard let database = subtitleDatabase else {
            return
        }

        shiorisTask?.cancel()
        shiorisTask = Task { [weak self] in
            do {
                let loadedShioris = try await Task.detached(priority: .userInitiated) {
                    try database.shioris()
                }.value

                guard !Task.isCancelled else { return }

                self?.applyShioris(loadedShioris)
            } catch {
                guard !Task.isCancelled else { return }
                print("Failed to load shioris asynchronously: \(error)")
            }
        }
    }

    func applyShioris(_ nextShioris: [Shiori]) {
        shiori.shioris = nextShioris.sorted(by: Self.shioriSort)
        rebuildShioriFileGroups()
    }

    func rebuildShioriFileGroups() {
        shiori.shioriFileGroups = Self.makeShioriFileGroups(
            from: shiori.shioris,
            collapsedGroupPaths: shiori.collapsedShioriGroupPaths
        )
        UIInvalidationProbe.count(
            "UI.ShioriPresentation.rebuilt",
            details: "groups=\(shiori.shioriFileGroups.count) rows=\(shiori.shioris.count)"
        )
    }

    func openShiori(_ shiori: Shiori, recordsNavigationHistory: Bool = true) {
        UIInvalidationProbe.mark(
            "ACTION UI.Shiori.opened",
            details: "time=\(String(format: "%.2f", Double(shiori.startMilliseconds) / 1000.0))"
        )
        rememberPlaybackOriginatingPanelModeIfEntering()
        saveCurrentLibraryPlaybackHistory()
        stopLibraryPlaybackHistoryTracking()
        if recordsNavigationHistory {
            recordPlaybackNavigationEntry(playbackNavigationPayload(for: shiori))
        }
        activePlaybackSource = .shiori
        self.shiori.selectedShiori = shiori
        search.selectedSearchResult = nil
        library.selectedLibraryVideo = nil
        playback.isPlaybackSurfaceExpanded = true
        Task { @MainActor in
            await Task.yield()
            play(shiori)
        }
    }

    func play(_ shiori: Shiori) {
        ensurePlayerInitialized()
        saveCurrentLibraryPlaybackHistory()
        stopLibraryPlaybackHistoryTracking()
        activePlaybackSource = .shiori
        playback.playbackStatus = .opening
        let subtitleCues = playbackSubtitleCues(for: shiori)
        playback.playbackViewModel?.setSubtitleCues(
            subtitleCues,
            currentTimeMilliseconds: shiori.startMilliseconds
        )

        do {
            let request = try PlaybackRequest(
                videoURL: URL(fileURLWithPath: shiori.videoPath),
                startMilliseconds: shiori.startMilliseconds,
                subtitleSource: playbackSubtitleSource(for: shiori)
            )

            guard let player else {
                throw PlaybackError.playbackPlayerUnavailable
            }

            if player.currentVideoURL?.standardizedFileURL.path == request.videoURL.standardizedFileURL.path {
                player.loadSubtitleSource(request.subtitleSource)
                try player.seek(toMilliseconds: request.startMilliseconds)
            } else {
                try player.open(request)
            }

            try player.setPaused(false)
            playback.playbackStatus = .playing
        } catch {
            playback.playbackViewModel?.clearSubtitleCues()
            playback.playbackStatus = .failed(Self.errorMessage(for: error))
        }
    }

    func toggleCurrentShiori() -> Bool {
        guard let currentPlaybackSubtitlePath,
              let currentPlaybackSubtitleFormat,
              let currentPlaybackVideoPath,
              let playbackViewModel = playback.playbackViewModel
        else {
            playback.playbackViewModel?.showShioriFeedback(.unavailable)
            return false
        }

        let subtitleFile = URL(fileURLWithPath: currentPlaybackSubtitlePath)
        let videoFile = URL(fileURLWithPath: currentPlaybackVideoPath)
        let videoName = library.selectedLibraryVideo?.videoName
            ?? search.selectedSearchResult?.videoName
            ?? shiori.selectedShiori?.videoName
            ?? videoFile.lastPathComponent
        let milliseconds = max(0, Int((playbackViewModel.currentTime * 1_000).rounded(.down)))

        guard let database = subtitleDatabase else {
            playbackViewModel.showShioriFeedback(.unavailable)
            return false
        }

        do {
            guard let selection = try database.cueTextSelection(
                forSubtitleFile: subtitleFile,
                atMilliseconds: milliseconds
            ), !selection.text.isEmpty else {
                playbackViewModel.showShioriFeedback(.unavailable)
                return false
            }

            if try database.shiori(
                subtitleFile: subtitleFile,
                startMilliseconds: selection.startMilliseconds,
                endMilliseconds: selection.endMilliseconds
            ) != nil {
                try database.removeShiori(
                    subtitleFile: subtitleFile,
                    startMilliseconds: selection.startMilliseconds,
                    endMilliseconds: selection.endMilliseconds
                )
                applyShioris(try database.shioris())
                playbackViewModel.showShioriFeedback(.removed)
                return true
            }

            _ = try database.upsertShiori(
                subtitleFile: subtitleFile,
                subtitleFormat: currentPlaybackSubtitleFormat,
                videoFile: videoFile,
                videoName: videoName,
                selection: selection
            )
            applyShioris(try database.shioris())
            playbackViewModel.showShioriFeedback(.saved)
            return true
        } catch {
            print("Failed to toggle Shiori: \(error)")
            playbackViewModel.showShioriFeedback(.unavailable)
            return false
        }
    }


    func toggleShioriGroup(_ subtitlePath: String) {
        UIInvalidationProbe.mark(
            "ACTION UI.ShioriGroup.toggled",
            details: "collapsedBefore=\(shiori.collapsedShioriGroupPaths.contains(subtitlePath))"
        )
        if shiori.collapsedShioriGroupPaths.contains(subtitlePath) {
            shiori.collapsedShioriGroupPaths.remove(subtitlePath)
        } else {
            shiori.collapsedShioriGroupPaths.insert(subtitlePath)
        }
        rebuildShioriFileGroups()
    }

    func collapseAllShioriGroups() {
        let groupPaths = Set(shiori.shioriFileGroups.map(\.id))
        guard !groupPaths.isEmpty else {
            return
        }

        let collapsedPaths = shiori.collapsedShioriGroupPaths.union(groupPaths)
        guard collapsedPaths != shiori.collapsedShioriGroupPaths else {
            return
        }

        shiori.collapsedShioriGroupPaths = collapsedPaths
        rebuildShioriFileGroups()
    }

    var canOpenPreviousShiori: Bool {
        guard activePlaybackSource == .shiori, let selectedShiori = shiori.selectedShiori else {
            return false
        }
        if let index = shiori.shioris.firstIndex(where: { $0.id == selectedShiori.id }), index > 0 {
            return true
        }
        return false
    }

    var canOpenNextShiori: Bool {
        guard activePlaybackSource == .shiori, let selectedShiori = shiori.selectedShiori else {
            return false
        }
        if let index = shiori.shioris.firstIndex(where: { $0.id == selectedShiori.id }), index < shiori.shioris.count - 1 {
            return true
        }
        return false
    }

    func openPreviousShiori() {
        let hasResult = canOpenPreviousShiori
        playback.playbackViewModel?.showShioriNavigationFeedback(direction: .previous, hasResult: hasResult)
        if hasResult {
            guard let selectedShiori = shiori.selectedShiori,
                  let index = shiori.shioris.firstIndex(where: { $0.id == selectedShiori.id }),
                  index > 0 else {
                return
            }
            openShiori(shiori.shioris[index - 1])
        }
    }

    func openNextShiori() {
        let hasResult = canOpenNextShiori
        playback.playbackViewModel?.showShioriNavigationFeedback(direction: .next, hasResult: hasResult)
        if hasResult {
            guard let selectedShiori = shiori.selectedShiori,
                  let index = shiori.shioris.firstIndex(where: { $0.id == selectedShiori.id }),
                  index < shiori.shioris.count - 1 else {
                return
            }
            openShiori(shiori.shioris[index + 1])
        }
    }
}
