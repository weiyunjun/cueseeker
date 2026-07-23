import AppKit
import Foundation
import CueSeekerCore
import CueSeekerPlayback

struct ShioriTagPopoverState: Equatable {
    let allTags: [ShioriTag]
    let currentTags: [ShioriTag]
}

struct ShioriTagDeletionOutcome: Equatable {
    let popoverState: ShioriTagPopoverState
    let deletionResult: ShioriTagDeletionResult
}

@MainActor
extension AppCoordinator {
    func loadShioriListOverviewIfNeeded() {
        guard !shiori.hasLoadedListOverview, shioriListOverviewTask == nil else {
            return
        }
        reloadShioriListOverview()
    }

    func reloadShioriListOverview() {
        shioriListOverviewTask?.cancel()
        shiori.clearListOverviewForReload()
        let databaseURL = databaseURL
        shioriListOverviewTask = Task { @MainActor [weak self] in
            guard let self else {
                return
            }
            defer {
                self.shioriListOverviewTask = nil
            }
            do {
                let overview = try await Self.runCancellableDetached(
                    priority: .userInitiated
                ) {
                    try ShioriDatabase(
                        path: databaseURL,
                        access: .readOnly
                    ).shioriListOverview()
                }
                try Task.checkCancellation()
                self.shiori.installListOverview(overview)
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled else {
                    return
                }
                print("Failed to load Shiori list overview: \(error)")
                self.shiori.installListOverview(
                    ShioriListOverview(lists: [], uniqueCueCount: 0)
                )
            }
        }
    }

    func openShioriList(id: Int64) {
        workbenchLayout.selectShioriList(id: id)
        shiori.setActiveListID(id)
        reloadShioriTableRows()
    }

    func showShioriListOverview() {
        workbenchLayout.clearShioriList()
        shiori.setActiveListID(try? shioriDatabase?.firstShioriListID())
        reloadShioriListOverview()
    }

    func beginCreatingShioriList() {
        guard shiori.listEditorSession == nil else {
            return
        }
        shiori.listEditorSession = ShioriListEditorSession(mode: .newList)
    }

    func beginEditingShioriList(_ list: ShioriList) {
        guard shiori.listEditorSession == nil else {
            return
        }
        shiori.listEditorSession = ShioriListEditorSession(mode: .edit(list))
    }

    func closeShioriListEditor() {
        guard shiori.listEditorSession?.isSaving != true else {
            return
        }
        shioriListCoverImportTask?.cancel()
        shioriListCoverImportTask = nil
        shiori.listEditorSession = nil
    }

    func validateShioriListEditor(_ session: ShioriListEditorSession) {
        guard shiori.listEditorSession?.id == session.id,
              let database = shioriDatabase
        else {
            return
        }
        do {
            session.apply(validation: try database.validateShioriList(
                name: session.name,
                description: session.listDescription,
                excludingListID: session.mode.editedList?.id
            ))
        } catch {
            print("Failed to validate Shiori list: \(error)")
        }
    }

    func beginChoosingShioriListCover(_ session: ShioriListEditorSession) {
        guard shiori.listEditorSession?.id == session.id,
              !session.isSaving
        else {
            return
        }

        let panel = NSOpenPanel()
        let delegate = LibraryCoverOpenPanelDelegate()
        panel.delegate = delegate
        panel.title = "Choose Cover Image"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        panel.resolvesAliases = true
        panel.allowedContentTypes = LibraryCoverOpenPanelPolicy.allowedContentTypes
        panel.allowsOtherFileTypes = false

        let completion: (NSApplication.ModalResponse) -> Void = {
            [weak self, weak session, delegate] response in
            _ = delegate
            guard let self,
                  let session,
                  response == .OK,
                  let sourceURL = panel.url,
                  self.shiori.listEditorSession?.id == session.id
            else {
                return
            }

            self.shioriListCoverImportTask?.cancel()
            self.shioriListCoverImportTask = Task { @MainActor [weak self, weak session] in
                guard let self, let session else {
                    return
                }
                do {
                    let source = try await Task.detached(priority: .userInitiated) {
                        try LibraryUserCoverProcessor.loadSource(at: sourceURL)
                    }.value
                    try Task.checkCancellation()
                    guard self.shiori.listEditorSession?.id == session.id else {
                        return
                    }
                    session.selectCoverSource(source)
                } catch is CancellationError {
                    return
                } catch {
                    print("Failed to load Shiori list cover: \(error)")
                }
            }
        }

        if let window = NSApplication.shared.keyWindow ?? NSApplication.shared.mainWindow {
            panel.beginSheetModal(for: window, completionHandler: completion)
        } else {
            completion(panel.runModal())
        }
    }

