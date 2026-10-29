import AppKit
import Foundation
import CueSeekerCore
import CueSeekerPlayback

/// Where a `Save to Excerpt` result is reported. The sentence is the same either
/// way; the Workbench shows it in a Toast and the playback surfaces show it in
/// the playback feedback, which is the only thing visible there.
enum ExcerptSaveReport {
    case toast
    case playbackFeedback
}

@MainActor
extension AppCoordinator {
    // MARK: - Forwarding Store Properties

    var excerptDatabase: ExcerptDatabase? {
        excerpt.database
    }

    var excerptListCoverStorage: ExcerptListCoverStorage {
        excerpt.coverStorage
    }

    var excerptNeedsReloadAfterIndexedContentMutation: Bool {
        get { excerpt.needsReloadAfterIndexedContentMutation }
        set { excerpt.needsReloadAfterIndexedContentMutation = newValue }
    }

    var pendingExcerptContentRemovalFolders: [URL] {
        get { excerpt.pendingContentRemovalFolders }
        set { excerpt.pendingContentRemovalFolders = newValue }
    }

    var excerptListCoverImportTask: Task<Void, Never>? {
        get { excerpt.listCoverImportTask }
        set { excerpt.listCoverImportTask = newValue }
    }

    var excerptListSaveTask: Task<Void, Never>? {
        get { excerpt.listSaveTask }
        set { excerpt.listSaveTask = newValue }
    }

    var excerptListOverviewTask: Task<Void, Never>? {
        get { excerpt.listOverviewTask }
        set { excerpt.listOverviewTask = newValue }
    }

    var excerptTableRowsTask: Task<Void, Never>? {
        get { excerpt.tableRowsTask }
        set { excerpt.tableRowsTask = newValue }
    }

    var excerptMutationTask: Task<Void, Never>? {
        get { excerpt.mutationTask }
        set { excerpt.mutationTask = newValue }
    }

    var excerptPlaybackNavigationScopeIDs: [Int64]? {
        get { excerpt.playbackNavigationScopeIDs }
        set { excerpt.playbackNavigationScopeIDs = newValue }
    }

    var excerptPlaybackNavigationSnapshot: (currentID: Int64, previousID: Int64?, nextID: Int64?)? {
        get { excerpt.playbackNavigationSnapshot }
        set { excerpt.playbackNavigationSnapshot = newValue }
    }

    // MARK: - List Overview & Route Navigation

    func loadExcerptListOverviewIfNeeded() {
        excerpt.loadListOverviewIfNeeded()
    }

    func reloadExcerptListOverview() {
        excerpt.reloadListOverview()
    }

    func openExcerptList(id: Int64) {
        navigateWorkbench(to: .excerptList(id: id))
    }

    func showExcerptListOverview() {
        navigateWorkbench(to: .excerpt)
    }

    func openRecentExcerpt(_ summary: ExcerptListSummary) {
        openExcerptListPlayback(
            summary,
            preferredExcerptID: summary.resumeExcerpt?.id
        )
    }

    func openExcerptListPlayback(_ summary: ExcerptListSummary) {
        openExcerptListPlayback(
            summary,
            preferredExcerptID: summary.resumeExcerpt?.id
        )
    }

    private func openExcerptListPlayback(
        _ summary: ExcerptListSummary,
        preferredExcerptID: Int64?
    ) {
        guard let resolution = excerpt.resolveListPlayback(
            summary,
            preferredExcerptID: preferredExcerptID
        ) else {
            return
        }
        switch resolution {
        case .resolved(let target, let navigationScopeIDs, let ordinal):
            openExcerpt(
                target,
                navigationScopeIDs: navigationScopeIDs,
                playlistScope: .explicitIDs(navigationScopeIDs),
                playlistSelectedOrdinal: ordinal,
                displayTitle: target.displayTitle
            )
        case .fallback(let fallbackTarget):
            openExcerpt(
                fallbackTarget,
                navigationScopeIDs: [],
                playlistScope: .explicitIDs([]),
                playlistSelectedOrdinal: nil,
                displayTitle: fallbackTarget.displayTitle,
                allowsUnavailableTarget: true
            )
        case .empty:
            reloadExcerptListOverview()
        }
    }

    // MARK: - Excerpt List Editor Forwarding

