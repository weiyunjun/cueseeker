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
                    let database = try ExcerptDatabase(
                        path: databaseURL,
                        access: .readOnly
                    )
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
        guard let database = excerptDatabase else { return }
        do {
            let relations = try database.excerptRelations(
                listID: summary.list.id
            )
            let resolvedByID = Dictionary(
                uniqueKeysWithValues: try database.excerpts(
                    listID: summary.list.id
                ).map { ($0.id, $0) }
            )
            let navigationScopeIDs = relations.compactMap { relation -> Int64? in
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
                if let fallbackTarget = preferredExcerptID.flatMap({ resolvedByID[$0] })
                    ?? summary.resumeExcerpt
                    ?? relations.first.flatMap({ resolvedByID[$0.id] }) {
                    openExcerpt(
                        fallbackTarget,
                        navigationScopeIDs: [],
                        playlistScope: .explicitIDs([]),
                        playlistSelectedOrdinal: nil,
                        displayTitle: fallbackTarget.displayTitle,
                        allowsUnavailableTarget: true
                    )
                    return
                }
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
        if let pendingTransfer, case .excerpt(let item) = pendingTransfer.target {
            guard item.isValid, excerptIDsInLibrary(among: [item.id]).contains(item.id) else {
                toast.show(TableToastRequest.cueNotInLibrary)
                return
            }
        }
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
                let databaseURL = self.databaseURL
                let savedList: ExcerptList = try await Self.runCancellableDetached(
                    priority: .userInitiated
                ) {
                    let db = try ExcerptDatabase(path: databaseURL)
                    switch mode {
                    case .newList:
                        return try db.createExcerptList(
                            name: name,
                            description: description,
                            coverPath: coverPath
                        )
                    case .edit(let list):
                        return try db.updateExcerptList(
                            id: list.id,
                            name: name,
                            description: description,
                            coverPath: coverPath
                        )
                    }
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
        guard excerptDatabase != nil else {
            return false
        }
        if workbenchLayout.selectedExcerptListID == id {
            // The page being looked at is gone: going back to the overview
            // is a step of its own, like any other page change.
            navigateWorkbench(to: .excerpt)
        }
        settings.removeExcerptListSettings(forListID: id)
        if excerpt.activeListID == id {
            let nextListID = excerpt.listOverview.lists.first(where: { $0.id != id })?.id
            excerpt.setActiveListID(nextListID)
            if let nextListID {
                excerpt.updateTableFacetFilter(
                    settings.excerptFacetFilter(forListID: nextListID)
                )
                excerpt.updateTableSortOrder(
                    settings.excerptSortOrder(forListID: nextListID)
                )
            } else {
                excerpt.updateTableFacetFilter(CueFacetFilter())
                excerpt.updateTableSortOrder(.earliestDateAdded)
            }
        }
        let currentUniqueCount = excerpt.listOverview.uniqueCueCount
        let removedCueCount = excerpt.listOverview.lists.first(where: { $0.id == id })?.cueCount ?? 0
        let estimatedUniqueCount = max(0, currentUniqueCount - removedCueCount)
        excerpt.removeListSummary(id: id, uniqueCueCount: estimatedUniqueCount)

        let databaseURL = databaseURL
        excerptListSaveTask?.cancel()
        excerptListSaveTask = Task { @MainActor [weak self] in
            defer { self?.excerptListSaveTask = nil }
            do {
                let (deleted, uniqueCueCount) = try await Self.runCancellableDetached(
                    priority: .userInitiated
                ) {
                    let db = try ExcerptDatabase(path: databaseURL)
                    let list = try db.deleteExcerptList(id: id)
                    let count = try db.uniqueExcerptCueCount()
                    return (list, count)
                }
                guard let self else { return }
                self.excerpt.removeListSummary(id: id, uniqueCueCount: uniqueCueCount)
                if let coverPath = deleted.coverPath {
                    do {
                        try await self.excerptListCoverStorage.remove(path: coverPath)
                    } catch {
                        print("Failed to remove deleted Excerpt list cover: \(error)")
                    }
                }
            } catch {
                print("Failed to delete Excerpt list in background: \(error)")
                self?.reloadExcerptListOverview()
            }
        }
        return true
    }

    func loadExcerptTableRowsIfNeeded() {
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
        guard let listID = excerpt.activeListID
                ?? (try? excerptDatabase?.firstExcerptListID())
        else {
            excerpt.clearTableRowsForReload()
            excerpt.markTableRowsLoaded(totalSavedRowCount: 0)
            return
        }

        excerptTableRowsTask?.cancel()
        let wasActiveListIDNil = excerpt.activeListID == nil
        excerpt.setActiveListID(listID)
        if wasActiveListIDNil {
            excerpt.updateTableFacetFilter(
                settings.excerptFacetFilter(forListID: listID)
            )
            excerpt.updateTableSortOrder(
                settings.excerptSortOrder(forListID: listID)
            )
        }

        let resultSnapshotID = excerpt.tableResultSnapshotID
        let searchText = excerpt.tableSearchDraft
        let facetFilter = excerpt.tableFacetFilter
        let sortOrder = excerpt.tableSortOrder
        let dataRevision = excerpt.tableDataRevision
        if excerpt.residentDataRevision == dataRevision,
           excerpt.residentListID == listID {
            applyResidentExcerptTableProjection(
                resultSnapshotID: resultSnapshotID,
                searchText: searchText,
                facetFilter: facetFilter,
                sortOrder: sortOrder,
                listID: listID,
                dataRevision: dataRevision
            )
            ExcerptOpenPerformanceTracker.recordDataReady(
                listID: listID,
                count: excerpt.residentRelations.count,
                cacheHit: true
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
                    sortOrder: sortOrder,
                    listID: listID,
                    dataRevision: dataRevision
                ) else {
                    ExcerptOpenPerformanceTracker.cancelOpen(listID: listID)
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
                    sortOrder: sortOrder,
                    listID: listID,
                    dataRevision: dataRevision
                )
                ExcerptOpenPerformanceTracker.recordDataReady(
                    listID: listID,
                    count: residentSnapshot.relations.count,
                    cacheHit: false
                )
            } catch is CancellationError {
                ExcerptOpenPerformanceTracker.cancelOpen(listID: listID)
                return
            } catch {
                guard !Task.isCancelled else { return }
                print("Failed to load resident Excerpt data: \(error)")
                ExcerptOpenPerformanceTracker.cancelOpen(listID: listID)
                if self.excerptTableRequestMatches(
                    resultSnapshotID: resultSnapshotID,
                    searchText: searchText,
                    facetFilter: facetFilter,
                    sortOrder: sortOrder,
                    listID: listID,
                    dataRevision: dataRevision
                ) {
                    self.excerpt.markTableRowsLoaded(totalSavedRowCount: 0)
                }
            }
        }
    }

    func prepareExcerptForIndexedContentMutation(under folders: [URL]) {
        excerptNeedsReloadAfterIndexedContentMutation = true
        pendingExcerptContentRemovalFolders.append(contentsOf: folders)
        excerptPlaybackNavigationScopeIDs = nil
        excerptPlaybackNavigationSnapshot = nil
    }

    func reloadExcerptAfterIndexedContentMutation() {
        excerptNeedsReloadAfterIndexedContentMutation = true
    }

    func refreshExcerptOnReappearanceIfNeeded() {
        guard excerptNeedsReloadAfterIndexedContentMutation else {
            return
        }
        excerptNeedsReloadAfterIndexedContentMutation = false
        let folders = pendingExcerptContentRemovalFolders
        pendingExcerptContentRemovalFolders.removeAll()
        if !folders.isEmpty {
            cueContent.remove { content in
                folders.contains { folder in
                    Self.path(content.subtitlePath, isUnder: folder)
                }
            }
        }
        excerpt.markTableRowsStale()
        reloadExcerptListOverview()
        reloadExcerptTableRows()
        refreshRecentWatching()
    }

    func refreshExcerptForLibraryWatchStateChange() {
        guard excerpt.residentDataRevision != nil else { return }
        excerpt.markTableRowsStale()
        reloadExcerptTableRows()
    }

    func applyRenameToExcerpt(_ steps: [LibraryRenameStep]) {
        let rewrittenFilter = search.normalizedFacetFilter(
            excerpt.tableFacetFilter.rewritingFolderPaths(steps)
        )
        _ = excerpt.updateTableFacetFilter(rewrittenFilter)
        let cachedCueIDs = cueContent.cachedCueIDs
        if !cachedCueIDs.isEmpty,
           let updatedContents = try? CueContentDatabase(path: databaseURL)
               .cueContents(forCueIDs: cachedCueIDs),
           !updatedContents.isEmpty {
            cueContent.install(updatedContents)
        }
        excerpt.applyRename(steps, cueContentStore: cueContent)
        if excerpt.hasLoadedListOverview, let excerptDatabase {
            if let overview = try? excerptDatabase.excerptListOverview() {
                excerpt.installListOverview(overview)
            }
            if let summaries = try? excerptDatabase.recentExcerptListSummaries() {
                excerpt.installRecentListSummaries(summaries)
            }
        }
        reloadExcerptListOverview()
    }

    func updateExcerptFacetFilter(_ filter: CueFacetFilter) {
        guard excerpt.updateTableFacetFilter(filter),
              let listID = excerpt.activeListID
        else {
            return
        }
        settings.setExcerptFacetFilter(filter, forListID: listID)
        if excerptNeedsReloadAfterIndexedContentMutation {
            refreshExcerptOnReappearanceIfNeeded()
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
            sortOrder: excerpt.tableSortOrder,
            listID: listID,
            dataRevision: dataRevision
        )
    }

    func updateExcerptSortOrder(_ sortOrder: ExcerptSortOrder) {
        guard excerpt.updateTableSortOrder(sortOrder),
              let listID = excerpt.activeListID
        else {
            return
        }
        settings.setExcerptSortOrder(sortOrder, forListID: listID)
        if excerptNeedsReloadAfterIndexedContentMutation {
            refreshExcerptOnReappearanceIfNeeded()
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
            facetFilter: excerpt.tableFacetFilter,
            sortOrder: sortOrder,
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
        if excerptNeedsReloadAfterIndexedContentMutation {
            refreshExcerptOnReappearanceIfNeeded()
            return
        }
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
            sortOrder: excerpt.tableSortOrder,
            listID: listID,
            dataRevision: dataRevision
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
        let trimmedSearchText = searchText.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        let normalizedFilter = search.normalizedFacetFilter(facetFilter)
        let facetProjection = excerpt.residentFacetProjection(
            using: normalizedFilter
        )
        let matchingExcerptIDs = Set(facetProjection.excerptIDs)
        var validSearchMatchingCueIDs = Set<Int64>()
        let relations = excerpt.residentRelations.filter { relation in
            let content = cueContent.content(for: relation.cueID)
            guard let resolved = excerpt.residentExcerptsByID[relation.id] else {
                return false
            }
            let cueText = content?.content ?? resolved.content
            let matchesSearch = trimmedSearchText.isEmpty
                || SubtitleSearchQueryMatcher.matches(
                    cueText,
                    query: trimmedSearchText
                )
            if matchesSearch, resolved.isValid {
                validSearchMatchingCueIDs.insert(relation.cueID)
            }
            guard matchingExcerptIDs.contains(relation.id) else {
                return false
            }
            return matchesSearch
        }
        let resolvedSortOrder = sortOrder ?? excerpt.tableSortOrder
        let sortedRelations: [ExcerptRelation]
        switch resolvedSortOrder {
        case .earliestDateAdded:
            sortedRelations = relations
        case .latestDateAdded:
            sortedRelations = relations.enumerated().sorted { lhs, rhs in
                if lhs.element.createdAt != rhs.element.createdAt {
                    return lhs.element.createdAt > rhs.element.createdAt
                }
                return lhs.offset < rhs.offset
            }.map(\.element)
        case .mostCharacters, .fewestCharacters:
            let widths = relations.map { relation -> Int in
                let cueText = cueContent.content(for: relation.cueID)?.content
                    ?? excerpt.residentExcerptsByID[relation.id]?.content
                    ?? ""
                return CueCharacterFacet.characterWidth(of: cueText)
            }
            sortedRelations = relations.indices.sorted { lhs, rhs in
                if widths[lhs] != widths[rhs] {
                    return resolvedSortOrder == .mostCharacters
                        ? widths[lhs] > widths[rhs]
                        : widths[lhs] < widths[rhs]
                }
                return lhs < rhs
            }.map { relations[$0] }
        }
        let validFacetSnapshot = excerpt.residentFacetSnapshot?.keeping(
            cueIDs: validSearchMatchingCueIDs
        ) ?? .empty
        let validDistribution = validFacetSnapshot.filteredCueIDs(
            using: normalizedFilter,
            limit: validFacetSnapshot.cueIDs.count
        ).distribution
        return (sortedRelations, validDistribution)
    }

    private func applyResidentExcerptTableProjection(
        resultSnapshotID: UUID,
        searchText: String,
        facetFilter: CueFacetFilter,
        sortOrder: ExcerptSortOrder,
        listID: Int64,
        dataRevision: Int
    ) {
        guard excerptTableRequestMatches(
            resultSnapshotID: resultSnapshotID,
            searchText: searchText,
            facetFilter: facetFilter,
            sortOrder: sortOrder,
            listID: listID,
            dataRevision: dataRevision
        ) else {
            return
        }

        let relations = residentExcerptTableProjection(
            searchText: searchText,
            facetFilter: facetFilter,
            sortOrder: sortOrder
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
        sortOrder: ExcerptSortOrder,
        listID: Int64,
        dataRevision: Int
    ) -> Bool {
        !Task.isCancelled
            && excerpt.tableResultSnapshotID == resultSnapshotID
            && excerpt.tableSearchDraft == searchText
            && excerpt.tableFacetFilter == facetFilter
            && excerpt.tableSortOrder == sortOrder
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
        // A destination menu opened before the cue left the library.
        if !isCueInLibrary(cueID) {
            switch report {
            case .toast:
                toast.show(TableToastRequest.cueNotInLibrary)
            case .playbackFeedback:
                playback.playbackViewModel?.showNotInLibraryFeedback()
            }
            return false
        }
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
            excerpt.markTableRowsStale()
            if !excerpt.adjustListCueCounts([destinationListID: 1]) {
                reloadExcerptListOverview()
            }
            excerpt.setRecentSaveListID(destinationListID)
            reportExcerptSave(
                ExcerptToastRequest.saveSucceeded(listName: destination.name),
                report
            )

            let databaseURL = databaseURL
            excerptMutationTask?.cancel()
            excerptMutationTask = Task { @MainActor [weak self] in
                defer { self?.excerptMutationTask = nil }
                do {
                    let (uniqueCueCount, recentSummaries) = try await Self.runCancellableDetached(priority: .userInitiated) {
                        let db = try ExcerptDatabase(path: databaseURL)
                        _ = try db.upsertExcerpt(cueID: cueID, listID: destinationListID)
                        return (try db.uniqueExcerptCueCount(), try db.recentExcerptListSummaries())
                    }
                    guard let self else { return }
                    _ = self.excerpt.adjustListCueCounts([destinationListID: 0], uniqueCueCount: uniqueCueCount)
                    self.excerpt.installRecentListSummaries(recentSummaries)
                } catch {
                    print("Failed to save Excerpt in background: \(error)")
                    guard let self else { return }
                    self.reportExcerptSave(
                        ExcerptToastRequest.saveFailed(listName: destination.name),
                        report
                    )
                    self.reloadExcerptListOverview()
                }
            }
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
        guard item.isValid, excerptIDsInLibrary(among: [item.id]).contains(item.id) else {
            toast.show(TableToastRequest.cueNotInLibrary)
            return false
        }
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

        if let relation = try? database.excerptRelation(id: item.id),
           let exists = try? database.excerptRelationExists(cueID: relation.cueID, listID: destinationListID),
           exists {
            toast.show(
                ExcerptToastRequest.destinationAlreadyContainsCue(
                    listName: destination.name
                )
            )
            return false
        }

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

        let databaseURL = databaseURL
        let itemID = item.id
        let destinationName = destination.name
        excerptMutationTask?.cancel()
        excerptMutationTask = Task { @MainActor [weak self] in
            defer { self?.excerptMutationTask = nil }
            do {
                let recentSummaries = try await Self.runCancellableDetached(priority: .userInitiated) {
                    let db = try ExcerptDatabase(path: databaseURL)
                    _ = try db.moveExcerpt(id: itemID, toListID: destinationListID)
                    return try db.recentExcerptListSummaries()
                }
                guard let self, !self.excerptNeedsReloadAfterIndexedContentMutation else { return }
                self.excerpt.installRecentListSummaries(recentSummaries)
            } catch ExcerptTransferError.destinationUnavailable {
                self?.toast.show(ExcerptToastRequest.destinationUnavailable(listName: destinationName))
                self?.reloadExcerptListOverview()
                self?.reloadExcerptTableRows()
            } catch ExcerptTransferError.destinationAlreadyContainsCue {
                self?.toast.show(ExcerptToastRequest.destinationAlreadyContainsCue(listName: destinationName))
                self?.reloadExcerptListOverview()
                self?.reloadExcerptTableRows()
            } catch {
                print("Failed to move Excerpt in background: \(error)")
                self?.toast.show(ExcerptToastRequest.moveFailed)
                self?.reloadExcerptListOverview()
                self?.reloadExcerptTableRows()
            }
        }
        return true
    }

    @discardableResult
    func duplicateExcerpt(
        _ item: Excerpt,
        toListID destinationListID: Int64,
        listName: String
    ) -> Bool {
        guard item.isValid, excerptIDsInLibrary(among: [item.id]).contains(item.id) else {
            toast.show(TableToastRequest.cueNotInLibrary)
            return false
        }
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

        if let relation = try? database.excerptRelation(id: item.id),
           let exists = try? database.excerptRelationExists(cueID: relation.cueID, listID: destinationListID),
           exists {
            toast.show(
                ExcerptToastRequest.destinationAlreadyContainsCue(
                    listName: destination.name
                )
            )
            return false
        }

        if !excerpt.adjustListCueCounts([destinationListID: 1]) {
            reloadExcerptListOverview()
        }
        toast.show(
            ExcerptToastRequest.duplicateSucceeded(listName: destination.name)
        )

        let databaseURL = databaseURL
        let itemID = item.id
        let destinationName = destination.name
        excerptMutationTask?.cancel()
        excerptMutationTask = Task { @MainActor [weak self] in
            defer { self?.excerptMutationTask = nil }
            do {
                let recentSummaries = try await Self.runCancellableDetached(priority: .userInitiated) {
                    let db = try ExcerptDatabase(path: databaseURL)
                    _ = try db.duplicateExcerpt(id: itemID, toListID: destinationListID)
                    return try db.recentExcerptListSummaries()
                }
                guard let self, !self.excerptNeedsReloadAfterIndexedContentMutation else { return }
                self.excerpt.installRecentListSummaries(recentSummaries)
            } catch ExcerptTransferError.destinationUnavailable {
                self?.toast.show(ExcerptToastRequest.destinationUnavailable(listName: destinationName))
                self?.reloadExcerptListOverview()
            } catch ExcerptTransferError.destinationAlreadyContainsCue {
                self?.toast.show(ExcerptToastRequest.destinationAlreadyContainsCue(listName: destinationName))
                self?.reloadExcerptListOverview()
            } catch {
                print("Failed to duplicate Excerpt in background: \(error)")
                self?.toast.show(ExcerptToastRequest.duplicateFailed)
                self?.reloadExcerptListOverview()
            }
        }
        return true
    }

    @discardableResult
    func removeExcerpt(_ item: Excerpt, reloadPresentation: Bool = true) -> Bool {
        guard excerptDatabase != nil else {
            playback.playbackViewModel?.showExcerptFeedback(.unavailable)
            return false
        }

        _ = reloadPresentation
        let sourceListID = excerpt.activeListID
        let cueCountDelta = item.isValid ? -1 : 0
        handleExcerptRemovedFromCurrentList(item)
        if let sourceListID {
            _ = excerpt.adjustListCueCounts([sourceListID: cueCountDelta])
        } else if !excerptNeedsReloadAfterIndexedContentMutation {
            reloadExcerptListOverview()
        }
        playback.playbackViewModel?.showExcerptFeedback(.removed)

        let databaseURL = databaseURL
        let itemID = item.id
        excerptMutationTask?.cancel()
        excerptMutationTask = Task { @MainActor [weak self] in
            defer { self?.excerptMutationTask = nil }
            do {
                let (uniqueCueCount, recentSummaries) = try await Self.runCancellableDetached(priority: .userInitiated) {
                    let database = try ExcerptDatabase(path: databaseURL)
                    _ = try database.removeExcerpt(id: itemID)
                    return (try database.uniqueExcerptCueCount(), try database.recentExcerptListSummaries())
                }
                guard let self, !self.excerptNeedsReloadAfterIndexedContentMutation else { return }
                if let sourceListID {
                    _ = self.excerpt.adjustListCueCounts([sourceListID: 0], uniqueCueCount: uniqueCueCount)
                }
                self.excerpt.installRecentListSummaries(recentSummaries)
            } catch {
                print("Failed to remove Excerpt in background: \(error)")
                guard let self else { return }
                self.playback.playbackViewModel?.showExcerptFeedback(.unavailable)
                self.reloadExcerptListOverview()
                self.reloadExcerptTableRows()
            }
        }
        return true
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

        // Filter navigationScopeIDs to items that remain in the library
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
            Task { @MainActor in
                await Task.yield()
                _ = play(excerpt)
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
        guard let database = excerptDatabase else {
            return
        }
        if let relation = try? database.excerptRelation(id: item.id),
           let list = try? database.excerptList(id: relation.listID) {
            let existingSummary = excerpt.recentListSummaries.first(where: { $0.id == list.id })
                ?? excerpt.listOverview.lists.first(where: { $0.id == list.id })
            let cueCount = existingSummary?.cueCount ?? 1
            let playedList = ExcerptList(
                id: list.id,
                name: list.name,
                description: list.description,
                coverPath: list.coverPath,
                createdAt: list.createdAt,
                recentCueID: relation.cueID,
                recentSortOrder: "created_at_desc",
                recentPlayedAt: ISO8601DateFormatter().string(from: Date())
            )
            let resumePosition: Int = {
                if excerpt.residentListID == list.id {
                    let playableIDs = excerpt.residentRelations.compactMap { rel -> Int64? in
                        excerpt.residentExcerptsByID[rel.id]?.isValid == true ? rel.id : nil
                    }
                    if let idx = playableIDs.firstIndex(of: item.id) {
                        return idx + 1
                    }
                }
                if let relations = try? database.excerptRelations(listID: list.id),
                   let idx = relations.firstIndex(where: { $0.id == item.id }) {
                    return idx + 1
                }
                return existingSummary?.resumePosition ?? 1
            }()
            let newSummary = ExcerptListSummary(
                list: playedList,
                cueCount: cueCount,
                resumeExcerpt: item,
                resumePosition: resumePosition
            )
            var updated = excerpt.recentListSummaries.filter { $0.id != list.id }
            updated.insert(newSummary, at: 0)
            excerpt.installRecentListSummaries(updated)
        }
        let databaseURL = databaseURL
        let itemID = item.id
        Task { @MainActor [weak self] in
            do {
                let summaries = try await Self.runCancellableDetached(priority: .utility) {
                    let database = try ExcerptDatabase(path: databaseURL)
                    try database.recordRecentExcerptPlayback(excerptID: itemID)
                    return try database.recentExcerptListSummaries()
                }
                guard let self else { return }
                self.excerptListOverviewTask?.cancel()
                self.excerpt.installRecentListSummaries(summaries)
            } catch {
                print("Failed to record recent Excerpt playback: \(error)")
            }
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
                  !scopeIDs.isEmpty,
                  let index = (validatedPreferredOrdinal.flatMap { $0 < scopeIDs.count ? $0 : nil })
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
                previousID: index > 0 && index - 1 < scopeIDs.count ? scopeIDs[index - 1] : nil,
                nextID: index + 1 < scopeIDs.count
                    ? scopeIDs[index + 1]
                    : nil
            )
            return index
        }

        if let scopeIDs = excerptPlaybackNavigationScopeIDs,
           !scopeIDs.isEmpty,
           let index = (validatedPreferredOrdinal.flatMap { $0 < scopeIDs.count ? $0 : nil })
                ?? scopeIDs.firstIndex(of: selectedID) {
            excerptPlaybackNavigationSnapshot = (
                currentID: selectedID,
                previousID: index > 0 && index - 1 < scopeIDs.count ? scopeIDs[index - 1] : nil,
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