    func saveShioriListEditor(_ session: ShioriListEditorSession) {
        guard shiori.listEditorSession?.id == session.id,
              !session.isSaving,
              let database = shioriDatabase
        else {
            return
        }
        validateShioriListEditor(session)
        guard session.nameValidationMessage == nil,
              session.descriptionValidationMessage == nil
        else {
            return
        }

        session.isSaving = true
        let source = session.selectedCoverSource
        let cropRect = session.cropRect
        let oldCoverPath = session.originalCoverPath
        let mode = session.mode
        let name = session.name
        let description = session.listDescription
        shioriListSaveTask?.cancel()
        shioriListSaveTask = Task { @MainActor [weak self, weak session] in
            guard let self, let session else {
                return
            }
            var publishedCoverPath: String?
            do {
                if let source {
                    publishedCoverPath = try await self.shioriListCoverStorage.publish(
                        source: source,
                        cropRect: cropRect
                    )
                }
                let coverPath = publishedCoverPath ?? oldCoverPath
                switch mode {
                case .newList:
                    _ = try database.createShioriList(
                        name: name,
                        description: description,
                        coverPath: coverPath
                    )
                case .edit(let list):
                    _ = try database.updateShioriList(
                        id: list.id,
                        name: name,
                        description: description,
                        coverPath: coverPath
                    )
                }

                if publishedCoverPath != nil, oldCoverPath != nil {
                    do {
                        try await self.shioriListCoverStorage.remove(path: oldCoverPath)
                    } catch {
                        print("Failed to remove replaced Shiori list cover: \(error)")
                    }
                }
                guard self.shiori.listEditorSession?.id == session.id else {
                    return
                }
                session.isSaving = false
                self.shiori.listEditorSession = nil
                self.reloadShioriListOverview()
            } catch is CancellationError {
                if let publishedCoverPath {
                    try? await self.shioriListCoverStorage.remove(path: publishedCoverPath)
                }
                if self.shiori.listEditorSession?.id == session.id {
                    session.isSaving = false
                }
            } catch {
                if let publishedCoverPath {
                    try? await self.shioriListCoverStorage.remove(path: publishedCoverPath)
                }
                guard self.shiori.listEditorSession?.id == session.id else {
                    return
                }
                session.isSaving = false
                if let validationError = error as? ShioriListValidationError {
                    let validation = try? database.validateShioriList(
                        name: session.name,
                        description: session.listDescription,
                        excludingListID: session.mode.editedList?.id
                    )
                    if let validation {
                        session.apply(validation: validation)
                    } else {
                        print("Failed to revalidate Shiori list after \(validationError)")
                    }
                } else {
                    print("Failed to save Shiori list: \(error)")
                }
            }
            self.shioriListSaveTask = nil
        }
    }

    @discardableResult
    func deleteShioriList(id: Int64) -> Bool {
        guard let database = shioriDatabase else {
            return false
        }
        do {
            let deleted = try database.deleteShioriList(id: id)
            if workbenchLayout.selectedShioriListID == id {
                workbenchLayout.clearShioriList()
            }
            if shiori.activeListID == id {
                shiori.setActiveListID(try database.firstShioriListID())
            }
            reloadShioriListOverview()
            if let coverPath = deleted.coverPath {
                Task {
                    do {
                        try await shioriListCoverStorage.remove(path: coverPath)
                    } catch {
                        print("Failed to remove deleted Shiori list cover: \(error)")
                    }
                }
            }
            return true
        } catch {
            print("Failed to delete Shiori list: \(error)")
            return false
        }
    }

    func loadShioriTableRowsIfNeeded() {
        guard !indexing.indexingStatus.isIndexing,
              !indexing.folderRemovalStatus.isRemoving
        else {
            return
        }
        guard shioriTableRowsTask == nil else {
            return
        }
        let snapshot = shiori.tableRowStore.snapshot
        guard !shiori.tableHasLoadedInitialPage
                || snapshot.totalRowCount != shiori.tableResultRowCount
        else {
            return
        }
        reloadShioriTableRows()
    }