    func beginCreatingExcerptList(
        pendingTransfer: ExcerptListEditorPendingTransfer? = nil
    ) {
        excerpt.presentCreateExcerptListEditor(
            pendingTransfer: pendingTransfer,
            isExcerptInLibrary: { [weak self] id in
                self?.excerptIDsInLibrary(among: [id]).contains(id) == true
            },
            onCueNotInLibrary: { [weak self] in
                self?.toast.show(TableToastRequest.cueNotInLibrary)
            }
        )
    }

    func beginEditingExcerptList(_ list: ExcerptList) {
        excerpt.presentEditExcerptListEditor(list)
    }

    func closeExcerptListEditor() {
        excerpt.closeExcerptListEditor()
    }

    func validateExcerptListEditor(_ session: ExcerptListEditorSession) {
        excerpt.validateExcerptListEditor(session)
    }

    func beginChoosingExcerptListCover(_ session: ExcerptListEditorSession) {
        excerpt.beginChoosingExcerptListCover(session)
    }

    func saveExcerptListEditor(_ session: ExcerptListEditorSession) {
        excerpt.saveExcerptListEditor(session) {
            [weak self] pendingTransfer, listID, listName in
            self?.runExcerptListEditorPendingTransfer(
                pendingTransfer,
                toListID: listID,
                listName: listName
            )
        }
    }

    @discardableResult
    func deleteExcerptList(id: Int64) -> Bool {
        guard excerpt.database != nil else {
            return false
        }
        if workbenchLayout.selectedExcerptListID == id {
            // The page being looked at is gone: going back to the overview
            // is a step of its own, like any other page change.
            navigateWorkbench(to: .excerpt)
        }
        return excerpt.deleteExcerptList(id: id, settings: settings)
    }

    // MARK: - Table Rows, Projection & Refresh Forwarding

    func loadExcerptTableRowsIfNeeded() {
        excerpt.loadTableRowsIfNeeded(
            settings: settings,
            normalizeFacetFilter: search.normalizedFacetFilter,
            onProjectionApplied: { [weak self] in
                self?.refreshExcerptPlaybackPlaylistSource()
            }
        )
    }

    func reloadExcerptTableRows() {
        excerpt.reloadTableRows(
            settings: settings,
            normalizeFacetFilter: search.normalizedFacetFilter,
            onProjectionApplied: { [weak self] in
                self?.refreshExcerptPlaybackPlaylistSource()
            }
        )
    }

    func prepareExcerptForIndexedContentMutation(under folders: [URL]) {
        excerpt.prepareForIndexedContentMutation(under: folders)
    }

    func reloadExcerptAfterIndexedContentMutation() {
        excerpt.markReloadNeededAfterIndexedContentMutation()
    }

    func refreshExcerptOnReappearanceIfNeeded() {
        excerpt.refreshOnReappearanceIfNeeded(
            settings: settings,
            normalizeFacetFilter: search.normalizedFacetFilter,
            onProjectionApplied: { [weak self] in
                self?.refreshExcerptPlaybackPlaylistSource()
            },
            onRefreshRecentWatching: { [weak self] in
                self?.refreshRecentWatching()
            }
        )
    }

    func refreshExcerptForLibraryWatchStateChange() {
        excerpt.refreshForLibraryWatchStateChange(
            settings: settings,
            normalizeFacetFilter: search.normalizedFacetFilter,
            onProjectionApplied: { [weak self] in
                self?.refreshExcerptPlaybackPlaylistSource()
            }
        )
    }

    func applyRenameToExcerpt(_ steps: [LibraryRenameStep]) {
        excerpt.applyCompletedRename(
            steps,
            normalizeFacetFilter: search.normalizedFacetFilter
        )
    }

    func updateExcerptFacetFilter(_ filter: CueFacetFilter) {
        excerpt.updateFacetFilter(
            filter,
            settings: settings,
            normalizeFacetFilter: search.normalizedFacetFilter,
            onProjectionApplied: { [weak self] in
                self?.refreshExcerptPlaybackPlaylistSource()
            },
            onRefreshRecentWatching: { [weak self] in
                self?.refreshRecentWatching()
            }
        )
    }

