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
    func loadExcerptListOverviewIfNeeded() {
        guard !excerpt.hasLoadedListOverview, excerptListOverviewTask == nil else {
            return
        }
        reloadExcerptListOverview()
    }

    func reloadExcerptListOverview() {
        excerptListOverviewTask?.cancel()
        let databaseURL = databaseURL
        excerptListOverviewTask = Task { @MainActor [weak self] in
            guard let self else {
                return
            }
            defer {
                self.excerptListOverviewTask = nil
            }
            do {
                let snapshot = try await Self.runCancellableDetached(
                    priority: .userInitiated
                ) {
                    let database = try ExcerptDatabase(path: databaseURL)
                    return (
                        try database.excerptListOverview(),
                        try database.recentExcerptListSummaries()
                    )
                }
                try Task.checkCancellation()
                self.excerpt.installListOverview(snapshot.0)
                self.excerpt.installRecentListSummaries(snapshot.1)
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled else {
                    return
                }
                print("Failed to load Excerpt list overview: \(error)")
                if !self.excerpt.hasLoadedListOverview {
                    self.excerpt.installListOverview(
                        ExcerptListOverview(lists: [], uniqueCueCount: 0)
                    )
                    self.excerpt.installRecentListSummaries([])
                }
            }
        }
    }

    func openExcerptList(id: Int64) {
        navigateWorkbench(to: .excerptList(id: id))
    }

    func showExcerptListOverview() {
        navigateWorkbench(to: .excerpt)
    }

    func openRecentExcerpt(_ summary: ExcerptListSummary) {
        guard let item = summary.resumeExcerpt else { return }
        openExcerptListPlayback(summary, preferredExcerptID: item.id)
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
        guard let database = excerptDatabase else { return }
        do {
            let resolvedByID = Dictionary(
                uniqueKeysWithValues: try database.excerpts(
                    listID: summary.list.id
                ).map { ($0.id, $0) }
            )
            let navigationScopeIDs = try database.excerptRelations(
                listID: summary.list.id
            ).compactMap { relation -> Int64? in
                guard resolvedByID[relation.id]?.isValid == true else {
                    return nil
                }
                return relation.id
            }
            let preferredTargetID = preferredExcerptID.flatMap { candidate in
                navigationScopeIDs.contains(candidate) ? candidate : nil
            }
            guard let targetID = preferredTargetID ?? navigationScopeIDs.first,
                  let target = resolvedByID[targetID],
                  let ordinal = navigationScopeIDs.firstIndex(of: targetID)
            else {
                reloadExcerptListOverview()
                return
            }
            openExcerpt(
                target,
                navigationScopeIDs: navigationScopeIDs,
                playlistScope: .explicitIDs(navigationScopeIDs),
                playlistSelectedOrdinal: ordinal,
                displayTitle: target.displayTitle
            )
        } catch {
            print("Failed to open Excerpt list playback: \(error)")
        }
    }

    func beginCreatingExcerptList(
        pendingTransfer: ExcerptListEditorPendingTransfer? = nil
    ) {
        guard excerpt.listEditorSession == nil else {
            return
        }
        excerpt.listEditorSession = ExcerptListEditorSession(
            mode: .newList,
            pendingTransfer: pendingTransfer
        )
    }

    func beginEditingExcerptList(_ list: ExcerptList) {
        guard excerpt.listEditorSession == nil else {
            return
        }
        excerpt.listEditorSession = ExcerptListEditorSession(mode: .edit(list))
    }

    func closeExcerptListEditor() {
        guard excerpt.listEditorSession?.isSaving != true else {
            return
        }
        excerptListCoverImportTask?.cancel()
        excerptListCoverImportTask = nil
        excerpt.listEditorSession = nil
    }

    func validateExcerptListEditor(_ session: ExcerptListEditorSession) {
        guard excerpt.listEditorSession?.id == session.id,
              let database = excerptDatabase
        else {
            return
        }
        do {
            session.apply(validation: try database.validateExcerptList(
                name: session.name,
                description: session.listDescription,
                excludingListID: session.mode.editedList?.id
            ))
        } catch {
            print("Failed to validate Excerpt list: \(error)")
        }
    }

    func beginChoosingExcerptListCover(_ session: ExcerptListEditorSession) {
        guard excerpt.listEditorSession?.id == session.id,
              !session.isSaving
        else {
            return
        }

        let panel = NSOpenPanel()
        let delegate = LibraryCoverOpenPanelDelegate()
        panel.delegate = delegate
        panel.title = L("cover.choose_cover_image")
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
                  self.excerpt.listEditorSession?.id == session.id
            else {
                return
            }

            self.excerptListCoverImportTask?.cancel()
            self.excerptListCoverImportTask = Task { @MainActor [weak self, weak session] in
                guard let self, let session else {
                    return
                }
                do {
                    let source = try await Task.detached(priority: .userInitiated) {
                        try LibraryUserCoverProcessor.loadSource(at: sourceURL)
                    }.value
                    try Task.checkCancellation()
                    guard self.excerpt.listEditorSession?.id == session.id else {
                        return
                    }
                    session.selectCoverSource(source)
                } catch is CancellationError {
                    return
                } catch {
                    print("Failed to load Excerpt list cover: \(error)")
                }
            }
        }

        if let window = NSApplication.shared.keyWindow ?? NSApplication.shared.mainWindow {
            panel.beginSheetModal(for: window, completionHandler: completion)
        } else {
            completion(panel.runModal())
        }
    }

    func saveExcerptListEditor(_ session: ExcerptListEditorSession) {
        guard excerpt.listEditorSession?.id == session.id,
              !session.isSaving,
              let database = excerptDatabase
        else {
            return
        }
        validateExcerptListEditor(session)
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
        excerptListSaveTask?.cancel()
        excerptListSaveTask = Task { @MainActor [weak self, weak session] in
            guard let self, let session else {
                return
            }
            var publishedCoverPath: String?
            do {
                if let source {
                    publishedCoverPath = try await self.excerptListCoverStorage.publish(
                        source: source,
                        cropRect: cropRect
                    )
                }
                let coverPath = publishedCoverPath ?? oldCoverPath
                let savedList: ExcerptList
                switch mode {
                case .newList:
                    savedList = try database.createExcerptList(
                        name: name,
                        description: description,
                        coverPath: coverPath
                    )
                case .edit(let list):
                    savedList = try database.updateExcerptList(
                        id: list.id,
                        name: name,
                        description: description,
                        coverPath: coverPath
                    )
                }

                if publishedCoverPath != nil, oldCoverPath != nil {
                    do {
                        try await self.excerptListCoverStorage.remove(path: oldCoverPath)
                    } catch {
                        print("Failed to remove replaced Excerpt list cover: \(error)")
                    }
                }
                guard self.excerpt.listEditorSession?.id == session.id else {
                    return
                }
                session.isSaving = false
                self.excerpt.listEditorSession = nil
                if !self.excerpt.upsertListSummary(savedList) {
                    self.reloadExcerptListOverview()
                }
                if let pendingTransfer = session.pendingTransfer {
                    self.runExcerptListEditorPendingTransfer(
                        pendingTransfer,
                        toListID: savedList.id,
                        listName: savedList.name
                    )
                }
            } catch is CancellationError {
                if let publishedCoverPath {
                    try? await self.excerptListCoverStorage.remove(path: publishedCoverPath)
                }
                if self.excerpt.listEditorSession?.id == session.id {
                    session.isSaving = false
                }
            } catch {
                if let publishedCoverPath {
                    try? await self.excerptListCoverStorage.remove(path: publishedCoverPath)
                }
                guard self.excerpt.listEditorSession?.id == session.id else {
                    return
                }
                session.isSaving = false
                if let validationError = error as? ExcerptListValidationError {
                    let validation = try? database.validateExcerptList(
                        name: session.name,
                        description: session.listDescription,
                        excludingListID: session.mode.editedList?.id
                    )
                    if let validation {
                        session.apply(validation: validation)
                    } else {
                        print("Failed to revalidate Excerpt list after \(validationError)")
                    }
                } else {
                    print("Failed to save Excerpt list: \(error)")
                }
            }
            self.excerptListSaveTask = nil
        }
    }

    @discardableResult
    func deleteExcerptList(id: Int64) -> Bool {
        guard let database = excerptDatabase else {
            return false
        }
        do {
            let deleted = try database.deleteExcerptList(id: id)
            if workbenchLayout.selectedExcerptListID == id {
                // The page being looked at is gone: going back to the overview
                // is a step of its own, like any other page change.
                navigateWorkbench(to: .excerpt)
            }
            if excerpt.activeListID == id {
                let nextListID = try database.firstExcerptListID()
                if let nextListID {
                    excerpt.updateTableFacetFilter(
                        settings.excerptFacetFilter(forListID: nextListID)
                    )
                }
                excerpt.setActiveListID(nextListID)
            }
            let didUpdateOverview = (try? database.uniqueExcerptCueCount())
                .map {
                    excerpt.removeListSummary(id: id, uniqueCueCount: $0)
                } ?? false
            if !didUpdateOverview {
                reloadExcerptListOverview()
            }
            if let coverPath = deleted.coverPath {
                Task {
                    do {
                        try await excerptListCoverStorage.remove(path: coverPath)
                    } catch {
                        print("Failed to remove deleted Excerpt list cover: \(error)")
                    }
                }
            }
            return true
        } catch {
            print("Failed to delete Excerpt list: \(error)")
            return false
        }
    }

    func loadExcerptTableRowsIfNeeded() {
        guard !indexing.indexingStatus.isIndexing,
              !indexing.folderRemovalStatus.isRemoving
        else {
            return
        }
        guard excerptTableRowsTask == nil else {
            return
        }
        let snapshot = excerpt.tableRowStore.snapshot
        guard !excerpt.tableHasLoadedInitialPage
                || snapshot.totalRowCount != excerpt.tableResultRowCount
                || excerpt.tableRowsNeedReload
        else {
            return
        }
        reloadExcerptTableRows()
    }

    func reloadExcerptTableRows() {
        guard !indexing.indexingStatus.isIndexing,
              !indexing.folderRemovalStatus.isRemoving
        else {
            return
        }
        guard let listID = excerpt.activeListID
                ?? (try? excerptDatabase?.firstExcerptListID())
        else {
            excerpt.clearTableRowsForReload()
            excerpt.markTableRowsLoaded(totalSavedRowCount: 0)
            return
        }

        excerptTableRowsTask?.cancel()
        if excerpt.activeListID == nil {
            excerpt.updateTableFacetFilter(
                settings.excerptFacetFilter(forListID: listID)
            )
        }
        excerpt.setActiveListID(listID)
        excerpt.clearTableRowsForReload()

        let resultSnapshotID = excerpt.tableResultSnapshotID
        let searchText = excerpt.tableSearchDraft
        let facetFilter = excerpt.tableFacetFilter
        let dataRevision = excerpt.tableDataRevision
        if excerpt.residentDataRevision == dataRevision,
           excerpt.residentListID == listID {
            applyResidentExcerptTableProjection(
                resultSnapshotID: resultSnapshotID,
                searchText: searchText,
                facetFilter: facetFilter,
                listID: listID,
                dataRevision: dataRevision
            )
            return
        }

        excerptTableRowsTask = Task { @MainActor [weak self] in
            guard let self else {
                return
            }
            defer {
                if self.excerpt.tableResultSnapshotID == resultSnapshotID {
                    self.excerptTableRowsTask = nil
                }
            }

            do {
                let databaseURL = self.databaseURL
                let residentSnapshot = try await Self.runCancellableDetached(
                    priority: .userInitiated
                ) {
                    try ExcerptDatabase(
                        path: databaseURL,
                        access: .readOnly
                    ).excerptResidentSnapshot(listID: listID)
                }
                guard self.excerptTableRequestMatches(
                    resultSnapshotID: resultSnapshotID,
                    searchText: searchText,
                    facetFilter: facetFilter,
                    listID: listID,
                    dataRevision: dataRevision
                ) else {
                    return
                }
                self.cueContent.install(residentSnapshot.cueContents)
                self.excerpt.installResidentSnapshot(
                    residentSnapshot,
                    listID: listID,
                    dataRevision: dataRevision
                )
                self.applyResidentExcerptTableProjection(
                    resultSnapshotID: resultSnapshotID,
                    searchText: searchText,
                    facetFilter: facetFilter,
                    listID: listID,
                    dataRevision: dataRevision
                )
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled else { return }
                print("Failed to load resident Excerpt data: \(error)")
                if self.excerptTableRequestMatches(
                    resultSnapshotID: resultSnapshotID,
                    searchText: searchText,
                    facetFilter: facetFilter,
                    listID: listID,
                    dataRevision: dataRevision
                ) {
                    self.excerpt.markTableRowsLoaded(totalSavedRowCount: 0)
                }
            }
        }
    }

    func prepareExcerptForIndexedContentMutation(under folders: [URL]) {
        excerptNeedsReloadAfterIndexedContentMutation =
            excerptNeedsReloadAfterIndexedContentMutation
            || excerpt.residentDataRevision != nil
            || excerpt.tableHasLoadedInitialPage
            || excerptTableRowsTask != nil
        excerptTableRowsTask?.cancel()
        excerptTableRowsTask = nil
        cueContent.remove { content in
            folders.contains { folder in
                Self.path(content.subtitlePath, isUnder: folder)
            }
        }
        excerpt.invalidateTableRows()
        excerpt.clearListOverviewForReload()
        excerptPlaybackNavigationScopeIDs = nil
        excerptPlaybackNavigationSnapshot = nil
    }

    func reloadExcerptAfterIndexedContentMutation() {
        excerptTableRowsTask?.cancel()
        excerptTableRowsTask = nil
        guard excerptNeedsReloadAfterIndexedContentMutation else {
            return
        }
        excerptNeedsReloadAfterIndexedContentMutation = false
        reloadExcerptListOverview()
        reloadExcerptTableRows()
    }

    func refreshExcerptForLibraryWatchStateChange() {
        guard excerpt.residentDataRevision != nil else { return }
        excerpt.markTableRowsStale()
        reloadExcerptTableRows()
    }

    func updateExcerptFacetFilter(_ filter: CueFacetFilter) {
        guard excerpt.updateTableFacetFilter(filter),
              let listID = excerpt.activeListID
        else {
            return
        }
        let dataRevision = excerpt.tableDataRevision
        guard excerpt.residentDataRevision == dataRevision,
              excerpt.residentListID == listID
        else {
            reloadExcerptTableRows()
            return
        }

        excerpt.beginTableResultProjection()
        applyResidentExcerptTableProjection(
            resultSnapshotID: excerpt.tableResultSnapshotID,
            searchText: excerpt.tableSearchDraft,
            facetFilter: filter,
            listID: listID,
            dataRevision: dataRevision
        )
    }

    func updateExcerptSearchQuery(_ searchText: String) {
        guard excerpt.updateTableSearchDraft(searchText) else {
            return
        }
        let normalizedSearchText = excerpt.tableSearchDraft
        UIInvalidationProbe.mark(
            "ACTION UI.ExcerptSearchQuery.changed",
            scope: uiProbeScope,
            details: "length=\(normalizedSearchText.count)"
        )
        guard let listID = excerpt.activeListID else {
            reloadExcerptTableRows()
            return
        }
        let dataRevision = excerpt.tableDataRevision
        guard excerpt.residentDataRevision == dataRevision,
              excerpt.residentListID == listID
        else {
            reloadExcerptTableRows()
            return
        }

        excerpt.beginTableResultProjection()
        applyResidentExcerptTableProjection(
            resultSnapshotID: excerpt.tableResultSnapshotID,
            searchText: normalizedSearchText,
            facetFilter: excerpt.tableFacetFilter,
            listID: listID,
            dataRevision: dataRevision
        )
    }

    /// The Excerpt table's rows for a search text and a selection, with the
    /// counts by the usual rule. The table installs them; the Filter dialog
    /// reads them for a selection it has not handed to the table yet.
    func residentExcerptTableProjection(
        searchText: String,
        facetFilter: CueFacetFilter
    ) -> (relations: [ExcerptRelation], distribution: CueFacetDistribution) {
        let trimmedSearchText = searchText.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        let facetProjection = excerpt.residentFacetProjection(
            using: search.normalizedFacetFilter(facetFilter)
        )
        let matchingExcerptIDs = Set(facetProjection.excerptIDs)
        let relations = excerpt.residentRelations.filter { relation in
            guard matchingExcerptIDs.contains(relation.id) else {
                return false
            }
            let content = cueContent.content(for: relation.cueID)
            guard let resolved = excerpt.residentExcerptsByID[relation.id] else {
                return false
            }
            let cueText = content?.content ?? resolved.content
            return trimmedSearchText.isEmpty
                || SubtitleSearchQueryMatcher.matches(
                    cueText,
                    query: trimmedSearchText
                )
        }
        return (relations, facetProjection.distribution)
    }

    private func applyResidentExcerptTableProjection(
        resultSnapshotID: UUID,
        searchText: String,
        facetFilter: CueFacetFilter,
        listID: Int64,
        dataRevision: Int
    ) {
        guard excerptTableRequestMatches(
            resultSnapshotID: resultSnapshotID,
            searchText: searchText,
            facetFilter: facetFilter,
            listID: listID,
            dataRevision: dataRevision
        ) else {
            return
        }

        let relations = residentExcerptTableProjection(
            searchText: searchText,
            facetFilter: facetFilter
        ).relations
        excerpt.installTableResultExcerptIDs(relations.map(\.id))
        excerpt.markTableRowsLoaded(
            totalSavedRowCount: excerpt.residentRelations.count
        )
        excerpt.tableRowStore.updateResidentExcerptRelations(
            relations,
            resolvedExcerptsByID: excerpt.residentExcerptsByID,
            cueContentProvider: { [cueContent] cueID in
                cueContent.content(for: cueID)
            },
            cueContentRevision: cueContent.revision,
            tableName: "excerpt",
            probeSurface: .excerpt,
            probeScope: uiProbeScope
        )
        refreshExcerptPlaybackPlaylistSource()
    }

    private func excerptTableRequestMatches(
        resultSnapshotID: UUID,
        searchText: String,
        facetFilter: CueFacetFilter,
        listID: Int64,
        dataRevision: Int
    ) -> Bool {
        !Task.isCancelled
            && excerpt.tableResultSnapshotID == resultSnapshotID
            && excerpt.tableSearchDraft == searchText
            && excerpt.tableFacetFilter == facetFilter
            && excerpt.activeListID == listID
            && excerpt.tableDataRevision == dataRevision
    }

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
                message: request.message
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
        guard let database = excerptDatabase else {
            reportExcerptSave(
                ExcerptToastRequest.saveFailed(listName: listName),
                report
            )
            return false
        }
        let destination: ExcerptList
        do {
            guard let availableDestination = try database.excerptList(
                id: destinationListID
            ) else {
                reportExcerptSave(
                    ExcerptToastRequest.destinationUnavailable(
                        listName: listName
                    ),
                    report
                )
                return false
            }
            destination = availableDestination
        } catch {
            print("Failed to resolve Excerpt save destination: \(error)")
            reportExcerptSave(
                ExcerptToastRequest.saveFailed(listName: listName),
                report
            )
            return false
        }

        do {
            guard try database.excerpt(
                cueID: cueID,
                listID: destinationListID
            ) == nil else {
                reportExcerptSave(
                    ExcerptToastRequest.destinationAlreadyContainsCue(
                        listName: destination.name
                    ),
                    report
                )
                return false
            }
            _ = try database.upsertExcerpt(
                cueID: cueID,
                listID: destinationListID
            )
            excerpt.markTableRowsStale()
            if !excerpt.adjustListCueCounts(
                [destinationListID: 1],
                uniqueCueCount: try? database.uniqueExcerptCueCount()
            ) {
                reloadExcerptListOverview()
            }
            excerpt.setRecentSaveListID(destinationListID)
            reportExcerptSave(
                ExcerptToastRequest.saveSucceeded(listName: destination.name),
                report
            )
            return true
        } catch {
            print("Failed to save Excerpt: \(error)")
            reportExcerptSave(
                ExcerptToastRequest.saveFailed(listName: destination.name),
                report
            )
        }
        return false
    }

    func moveExcerpt(
        _ item: Excerpt,
        toListID destinationListID: Int64,
        listName: String
    ) -> Bool {
        guard let database = excerptDatabase else {
            toast.show(ExcerptToastRequest.moveFailed)
            return false
        }
        let destination: ExcerptList
        do {
            guard let availableDestination = try database.excerptList(
                id: destinationListID
            ) else {
                toast.show(
                    ExcerptToastRequest.destinationUnavailable(
                        listName: listName
                    )
                )
                return false
            }
            destination = availableDestination
        } catch {
            print("Failed to resolve Excerpt move destination: \(error)")
            toast.show(ExcerptToastRequest.moveFailed)
            return false
        }

        do {
            _ = try database.moveExcerpt(
                id: item.id,
                toListID: destinationListID
            )
            let sourceListID = excerpt.activeListID
            handleExcerptRemovedFromCurrentList(item)
            let didUpdateOverview = sourceListID.map {
                excerpt.adjustListCueCounts([
                    $0: -1,
                    destinationListID: 1,
                ])
            } ?? false
            if !didUpdateOverview {
                reloadExcerptListOverview()
            }
            toast.show(
                ExcerptToastRequest.moveSucceeded(listName: destination.name)
            )
            return true
        } catch ExcerptTransferError.destinationUnavailable {
            toast.show(
                ExcerptToastRequest.destinationUnavailable(
                    listName: destination.name
                )
            )
        } catch ExcerptTransferError.destinationAlreadyContainsCue {
            toast.show(
                ExcerptToastRequest.destinationAlreadyContainsCue(
                    listName: destination.name
                )
            )
        } catch {
            print("Failed to move Excerpt: \(error)")
            toast.show(ExcerptToastRequest.moveFailed)
        }
        return false
    }

    @discardableResult
    func duplicateExcerpt(
        _ item: Excerpt,
        toListID destinationListID: Int64,
        listName: String
    ) -> Bool {
        guard let database = excerptDatabase else {
            toast.show(ExcerptToastRequest.duplicateFailed)
            return false
        }
        let destination: ExcerptList
        do {
            guard let availableDestination = try database.excerptList(
                id: destinationListID
            ) else {
                toast.show(
                    ExcerptToastRequest.destinationUnavailable(
                        listName: listName
                    )
                )
                return false
            }
            destination = availableDestination
        } catch {
            print("Failed to resolve Excerpt duplicate destination: \(error)")
            toast.show(ExcerptToastRequest.duplicateFailed)
            return false
        }

        do {
            _ = try database.duplicateExcerpt(
                id: item.id,
                toListID: destinationListID
            )
            if !excerpt.adjustListCueCounts([destinationListID: 1]) {
                reloadExcerptListOverview()
            }
            toast.show(
                ExcerptToastRequest.duplicateSucceeded(listName: destination.name)
            )
            return true
        } catch ExcerptTransferError.destinationUnavailable {
            toast.show(
                ExcerptToastRequest.destinationUnavailable(
                    listName: destination.name
                )
            )
        } catch ExcerptTransferError.destinationAlreadyContainsCue {
            toast.show(
                ExcerptToastRequest.destinationAlreadyContainsCue(
                    listName: destination.name
                )
            )
        } catch {
            print("Failed to duplicate Excerpt: \(error)")
            toast.show(ExcerptToastRequest.duplicateFailed)
        }
        return false
    }

    @discardableResult
    func removeExcerpt(_ item: Excerpt, reloadPresentation: Bool = true) -> Bool {
        guard let database = excerptDatabase else {
            playback.playbackViewModel?.showExcerptFeedback(.unavailable)
            return false
        }

        do {
            try database.removeExcerpt(id: item.id)
            _ = reloadPresentation
            let sourceListID = excerpt.activeListID
            handleExcerptRemovedFromCurrentList(item)
            let uniqueCueCount = try? database.uniqueExcerptCueCount()
            let didUpdateOverview = sourceListID.flatMap { sourceListID in
                uniqueCueCount.map {
                    excerpt.adjustListCueCounts(
                        [sourceListID: -1],
                        uniqueCueCount: $0
                    )
                }
            } ?? false
            if !didUpdateOverview {
                reloadExcerptListOverview()
            }
            playback.playbackViewModel?.showExcerptFeedback(.removed)
            return true
        } catch {
            print("Failed to remove Excerpt: \(error)")
            playback.playbackViewModel?.showExcerptFeedback(.unavailable)
            return false
        }
    }

    private func handleExcerptRemovedFromCurrentList(_ item: Excerpt) {
        excerpt.removeExcerptFromCurrentProjection(id: item.id)
        removeExcerptFromPlaybackNavigationScope(item.id)
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

    func openExcerpt(
        _ excerpt: Excerpt,
        navigationScopeIDs: [Int64]? = nil,
        playlistScope: PlaybackPlaylistExcerptScope? = nil,
        playlistSelectedOrdinal: Int? = nil,
        displayTitle: String? = nil
    ) {
        guard excerpt.isValid else {
            return
        }
        clearCueAutoStopPlayback()
        invalidatePlaybackSubtitleFocusForSourceReplacement()
        playback.playbackStatus = .opening
        UIInvalidationProbe.mark(
            "ACTION UI.Excerpt.opened",
            details: "time=\(String(format: "%.2f", Double(excerpt.startMilliseconds) / 1000.0))"
        )
        preparePlaybackKeyboardFocus()
        let keepsExistingPlaylistSnapshot = playlistScope.map { scope in
            playback.playlistSource?.origin == .excerpt(scope: scope)
                && excerptPlaybackNavigationScopeIDs != nil
        } ?? false
        if !keepsExistingPlaylistSnapshot {
            if case .table(let context)? = playlistScope,
               let navigationScopeIDs,
               navigationScopeIDs.count == context.totalCount {
                // Core table snapshots are already ordered and unique by the
                // Excerpt primary key. Keep their copy-on-write ID buffer.
                excerptPlaybackNavigationScopeIDs = navigationScopeIDs
            } else {
                excerptPlaybackNavigationScopeIDs = normalizedExcerptPlaybackNavigationScopeIDs(
                    navigationScopeIDs
                )
            }
        }
        installExcerptPlaybackPlaylistSource(scope: playlistScope)
        let resolvedPlaylistOrdinal = refreshExcerptPlaybackNavigationSnapshot(
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
        saveCurrentLibraryPlaybackHistory()
        stopLibraryPlaybackHistoryTracking()
        activePlaybackSource = .excerpt
        self.excerpt.selectedExcerpt = excerpt
        search.selectResult(nil)
        library.selectedLibraryVideo = nil
        refreshPlaybackChromeSnapshot(
            displayTitle: playbackDisplayTitle(
                for: excerpt,
                providedDisplayTitle: displayTitle
            )
        )
        playback.isPlaybackSurfaceExpanded = true
        Task { @MainActor in
            await Task.yield()
            _ = play(excerpt)
        }
    }

    @discardableResult
    func play(_ excerpt: Excerpt) -> Bool {
        ensurePlayerInitialized()
        beginCueAutoStopPlayback()
        saveCurrentLibraryPlaybackHistory()
        stopLibraryPlaybackHistoryTracking()
        activePlaybackSource = .excerpt
        playback.playbackStatus = .opening
        playback.playbackViewModel?.preparePresentationTransition(
            to: Double(excerpt.startMilliseconds) / 1_000,
            subtitleCues: []
        )

        do {
            let autoStopBoundary = configureCueAutoStopBoundary(
                startMilliseconds: excerpt.startMilliseconds,
                endMilliseconds: excerpt.endMilliseconds
            )
            let request = try PlaybackRequest(
                videoURL: URL(fileURLWithPath: excerpt.videoPath),
                startMilliseconds: excerpt.startMilliseconds,
                autoStopAtMilliseconds: autoStopBoundary?.endMilliseconds,
                subtitleSource: playbackSubtitleSource(for: excerpt),
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
            playback.playbackViewModel?.cancelPendingPresentation()
            clearCueAutoStopPlayback()
            playback.playbackViewModel?.clearSubtitleCues()
            playback.playbackStatus = .failed(Self.errorMessage(for: error))
            return false
        }
    }

    func recordRecentExcerptPlayback(for item: Excerpt) {
        guard let excerptDatabase else {
            return
        }
        do {
            try excerptDatabase.recordRecentExcerptPlayback(excerptID: item.id)
            excerptListOverviewTask?.cancel()
            excerpt.installRecentListSummaries(
                try excerptDatabase.recentExcerptListSummaries()
            )
        } catch {
            print("Failed to record recent Excerpt playback: \(error)")
        }
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

    private func refreshExcerptPlaybackNavigationSnapshot(
        for selectedExcerpt: Excerpt,
        preferredOrdinal: Int? = nil
    ) -> Int? {
        let selectedID = selectedExcerpt.id
        let validatedPreferredOrdinal: Int?
        if let preferredOrdinal,
           playback.playlistSource?.itemIdentity(at: preferredOrdinal)
            == .excerpt(selectedID) {
            validatedPreferredOrdinal = preferredOrdinal
        } else {
            validatedPreferredOrdinal = nil
        }

        if let source = playback.playlistSource,
           case .excerpt(.table) = source.origin {
            let scopeIDs = excerptPlaybackNavigationScopeIDs
                ?? excerpt.playbackTableResultExcerptIDs
            guard let scopeIDs,
                  let index = validatedPreferredOrdinal
                    ?? scopeIDs.firstIndex(of: selectedID)
            else {
                excerptPlaybackNavigationSnapshot = (
                    currentID: selectedID,
                    previousID: nil,
                    nextID: nil
                )
                return nil
            }
            excerptPlaybackNavigationSnapshot = (
                currentID: selectedID,
                previousID: index > 0 ? scopeIDs[index - 1] : nil,
                nextID: index + 1 < scopeIDs.count
                    ? scopeIDs[index + 1]
                    : nil
            )
            return index
        }

        if let scopeIDs = excerptPlaybackNavigationScopeIDs,
           let index = validatedPreferredOrdinal
                ?? scopeIDs.firstIndex(of: selectedID) {
            excerptPlaybackNavigationSnapshot = (
                currentID: selectedID,
                previousID: index > 0 ? scopeIDs[index - 1] : nil,
                nextID: index + 1 < scopeIDs.count ? scopeIDs[index + 1] : nil
            )
            return index
        }

        let residentRelations = excerpt.residentRelations.filter {
            excerpt.residentExcerptsByID[$0.id]?.isValid == true
        }
        let residentOrdinal = validatedPreferredOrdinal
            ?? residentRelations.firstIndex(where: { $0.id == selectedID })

        if let index = residentOrdinal {
            excerptPlaybackNavigationSnapshot = (
                currentID: selectedID,
                previousID: index > 0 ? residentRelations[index - 1].id : nil,
                nextID: index + 1 < residentRelations.count
                    ? residentRelations[index + 1].id
                    : nil
            )
            return index
        }

        if let database = excerptDatabase {
            do {
                excerptPlaybackNavigationSnapshot = (
                    currentID: selectedID,
                    previousID: try database.adjacentExcerpt(to: selectedExcerpt, direction: .previous)?.id,
                    nextID: try database.adjacentExcerpt(to: selectedExcerpt, direction: .next)?.id
                )
                return nil
            } catch {
                print("Failed to load adjacent Excerpt: \(error)")
            }
        }

        excerptPlaybackNavigationSnapshot = (
            currentID: selectedID,
            previousID: nil,
            nextID: nil
        )
        return nil
    }

    func excerpt(withID id: Int64) -> Excerpt? {
        if let entryID = Int(exactly: id),
           let tableItem = excerpt.tableRowStore.snapshot.excerpt(entryID: entryID) {
            return tableItem
        }
        if let relation = excerpt.residentRelations.first(where: { $0.id == id }),
           let content = cueContent.content(for: relation.cueID) {
            return Excerpt(relation: relation, cueContent: content)
        }
        guard let excerptDatabase else {
            return nil
        }

        do {
            guard let relation = try excerptDatabase.excerptRelation(id: id),
                  let content = try CueContentDatabase(path: databaseURL).cueContents(
                    forCueIDs: [relation.cueID]
                  ).first
            else {
                return nil
            }
            cueContent.install([content])
            return Excerpt(relation: relation, cueContent: content)
        } catch {
            print("Failed to load scoped Excerpt: \(error)")
            return nil
        }
    }

    private func normalizedExcerptPlaybackNavigationScopeIDs(_ ids: [Int64]?) -> [Int64]? {
        guard let ids else {
            return nil
        }

        var seenIDs: Set<Int64> = []
        let normalizedIDs = ids.filter { seenIDs.insert($0).inserted }
        return normalizedIDs.isEmpty ? nil : normalizedIDs
    }

    private func removeExcerptFromPlaybackNavigationScope(_ id: Int64) {
        guard var scopeIDs = excerptPlaybackNavigationScopeIDs else {
            return
        }

        scopeIDs.removeAll { $0 == id }
        excerptPlaybackNavigationScopeIDs = scopeIDs.isEmpty ? nil : scopeIDs
    }
}