    func reloadShioriTableRows() {
        guard !indexing.indexingStatus.isIndexing,
              !indexing.folderRemovalStatus.isRemoving
        else {
            return
        }
        guard let listID = shiori.activeListID
                ?? (try? shioriDatabase?.firstShioriListID())
        else {
            shiori.clearTableRowsForReload()
            shiori.markTableRowsLoaded(totalSavedRowCount: 0)
            return
        }

        shioriTableRowsTask?.cancel()
        shiori.setActiveListID(listID)
        shiori.clearTableRowsForReload()

        let resultSnapshotID = shiori.tableResultSnapshotID
        let searchText = shiori.tableSubmittedSearchText
        let filterSet = shiori.tableFilterRules.subtitleSearchFilterSet
        let dataRevision = shiori.tableDataRevision
        if shiori.residentDataRevision == dataRevision,
           shiori.residentListID == listID {
            applyResidentShioriTableProjection(
                resultSnapshotID: resultSnapshotID,
                searchText: searchText,
                filterSet: filterSet,
                listID: listID,
                dataRevision: dataRevision
            )
            return
        }

        shioriTableRowsTask = Task { @MainActor [weak self] in
            guard let self else {
                return
            }
            defer {
                if self.shiori.tableResultSnapshotID == resultSnapshotID {
                    self.shioriTableRowsTask = nil
                }
            }

            do {
                let databaseURL = self.databaseURL
                let residentSnapshot = try await Self.runCancellableDetached(
                    priority: .userInitiated
                ) {
                    try ShioriDatabase(
                        path: databaseURL,
                        access: .readOnly
                    ).shioriResidentSnapshot(listID: listID)
                }
                guard self.shioriTableRequestMatches(
                    resultSnapshotID: resultSnapshotID,
                    searchText: searchText,
                    filterSignature: filterSet.cacheSignature,
                    listID: listID,
                    dataRevision: dataRevision
                ) else {
                    return
                }
                self.cueContent.install(residentSnapshot.cueContents)
                self.shiori.installResidentSnapshot(
                    residentSnapshot,
                    listID: listID,
                    dataRevision: dataRevision
                )
                self.applyResidentShioriTableProjection(
                    resultSnapshotID: resultSnapshotID,
                    searchText: searchText,
                    filterSet: filterSet,
                    listID: listID,
                    dataRevision: dataRevision
                )
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled else { return }
                print("Failed to load resident Shiori data: \(error)")
                if self.shioriTableRequestMatches(
                    resultSnapshotID: resultSnapshotID,
                    searchText: searchText,
                    filterSignature: filterSet.cacheSignature,
                    listID: listID,
                    dataRevision: dataRevision
                ) {
                    self.shiori.markTableRowsLoaded(totalSavedRowCount: 0)
                }
            }
        }
    }

    func prepareShioriForIndexedContentMutation(under folders: [URL]) {
        shioriNeedsReloadAfterIndexedContentMutation =
            shioriNeedsReloadAfterIndexedContentMutation
            || shiori.residentDataRevision != nil
            || shiori.tableHasLoadedInitialPage
            || shioriTableRowsTask != nil
        shioriTableRowsTask?.cancel()
        shioriTableRowsTask = nil
        cueContent.remove { content in
            folders.contains { folder in
                Self.path(content.subtitlePath, isUnder: folder)
            }
        }
        shiori.invalidateTableRows()
        shiori.clearListOverviewForReload()
        shioriPlaybackNavigationScopeIDs = nil
        shioriPlaybackNavigationSnapshot = nil
    }

    func reloadShioriAfterIndexedContentMutation() {
        shioriTableRowsTask?.cancel()
        shioriTableRowsTask = nil
        guard shioriNeedsReloadAfterIndexedContentMutation else {
            return
        }
        shioriNeedsReloadAfterIndexedContentMutation = false
        reloadShioriListOverview()
        reloadShioriTableRows()
    }