    func updateExcerptSortOrder(_ sortOrder: ExcerptSortOrder) {
        excerpt.updateSortOrder(
            sortOrder,
            settings: settings,
            normalizeFacetFilter: search.normalizedFacetFilter,
            onProjectionApplied: { [weak self] in
                self?.refreshExcerptPlaybackPlaylistSource()
            },
            onRefreshRecentWatching: { [weak self] in
                self?.refreshRecentWatching()
            }
        )
    }

    func updateExcerptSearchQuery(_ searchText: String) {
        excerpt.updateSearchQuery(
            searchText,
            settings: settings,
            normalizeFacetFilter: search.normalizedFacetFilter,
            onProjectionApplied: { [weak self] in
                self?.refreshExcerptPlaybackPlaylistSource()
            },
            onRefreshRecentWatching: { [weak self] in
                self?.refreshRecentWatching()
            }
        )
    }

    /// The Excerpt table's rows for a search text and a selection, with the
    /// counts by the usual rule. The table installs them; the Filter dialog
    /// reads them for a selection it has not handed to the table yet.
    func residentExcerptTableProjection(
        searchText: String,
        facetFilter: CueFacetFilter,
        sortOrder: ExcerptSortOrder? = nil
    ) -> (relations: [ExcerptRelation], distribution: CueFacetDistribution) {
        excerpt.residentExcerptTableProjection(
            searchText: searchText,
            facetFilter: facetFilter,
            sortOrder: sortOrder,
            normalizeFacetFilter: search.normalizedFacetFilter
        )
    }

    // MARK: - Excerpt CRUD Forwarding

    private func runExcerptListEditorPendingTransfer(
        _ transfer: ExcerptListEditorPendingTransfer,
        toListID destinationListID: Int64,
        listName: String
    ) {
        switch (transfer.action, transfer.target) {
        case (.saveToExcerpt, .cue(let cueID)):
            saveExcerpt(
                cueID: cueID,
                toListID: destinationListID,
                listName: listName,
                report: transfer.report
            )
        case (.moveToList, .excerpt(let item)):
            _ = moveExcerpt(
                item,
                toListID: destinationListID,
                listName: listName
            )
        case (.duplicateToList, .excerpt(let item)):
            _ = duplicateExcerpt(
                item,
                toListID: destinationListID,
                listName: listName
            )
        default:
            break
        }
    }

    private func reportExcerptSave(
        _ request: ToastRequest,
        _ report: ExcerptSaveReport
    ) {
        switch report {
        case .toast:
            toast.show(request)
        case .playbackFeedback:
            playback.playbackViewModel?.showExcerptSaveFeedback(
                message: request.message,
                icon: request.icon,
                iconWeight: request.iconWeight,
                durationMilliseconds: UInt64(request.duration * 1_000)
            )
        }
    }

    /// `listName` is the name the destination menu displayed. Every outcome
    /// names the list, and a list that is gone by the time the save runs can
    /// only be named by what the menu showed.
    @discardableResult
    func saveExcerpt(
        cueID: Int64,
        toListID destinationListID: Int64,
        listName: String,
        report: ExcerptSaveReport
    ) -> Bool {
        excerpt.saveExcerpt(
            cueID: cueID,
            toListID: destinationListID,
            listName: listName,
            isCueInLibrary: { [weak self] id in
                self?.isCueInLibrary(id) == true
            },
            onCueNotInLibrary: { [weak self] in
                guard let self else { return }
                switch report {
                case .toast:
                    self.toast.show(TableToastRequest.cueNotInLibrary)
                case .playbackFeedback:
                    self.playback.playbackViewModel?.showNotInLibraryFeedback()
                }
            },
            onReportToast: { [weak self] request in
                self?.reportExcerptSave(request, report)
            }
        )
    }

    @discardableResult
    func moveExcerpt(
        _ item: Excerpt,
        toListID destinationListID: Int64,
        listName: String
    ) -> Bool {
        excerpt.moveExcerpt(
            item,
            toListID: destinationListID,
            listName: listName,
            isExcerptInLibrary: { [weak self] id in
                self?.excerptIDsInLibrary(among: [id]).contains(id) == true
            },
            onToast: { [weak self] request in
                self?.toast.show(request)
            },
            onItemRemovedFromCurrentList: { [weak self] removed in
                self?.handleExcerptRemovedFromCurrentList(removed)
            },
            onReloadTableRows: { [weak self] in
                self?.reloadExcerptTableRows()
            }
        )
    }

    @discardableResult
    func duplicateExcerpt(
        _ item: Excerpt,
        toListID destinationListID: Int64,
        listName: String
    ) -> Bool {
        excerpt.duplicateExcerpt(
            item,
            toListID: destinationListID,
            listName: listName,
            isExcerptInLibrary: { [weak self] id in
                self?.excerptIDsInLibrary(among: [id]).contains(id) == true
            },
            onToast: { [weak self] request in
                self?.toast.show(request)
            }
        )
    }

    @discardableResult
    func removeExcerpt(_ item: Excerpt, reloadPresentation: Bool = true) -> Bool {
        excerpt.removeExcerpt(
            item,
            reloadPresentation: reloadPresentation,
            onFeedback: { [weak self] state in
                self?.playback.playbackViewModel?.showExcerptFeedback(state)
            },
            onItemRemovedFromCurrentList: { [weak self] removed in
                self?.handleExcerptRemovedFromCurrentList(removed)
            },
            onReloadTableRows: { [weak self] in
                self?.reloadExcerptTableRows()
            }
        )
    }

    private func handleExcerptRemovedFromCurrentList(_ item: Excerpt) {
        excerpt.removeExcerptFromCurrentProjection(id: item.id)
        excerpt.removeExcerptFromPlaybackNavigationScope(item.id)
        if excerpt.selectedExcerpt?.id == item.id {
            excerpt.selectedExcerpt = nil
            excerptPlaybackNavigationSnapshot = nil
            clearPlaybackChromeSnapshot()
        } else if let selectedExcerpt = excerpt.selectedExcerpt {
            _ = refreshExcerptPlaybackNavigationSnapshot(for: selectedExcerpt)
            refreshPlaybackChromeSnapshot(
                displayTitle: playback.chromeSnapshot.displayTitle
            )
        }
    }

    // MARK: - Playback & Navigation Orchestration

    func openExcerpt(
        _ excerpt: Excerpt,
        navigationScopeIDs: [Int64]? = nil,
        playlistScope: PlaybackPlaylistExcerptScope? = nil,
        playlistSelectedOrdinal: Int? = nil,
        displayTitle: String? = nil,
        allowsUnavailableTarget: Bool = false
    ) {
        guard excerpt.isValid || allowsUnavailableTarget else {
            return
        }
        ensurePlayerInitialized()
        let itemInLibrary = excerpt.isValid
            && excerptIDsInLibrary(among: [excerpt.id]).contains(excerpt.id)
        currentPlaybackItemLeftLibrary = !itemInLibrary
        self.excerpt.selectedExcerpt = excerpt
        search.selectResult(nil)
        library.selectedLibraryVideo = nil

        clearCueAutoStopPlayback()
        invalidatePlaybackSubtitleFocusForSourceReplacement()
        playback.playbackStatus = .opening
        UIInvalidationProbe.mark(
            "ACTION UI.Excerpt.opened",
            details: "time=\(String(format: "%.2f", Double(excerpt.startMilliseconds) / 1000.0))"
        )
        preparePlaybackKeyboardFocus()

        let validScopeIDs: [Int64]?
        let resolvedPlaylistScope: PlaybackPlaylistExcerptScope?
        if let navigationScopeIDs {
            let validSet = excerptIDsInLibrary(among: navigationScopeIDs)
            let filtered = navigationScopeIDs.filter { validSet.contains($0) }
            validScopeIDs = filtered
            if filtered.count < navigationScopeIDs.count {
                resolvedPlaylistScope = .explicitIDs(filtered)
            } else {
                resolvedPlaylistScope = playlistScope
            }
        } else {
            validScopeIDs = nil
            resolvedPlaylistScope = playlistScope
        }

        let keepsExistingPlaylistSnapshot = resolvedPlaylistScope.map { scope in
            playback.playlistSource?.origin == .excerpt(scope: scope)
                && excerptPlaybackNavigationScopeIDs != nil
        } ?? false
        if !keepsExistingPlaylistSnapshot {
            excerptPlaybackNavigationScopeIDs = validScopeIDs
        }
        installExcerptPlaybackPlaylistSource(scope: resolvedPlaylistScope)
        let resolvedPlaylistOrdinal: Int?
        if itemInLibrary {
            resolvedPlaylistOrdinal = refreshExcerptPlaybackNavigationSnapshot(
                for: excerpt,
                preferredOrdinal: playlistSelectedOrdinal
            )
            if let resolvedPlaylistOrdinal {
                _ = playback.setPlaylistPosition(
                    itemIdentity: .excerpt(excerpt.id),
                    ordinal: resolvedPlaylistOrdinal
                )
            } else {
                playback.clearPlaylistPosition()
            }
        } else {
            excerptPlaybackNavigationSnapshot = (
                currentID: excerpt.id,
                previousID: nil,
                nextID: nil
            )
            playback.clearPlaylistPosition()
            resolvedPlaylistOrdinal = nil
        }
        saveCurrentLibraryPlaybackHistory()
        stopLibraryPlaybackHistoryTracking()
        activePlaybackSource = .excerpt
        refreshPlaybackChromeSnapshot(
            displayTitle: playbackDisplayTitle(
                for: excerpt,
                providedDisplayTitle: displayTitle
            )
        )
        playback.isPlaybackSurfaceExpanded = true
        if !itemInLibrary {
            cancelPendingPlaybackOpenTask()
            playback.clearPlaylistPosition()
            playback.playbackStatus = .loadFailed
            try? player?.stop()
            playback.playbackViewModel?.resetPresentationForStoppedPlayback()
            showPlaybackItemNotInLibrary()
            if (playback.playlistSource?.boundary.totalCount ?? 0) == 0 {
                playback.playbackViewModel?.showNoAvailableNavigationFeedback(
                    direction: nil,
                    text: L("playback.hud.no_available_results")
                )
            }
        } else {
            playback.clearError(on: .notInLibrary)
            preparePlaybackTransition(
                forVideoPath: excerpt.videoPath,
                startMilliseconds: excerpt.startMilliseconds,
                subtitleCues: [],
                resetsLoadingTimer: true
            )
            schedulePlaybackOpen(
                videoPath: excerpt.videoPath,
                subtitlePath: excerpt.subtitlePath
            ) { [weak self] in
                _ = self?.play(excerpt)
            }
        }
    }