    private func applyResidentShioriTableProjection(
        resultSnapshotID: UUID,
        searchText: String,
        filterSet: SubtitleSearchFilterSet,
        listID: Int64,
        dataRevision: Int
    ) {
        guard shioriTableRequestMatches(
            resultSnapshotID: resultSnapshotID,
            searchText: searchText,
            filterSignature: filterSet.cacheSignature,
            listID: listID,
            dataRevision: dataRevision
        ) else {
            return
        }

        let trimmedSearchText = searchText.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        let relations = shiori.residentRelations.filter { relation in
            guard let content = cueContent.content(for: relation.cueID) else {
                return false
            }
            let matchesSearch = trimmedSearchText.isEmpty
                || content.displayTitle.range(
                    of: trimmedSearchText,
                    options: [.caseInsensitive, .diacriticInsensitive]
                ) != nil
                || content.content.range(
                    of: trimmedSearchText,
                    options: [.caseInsensitive, .diacriticInsensitive]
                ) != nil
            return matchesSearch && filterSet.matches(
                display: content.displayTitle,
                cues: content.content,
                languages: content.languages.map(\.rawValue).sorted(),
                speakers: content.speakers.sorted()
            )
        }
        shiori.installTableResultShioriIDs(relations.map(\.id))
        shiori.markTableRowsLoaded(
            totalSavedRowCount: shiori.residentRelations.count
        )
        shiori.tableRowStore.updateResidentShioriRelations(
            relations,
            tagsByShioriID: shiori.residentTagsByShioriID,
            cueContentProvider: { [cueContent] cueID in
                cueContent.content(for: cueID)
            },
            cueContentRevision: cueContent.revision,
            tableName: "shiori",
            probeSurface: .shiori,
            probeScope: uiProbeScope
        )
        refreshShioriPlaybackPlaylistSource()
    }

    private func shioriTableRequestMatches(
        resultSnapshotID: UUID,
        searchText: String,
        filterSignature: String,
        listID: Int64,
        dataRevision: Int
    ) -> Bool {
        !Task.isCancelled
            && shiori.tableResultSnapshotID == resultSnapshotID
            && shiori.tableSubmittedSearchText == searchText
            && shiori.tableFilterRules.subtitleSearchFilterSet.cacheSignature
                == filterSignature
            && shiori.activeListID == listID
            && shiori.tableDataRevision == dataRevision
    }

    func shioriTagPopoverState(forShioriID shioriID: Int64) -> ShioriTagPopoverState? {
        guard let database = shioriDatabase else { return nil }
        do {
            return ShioriTagPopoverState(
                allTags: try database.shioriTags(),
                currentTags: try database.shioriTags(forShioriID: shioriID)
            )
        } catch {
            print("Failed to load Shiori tags: \(error)")
            return nil
        }
    }

    func assignShioriTag(tagID: Int64, toShioriID shioriID: Int64) -> [ShioriTag]? {
        guard let database = shioriDatabase else { return nil }
        do {
            _ = try database.assignShioriTag(tagID: tagID, toShioriID: shioriID)
            let tags = try database.shioriTags(forShioriID: shioriID)
            shiori.updateResidentTags(tags, forShioriID: shioriID)
            return tags
        } catch {
            print("Failed to assign Shiori tag: \(error)")
            return nil
        }
    }

    func createAndAssignShioriTag(named name: String, toShioriID shioriID: Int64) -> ShioriTagPopoverState? {
        guard let database = shioriDatabase else { return nil }
        do {
            _ = try database.assignShioriTag(named: name, toShioriID: shioriID)
            let state = ShioriTagPopoverState(
                allTags: try database.shioriTags(),
                currentTags: try database.shioriTags(forShioriID: shioriID)
            )
            shiori.updateResidentTags(state.currentTags, forShioriID: shioriID)
            return state
        } catch {
            print("Failed to create Shiori tag: \(error)")
            return nil
        }
    }

    func removeShioriTagAssignment(tagID: Int64, fromShioriID shioriID: Int64) -> [ShioriTag]? {
        guard let database = shioriDatabase else { return nil }
        do {
            _ = try database.removeShioriTagAssignment(tagID: tagID, fromShioriID: shioriID)
            let tags = try database.shioriTags(forShioriID: shioriID)
            shiori.updateResidentTags(tags, forShioriID: shioriID)
            return tags
        } catch {
            print("Failed to remove Shiori tag assignment: \(error)")
            return nil
        }
    }

    func deleteShioriTagGlobally(tagID: Int64, currentShioriID: Int64) -> ShioriTagDeletionOutcome? {
        guard let database = shioriDatabase else { return nil }
        do {
            let deletion = try database.deleteShioriTag(tagID: tagID)
            shiori.removeResidentTag(
                tagID: tagID,
                fromShioriIDs: deletion.affectedShioriIDs
            )
            let state = ShioriTagPopoverState(
                allTags: try database.shioriTags(),
                currentTags: try database.shioriTags(forShioriID: currentShioriID)
            )
            return ShioriTagDeletionOutcome(
                popoverState: state,
                deletionResult: deletion
            )
        } catch {
            print("Failed to delete Shiori tag: \(error)")
            return nil
        }
    }

    @discardableResult
    func moveShiori(_ item: Shiori, toListID destinationListID: Int64) -> Bool {
        guard let database = shioriDatabase else {
            toast.show(ShioriToastRequest.moveFailed)
            return false
        }
        let destination: ShioriList
        do {
            guard let availableDestination = try database.shioriList(
                id: destinationListID
            ) else {
                toast.show(ShioriToastRequest.destinationUnavailable)
                return false
            }
            destination = availableDestination
        } catch {
            print("Failed to resolve Shiori move destination: \(error)")
            toast.show(ShioriToastRequest.moveFailed)
            return false
        }

        do {
            _ = try database.moveShiori(
                id: item.id,
                toListID: destinationListID
            )
            handleShioriRemovedFromCurrentList(item)
            toast.show(
                ShioriToastRequest.moveSucceeded(listName: destination.name)
            )
            return true
        } catch ShioriTransferError.destinationUnavailable {
            toast.show(ShioriToastRequest.destinationUnavailable)
        } catch ShioriTransferError.destinationAlreadyContainsCue {
            toast.show(
                ShioriToastRequest.destinationAlreadyContainsCue(
                    listName: destination.name
                )
            )
        } catch {
            print("Failed to move Shiori: \(error)")
            toast.show(ShioriToastRequest.moveFailed)
        }
        return false
    }

    @discardableResult
    func duplicateShiori(
        _ item: Shiori,
        toListID destinationListID: Int64
    ) -> Bool {
        guard let database = shioriDatabase else {
            toast.show(ShioriToastRequest.duplicateFailed)
            return false
        }
        let destination: ShioriList
        do {
            guard let availableDestination = try database.shioriList(
                id: destinationListID
            ) else {
                toast.show(ShioriToastRequest.destinationUnavailable)
                return false
            }
            destination = availableDestination
        } catch {
            print("Failed to resolve Shiori duplicate destination: \(error)")
            toast.show(ShioriToastRequest.duplicateFailed)
            return false
        }

        do {
            _ = try database.duplicateShiori(
                id: item.id,
                toListID: destinationListID
            )
            reloadShioriListOverview()
            toast.show(
                ShioriToastRequest.duplicateSucceeded(listName: destination.name)
            )
            return true
        } catch ShioriTransferError.destinationUnavailable {
            toast.show(ShioriToastRequest.destinationUnavailable)
        } catch ShioriTransferError.destinationAlreadyContainsCue {
            toast.show(
                ShioriToastRequest.destinationAlreadyContainsCue(
                    listName: destination.name
                )
            )
        } catch {
            print("Failed to duplicate Shiori: \(error)")
            toast.show(ShioriToastRequest.duplicateFailed)
        }
        return false
    }

    @discardableResult
    func removeShiori(_ item: Shiori, reloadPresentation: Bool = true) -> Bool {
        guard let database = shioriDatabase else {
            playback.playbackViewModel?.showShioriFeedback(.unavailable)
            return false
        }

        do {
            try database.removeShiori(id: item.id)
            _ = reloadPresentation
            handleShioriRemovedFromCurrentList(item)
            playback.playbackViewModel?.showShioriFeedback(.removed)
            return true
        } catch {
            print("Failed to remove Shiori: \(error)")
            playback.playbackViewModel?.showShioriFeedback(.unavailable)
            return false
        }
    }