    @discardableResult
    func play(_ excerpt: Excerpt) -> Bool {
        ensurePlayerInitialized()
        let targetDecodeMode = prepareDecodeModeForPlayback(videoPath: excerpt.videoPath)
        let codec = libraryDatabase?.videoCodec(forVideoPath: excerpt.videoPath) ?? "unknown"
        NSLog("[Playback] AppCoordinator.play(excerpt): videoPath=%@, codec=%@, startMs=%ld, settingMode=%@, targetMode=%@",
              excerpt.videoPath,
              codec,
              excerpt.startMilliseconds,
              settings.playbackDecodeMode.rawValue,
              targetDecodeMode.rawValue)
        beginCueAutoStopPlayback()
        saveCurrentLibraryPlaybackHistory()
        stopLibraryPlaybackHistoryTracking()
        activePlaybackSource = .excerpt
        playbackSubtitle = nil
        playback.playbackStatus = .opening
        playback.clearError(on: .video)
        playback.clearError(on: .notInLibrary)
        preparePlaybackTransition(
            forVideoPath: excerpt.videoPath,
            startMilliseconds: excerpt.startMilliseconds,
            subtitleCues: [],
            resetsLoadingTimer: false
        )

        do {
            let autoStopBoundary = configureCueAutoStopBoundary(
                startMilliseconds: excerpt.startMilliseconds,
                endMilliseconds: excerpt.endMilliseconds
            )
            let request = try PlaybackRequest(
                videoURL: URL.fromMediaPath(excerpt.videoPath),
                startMilliseconds: excerpt.startMilliseconds,
                autoStopAtMilliseconds: autoStopBoundary?.endMilliseconds,
                subtitleSource: loadablePlaybackSubtitleSource(playbackSubtitleSource(for: excerpt)),
                audioTrackIndex: defaultAudioTrackIndex(forVideoPath: excerpt.videoPath)
            )

            guard let player else {
                throw PlaybackError.playbackPlayerUnavailable
            }

            let generation: UInt
            if canSeekInOpenVideo(for: request) {
                if let autoStopBoundary {
                    generation = try player.seek(
                        to: autoStopBoundary,
                        subtitleSource: request.subtitleSource
                    )
                } else {
                    generation = try player.seek(
                        toMilliseconds: excerpt.startMilliseconds,
                        subtitleSource: request.subtitleSource
                    )
                }
            } else {
                generation = try player.open(request)
            }

            playback.playbackViewModel?.bindPendingPresentation(to: generation)
            recordRecentExcerptPlayback(for: excerpt)
            return true
        } catch {
            handlePlaybackOpenFailure(
                error,
                videoPath: excerpt.videoPath,
                cueStartMilliseconds: excerpt.startMilliseconds
            )
            return false
        }
    }

    func recordRecentExcerptPlayback(for item: Excerpt) {
        excerpt.recordRecentExcerptPlayback(for: item)
    }

    var canOpenPreviousExcerpt: Bool {
        guard activePlaybackSource == .excerpt,
              let selectedExcerpt = excerpt.selectedExcerpt,
              excerptPlaybackNavigationSnapshot?.currentID == selectedExcerpt.id
        else {
            return false
        }
        return excerptPlaybackNavigationSnapshot?.previousID != nil
    }

    var canOpenNextExcerpt: Bool {
        guard activePlaybackSource == .excerpt,
              let selectedExcerpt = excerpt.selectedExcerpt,
              excerptPlaybackNavigationSnapshot?.currentID == selectedExcerpt.id
        else {
            return false
        }
        return excerptPlaybackNavigationSnapshot?.nextID != nil
    }

    func openPreviousExcerpt() {
        guard !currentPlaybackItemLeftLibrary else {
            openFirstAvailablePlaybackItem(direction: .previous)
            return
        }
        let target = excerptPlaybackNavigationTarget(direction: .previous)
        let hasResult = target != nil
        playback.playbackViewModel?.showExcerptNavigationFeedback(direction: .previous, hasResult: hasResult)
        if let target {
            let targetOrdinal = excerpt.selectedExcerpt.flatMap {
                currentExcerptPlaylistAdjacentOrdinal(
                    for: $0,
                    direction: .previous
                )
            }
            openExcerpt(
                target,
                navigationScopeIDs: excerptPlaybackNavigationScopeIDs,
                playlistScope: activeExcerptPlaybackPlaylistScope,
                playlistSelectedOrdinal: targetOrdinal
            )
        }
    }

    func openNextExcerpt() {
        guard !currentPlaybackItemLeftLibrary else {
            openFirstAvailablePlaybackItem(direction: .next)
            return
        }
        let target = excerptPlaybackNavigationTarget(direction: .next)
        let hasResult = target != nil
        playback.playbackViewModel?.showExcerptNavigationFeedback(direction: .next, hasResult: hasResult)
        if let target {
            let targetOrdinal = excerpt.selectedExcerpt.flatMap {
                currentExcerptPlaylistAdjacentOrdinal(
                    for: $0,
                    direction: .next
                )
            }
            openExcerpt(
                target,
                navigationScopeIDs: excerptPlaybackNavigationScopeIDs,
                playlistScope: activeExcerptPlaybackPlaylistScope,
                playlistSelectedOrdinal: targetOrdinal
            )
        }
    }

    private var activeExcerptPlaybackPlaylistScope: PlaybackPlaylistExcerptScope? {
        guard let source = playback.playlistSource,
              case .excerpt(let scope) = source.origin
        else {
            return nil
        }
        return scope
    }

    private func excerptPlaybackNavigationTarget(direction: ExcerptNavigationDirection) -> Excerpt? {
        guard activePlaybackSource == .excerpt,
              let selectedExcerpt = excerpt.selectedExcerpt,
              let snapshot = excerptPlaybackNavigationSnapshot,
              snapshot.currentID == selectedExcerpt.id
        else {
            return nil
        }

        let targetID: Int64?
        switch direction {
        case .previous:
            targetID = snapshot.previousID
        case .next:
            targetID = snapshot.nextID
        }
        return targetID.flatMap(excerpt(withID:))
    }

    func refreshExcerptPlaybackNavigationSnapshot(
        for selectedExcerpt: Excerpt,
        preferredOrdinal: Int? = nil
    ) -> Int? {
        excerpt.refreshPlaybackNavigationSnapshot(
            for: selectedExcerpt,
            preferredOrdinal: preferredOrdinal,
            playlistSource: playback.playlistSource
        )
    }

    func excerpt(withID id: Int64) -> Excerpt? {
        excerpt.excerpt(withID: id)
    }
}