    private func handleShioriRemovedFromCurrentList(_ item: Shiori) {
        shiori.invalidateTableRows()
        reloadShioriListOverview()
        removeShioriFromPlaybackNavigationScope(item.id)
        if shiori.selectedShiori?.id == item.id {
            shiori.selectedShiori = nil
            shioriPlaybackNavigationSnapshot = nil
            clearPlaybackChromeSnapshot()
        } else if let selectedShiori = shiori.selectedShiori {
            _ = refreshShioriPlaybackNavigationSnapshot(for: selectedShiori)
            refreshPlaybackChromeSnapshot(
                displayTitle: playback.chromeSnapshot.displayTitle
            )
        }
    }

    func openShiori(
        _ shiori: Shiori,
        navigationScopeIDs: [Int64]? = nil,
        playlistScope: PlaybackPlaylistShioriScope? = nil,
        playlistSelectedOrdinal: Int? = nil,
        displayTitle: String? = nil,
        playbackReturnContextOnSuccessfulPlay: PlaybackReturnContext? = nil
    ) {
        clearCueAutoStopPlayback()
        invalidatePlaybackSubtitleFocusForSourceReplacement()
        playback.playbackStatus = .opening
        UIInvalidationProbe.mark(
            "ACTION UI.Shiori.opened",
            details: "time=\(String(format: "%.2f", Double(shiori.startMilliseconds) / 1000.0))"
        )
        preparePlaybackKeyboardFocus()
        let keepsExistingPlaylistSnapshot = playlistScope.map { scope in
            playback.playlistSource?.origin == .shiori(scope: scope)
                && shioriPlaybackNavigationScopeIDs != nil
        } ?? false
        if !keepsExistingPlaylistSnapshot {
            if case .table(let context)? = playlistScope,
               let navigationScopeIDs,
               navigationScopeIDs.count == context.totalCount {
                // Core table snapshots are already ordered and unique by the
                // Shiori primary key. Keep their copy-on-write ID buffer.
                shioriPlaybackNavigationScopeIDs = navigationScopeIDs
            } else {
                shioriPlaybackNavigationScopeIDs = normalizedShioriPlaybackNavigationScopeIDs(
                    navigationScopeIDs
                )
            }
        }
        installShioriPlaybackPlaylistSource(scope: playlistScope)
        let resolvedPlaylistOrdinal = refreshShioriPlaybackNavigationSnapshot(
            for: shiori,
            preferredOrdinal: playlistSelectedOrdinal
        )
        if let resolvedPlaylistOrdinal {
            _ = playback.setPlaylistPosition(
                itemIdentity: .shiori(shiori.id),
                ordinal: resolvedPlaylistOrdinal
            )
        } else {
            playback.clearPlaylistPosition()
        }
        initializePlaybackReturnContextIfEntering()
        saveCurrentLibraryPlaybackHistory()
        stopLibraryPlaybackHistoryTracking()
        activePlaybackSource = .shiori
        self.shiori.selectedShiori = shiori
        search.selectedSearchResult = nil
        library.selectedLibraryVideo = nil
        refreshPlaybackChromeSnapshot(
            displayTitle: playbackDisplayTitle(
                for: shiori,
                providedDisplayTitle: displayTitle
            )
        )
        playback.isPlaybackSurfaceExpanded = true
        Task { @MainActor in
            await Task.yield()
            let didStartPlayback = play(shiori)
            if let playbackReturnContextOnSuccessfulPlay {
                commitPlaybackReturnContext(
                    playbackReturnContextOnSuccessfulPlay,
                    afterSuccessfulPlayback: didStartPlayback
                )
            }
        }
    }

    @discardableResult
    func play(_ shiori: Shiori) -> Bool {
        ensurePlayerInitialized()
        beginCueAutoStopPlayback()
        saveCurrentLibraryPlaybackHistory()
        stopLibraryPlaybackHistoryTracking()
        activePlaybackSource = .shiori
        playback.playbackStatus = .opening
        playbackSubtitleCuesTask?.cancel()
        let subtitleCues = initialPlaybackSubtitleCues(for: shiori)
        playback.playbackViewModel?.preparePresentationTransition(
            to: Double(shiori.startMilliseconds) / 1_000,
            subtitleCues: subtitleCues
        )

        do {
            let autoStopBoundary = configureCueAutoStopBoundary(
                startMilliseconds: shiori.startMilliseconds,
                endMilliseconds: shiori.endMilliseconds
            )
            let request = try PlaybackRequest(
                videoURL: URL(fileURLWithPath: shiori.videoPath),
                startMilliseconds: shiori.startMilliseconds,
                autoStopAtMilliseconds: autoStopBoundary?.endMilliseconds,
                subtitleSource: playbackSubtitleSource(for: shiori)
            )

            guard let player else {
                throw PlaybackError.playbackPlayerUnavailable
            }

            let generation: UInt
            if player.currentVideoURL?.standardizedFileURL.path == request.videoURL.standardizedFileURL.path {
                if let autoStopBoundary {
                    generation = try player.seek(
                        to: autoStopBoundary,
                        subtitleSource: request.subtitleSource
                    )
                } else {
                    generation = try player.seek(
                        toMilliseconds: shiori.startMilliseconds,
                        subtitleSource: request.subtitleSource
                    )
                }
            } else {
                generation = try player.open(request)
            }

            playback.playbackViewModel?.bindPendingPresentation(to: generation)
            startPlaybackSubtitleCuesLoad(
                forSubtitleFile: URL(fileURLWithPath: shiori.subtitlePath),
                format: shiori.subtitleFormat,
                videoPath: shiori.videoPath
            )
            return true
        } catch {
            playback.playbackViewModel?.cancelPendingPresentation()
            clearCueAutoStopPlayback()
            playbackSubtitleCuesTask?.cancel()
            playback.playbackViewModel?.clearSubtitleCues()
            playback.playbackStatus = .failed(Self.errorMessage(for: error))
            return false
        }
    }

    var canOpenPreviousShiori: Bool {
        guard activePlaybackSource == .shiori,
              let selectedShiori = shiori.selectedShiori,
              shioriPlaybackNavigationSnapshot?.currentID == selectedShiori.id
        else {
            return false
        }
        return shioriPlaybackNavigationSnapshot?.previousID != nil
    }

    var canOpenNextShiori: Bool {
        guard activePlaybackSource == .shiori,
              let selectedShiori = shiori.selectedShiori,
              shioriPlaybackNavigationSnapshot?.currentID == selectedShiori.id
        else {
            return false
        }
        return shioriPlaybackNavigationSnapshot?.nextID != nil
    }

    func openPreviousShiori() {
        let target = shioriPlaybackNavigationTarget(direction: .previous)
        let hasResult = target != nil
        playback.playbackViewModel?.showShioriNavigationFeedback(direction: .previous, hasResult: hasResult)
        if let target {
            let targetOrdinal = shiori.selectedShiori.flatMap {
                currentShioriPlaylistAdjacentOrdinal(
                    for: $0,
                    direction: .previous
                )
            }
            openShiori(
                target,
                navigationScopeIDs: shioriPlaybackNavigationScopeIDs,
                playlistScope: activeShioriPlaybackPlaylistScope,
                playlistSelectedOrdinal: targetOrdinal
            )
        }
    }

    func openNextShiori() {
        let target = shioriPlaybackNavigationTarget(direction: .next)
        let hasResult = target != nil
        playback.playbackViewModel?.showShioriNavigationFeedback(direction: .next, hasResult: hasResult)
        if let target {
            let targetOrdinal = shiori.selectedShiori.flatMap {
                currentShioriPlaylistAdjacentOrdinal(
                    for: $0,
                    direction: .next
                )
            }
            openShiori(
                target,
                navigationScopeIDs: shioriPlaybackNavigationScopeIDs,
                playlistScope: activeShioriPlaybackPlaylistScope,
                playlistSelectedOrdinal: targetOrdinal
            )
        }
    }

    private var activeShioriPlaybackPlaylistScope: PlaybackPlaylistShioriScope? {
        guard let source = playback.playlistSource,
              case .shiori(let scope) = source.origin
        else {
            return nil
        }
        return scope
    }

    private func shioriPlaybackNavigationTarget(direction: ShioriNavigationDirection) -> Shiori? {
        guard activePlaybackSource == .shiori,
              let selectedShiori = shiori.selectedShiori,
              let snapshot = shioriPlaybackNavigationSnapshot,
              snapshot.currentID == selectedShiori.id
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
        return targetID.flatMap(shiori(withID:))
    }

    private func refreshShioriPlaybackNavigationSnapshot(
        for selectedShiori: Shiori,
        preferredOrdinal: Int? = nil
    ) -> Int? {
        let selectedID = selectedShiori.id
        let validatedPreferredOrdinal: Int?
        if let preferredOrdinal,
           playback.playlistSource?.itemIdentity(at: preferredOrdinal)
            == .shiori(selectedID) {
            validatedPreferredOrdinal = preferredOrdinal
        } else {
            validatedPreferredOrdinal = nil
        }

        if let source = playback.playlistSource,
           case .shiori(.table) = source.origin {
            let scopeIDs = shioriPlaybackNavigationScopeIDs
                ?? shiori.tableResultShioriIDs
            guard let scopeIDs,
                  let index = validatedPreferredOrdinal
                    ?? scopeIDs.firstIndex(of: selectedID)
            else {
                shioriPlaybackNavigationSnapshot = (
                    currentID: selectedID,
                    previousID: nil,
                    nextID: nil
                )
                return nil
            }
            shioriPlaybackNavigationSnapshot = (
                currentID: selectedID,
                previousID: index > 0 ? scopeIDs[index - 1] : nil,
                nextID: index + 1 < scopeIDs.count
                    ? scopeIDs[index + 1]
                    : nil
            )
            return index
        }

        if let scopeIDs = shioriPlaybackNavigationScopeIDs,
           let index = validatedPreferredOrdinal
                ?? scopeIDs.firstIndex(of: selectedID) {
            shioriPlaybackNavigationSnapshot = (
                currentID: selectedID,
                previousID: index > 0 ? scopeIDs[index - 1] : nil,
                nextID: index + 1 < scopeIDs.count ? scopeIDs[index + 1] : nil
            )
            return index
        }

        let residentOrdinal = validatedPreferredOrdinal
            ?? shiori.residentRelations.firstIndex(where: { $0.id == selectedID })

        if let index = residentOrdinal {
            let residentRelations = shiori.residentRelations
            shioriPlaybackNavigationSnapshot = (
                currentID: selectedID,
                previousID: index > 0 ? residentRelations[index - 1].id : nil,
                nextID: index + 1 < residentRelations.count
                    ? residentRelations[index + 1].id
                    : nil
            )
            return index
        }

        if let database = shioriDatabase {
            do {
                shioriPlaybackNavigationSnapshot = (
                    currentID: selectedID,
                    previousID: try database.adjacentShiori(to: selectedShiori, direction: .previous)?.id,
                    nextID: try database.adjacentShiori(to: selectedShiori, direction: .next)?.id
                )
                return nil
            } catch {
                print("Failed to load adjacent Shiori: \(error)")
            }
        }

        shioriPlaybackNavigationSnapshot = (
            currentID: selectedID,
            previousID: nil,
            nextID: nil
        )
        return nil
    }

    func shiori(withID id: Int64) -> Shiori? {
        if let entryID = Int(exactly: id),
           let tableItem = shiori.tableRowStore.snapshot.shiori(entryID: entryID) {
            return tableItem
        }
        if let relation = shiori.residentRelations.first(where: { $0.id == id }),
           let content = cueContent.content(for: relation.cueID) {
            return Shiori(relation: relation, cueContent: content)
        }
        guard let shioriDatabase else {
            return nil
        }

        do {
            guard let relation = try shioriDatabase.shioriRelation(id: id),
                  let content = try CueContentDatabase(path: databaseURL).cueContents(
                    forCueIDs: [relation.cueID]
                  ).first
            else {
                return nil
            }
            cueContent.install([content])
            return Shiori(relation: relation, cueContent: content)
        } catch {
            print("Failed to load scoped Shiori: \(error)")
            return nil
        }
    }

    private func normalizedShioriPlaybackNavigationScopeIDs(_ ids: [Int64]?) -> [Int64]? {
        guard let ids else {
            return nil
        }

        var seenIDs: Set<Int64> = []
        let normalizedIDs = ids.filter { seenIDs.insert($0).inserted }
        return normalizedIDs.isEmpty ? nil : normalizedIDs
    }

    private func removeShioriFromPlaybackNavigationScope(_ id: Int64) {
        guard var scopeIDs = shioriPlaybackNavigationScopeIDs else {
            return
        }

        scopeIDs.removeAll { $0 == id }
        shioriPlaybackNavigationScopeIDs = scopeIDs.isEmpty ? nil : scopeIDs
    }
}
