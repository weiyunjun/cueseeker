import AppKit
import Foundation
import CueSeekerCore

enum ExcerptListPlaybackResolution {
    case resolved(target: Excerpt, navigationScopeIDs: [Int64], ordinal: Int)
    case fallback(target: Excerpt)
    case empty
}

@MainActor
extension ExcerptStore {
    // MARK: - List Overview & Playback Resolution

    func loadListOverviewIfNeeded() {
        guard !hasLoadedListOverview, listOverviewTask == nil else {
            return
        }
        reloadListOverview()
    }

    func reloadListOverview() {
        listOverviewTask?.cancel()
        guard let databaseURL else {
            if !hasLoadedListOverview {
                installListOverview(ExcerptListOverview(lists: [], uniqueCueCount: 0))
                installRecentListSummaries([])
            }
            return
        }
        listOverviewTask = Task { @MainActor [weak self] in
            guard let self else {
                return
            }
            defer {
                self.listOverviewTask = nil
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
                self.installListOverview(snapshot.0)
                self.installRecentListSummaries(snapshot.1)
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled else {
                    return
                }
                print("Failed to load Excerpt list overview: \(error)")
                if !self.hasLoadedListOverview {
                    self.installListOverview(
                        ExcerptListOverview(lists: [], uniqueCueCount: 0)
                    )
                    self.installRecentListSummaries([])
                }
            }
        }
    }

    func resolveListPlayback(
        _ summary: ExcerptListSummary,
        preferredExcerptID: Int64?
    ) -> ExcerptListPlaybackResolution? {
        guard let database else { return nil }
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
                    return .fallback(target: fallbackTarget)
                }
                return .empty
            }
            return .resolved(
                target: target,
                navigationScopeIDs: navigationScopeIDs,
                ordinal: ordinal
            )
        } catch {
            print("Failed to open Excerpt list playback: \(error)")
            return nil
        }
    }

    // MARK: - Excerpt List Editor Lifecycle, Validation, Cover Import & Saving

    func presentCreateExcerptListEditor(
        pendingTransfer: ExcerptListEditorPendingTransfer? = nil,
        isExcerptInLibrary: (Int64) -> Bool,
        onCueNotInLibrary: () -> Void
    ) {
        if let pendingTransfer, case .excerpt(let item) = pendingTransfer.target {
            guard item.isValid, isExcerptInLibrary(item.id) else {
                onCueNotInLibrary()
                return
            }
        }
        guard listEditorSession == nil else {
            return
        }
        listEditorSession = ExcerptListEditorSession(
            mode: .newList,
            pendingTransfer: pendingTransfer
        )
    }

    func presentEditExcerptListEditor(_ list: ExcerptList) {
        guard listEditorSession == nil else {
            return
        }
        listEditorSession = ExcerptListEditorSession(mode: .edit(list))
    }

    func closeExcerptListEditor() {
        guard listEditorSession?.isSaving != true else {
            return
        }
        listCoverImportTask?.cancel()
        listCoverImportTask = nil
        listEditorSession = nil
    }

    func validateExcerptListEditor(_ session: ExcerptListEditorSession) {
        guard listEditorSession?.id == session.id,
              let database
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
        guard listEditorSession?.id == session.id,
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
                  self.listEditorSession?.id == session.id
            else {
                return
            }
            self.importExcerptListEditorCover(from: sourceURL, for: session)
        }

        if let window = NSApplication.shared.keyWindow ?? NSApplication.shared.mainWindow {
            panel.beginSheetModal(for: window, completionHandler: completion)
        } else {
            completion(panel.runModal())
        }
    }

    func importExcerptListEditorCover(
        from sourceURL: URL,
        for session: ExcerptListEditorSession
    ) {
        listCoverImportTask?.cancel()
        listCoverImportTask = Task { @MainActor [weak self, weak session] in
            guard let self, let session else {
                return
            }
            do {
                let source = try await Task.detached(priority: .userInitiated) {
                    try LibraryUserCoverProcessor.loadSource(at: sourceURL)
                }.value
                try Task.checkCancellation()
                guard self.listEditorSession?.id == session.id else {
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

    func saveExcerptListEditor(
        _ session: ExcerptListEditorSession,
        onPendingTransfer: @escaping @MainActor (ExcerptListEditorPendingTransfer, Int64, String) -> Void
    ) {
        guard listEditorSession?.id == session.id,
              !session.isSaving,
              let database,
              let databaseURL
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
        listSaveTask?.cancel()
        listSaveTask = Task { @MainActor [weak self, weak session] in
            guard let self, let session else {
                return
            }
            var publishedCoverPath: String?
            do {
                if let source {
                    publishedCoverPath = try await self.coverStorage.publish(
                        source: source,
                        cropRect: cropRect
                    )
                }
                let coverPath = publishedCoverPath ?? oldCoverPath
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
                        try await self.coverStorage.remove(path: oldCoverPath)
                    } catch {
                        print("Failed to remove replaced Excerpt list cover: \(error)")
                    }
                }
                guard self.listEditorSession?.id == session.id else {
                    return
                }
                session.isSaving = false
                self.listEditorSession = nil
                if !self.upsertListSummary(savedList) {
                    self.reloadListOverview()
                }
                if let pendingTransfer = session.pendingTransfer {
                    onPendingTransfer(pendingTransfer, savedList.id, savedList.name)
                }
            } catch is CancellationError {
                if let publishedCoverPath {
                    try? await self.coverStorage.remove(path: publishedCoverPath)
                }
                if self.listEditorSession?.id == session.id {
                    session.isSaving = false
                }
            } catch {
                if let publishedCoverPath {
                    try? await self.coverStorage.remove(path: publishedCoverPath)
                }
                guard self.listEditorSession?.id == session.id else {
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
            self.listSaveTask = nil
        }
    }

    @discardableResult
    func deleteExcerptList(
        id: Int64,
        settings: SettingsStore
    ) -> Bool {
        guard database != nil, let databaseURL else {
            return false
        }
        settings.removeExcerptListSettings(forListID: id)
        if activeListID == id {
            let nextListID = listOverview.lists.first(where: { $0.id != id })?.id
            setActiveListID(nextListID)
            if let nextListID {
                updateTableFacetFilter(
                    settings.excerptFacetFilter(forListID: nextListID)
                )
                updateTableSortOrder(
                    settings.excerptSortOrder(forListID: nextListID)
                )
            } else {
                updateTableFacetFilter(CueFacetFilter())
                updateTableSortOrder(.earliestDateAdded)
            }
        }
        let currentUniqueCount = listOverview.uniqueCueCount
        let removedCueCount = listOverview.lists.first(where: { $0.id == id })?.cueCount ?? 0
        let estimatedUniqueCount = max(0, currentUniqueCount - removedCueCount)
        removeListSummary(id: id, uniqueCueCount: estimatedUniqueCount)

        listSaveTask?.cancel()
        listSaveTask = Task { @MainActor [weak self] in
            defer { self?.listSaveTask = nil }
            do {
                let (deleted, uniqueCueCount) = try await Self.runCancellableDetached(
                    priority: .userInitiated
                ) {
                    let db = try ExcerptDatabase(path: databaseURL)
                    let list = try db.deleteExcerptList(id: id)
                    let count = try db.uniqueExcerptCueCount()
                    return (list, count)
                }
                guard let self, !self.needsReloadAfterIndexedContentMutation else { return }
                self.removeListSummary(id: id, uniqueCueCount: uniqueCueCount)
                if let coverPath = deleted.coverPath {
                    do {
                        try await self.coverStorage.remove(path: coverPath)
                    } catch {
                        print("Failed to remove deleted Excerpt list cover: \(error)")
                    }
                }
            } catch {
                print("Failed to delete Excerpt list in background: \(error)")
                self?.reloadListOverview()
            }
        }
        return true
    }

    // MARK: - Table Row Hydration, Projection, Filter/Sort/Search & Reappearance

    func loadTableRowsIfNeeded(
        settings: SettingsStore,
        normalizeFacetFilter: @escaping @MainActor (CueFacetFilter) -> CueFacetFilter,
        onProjectionApplied: @escaping @MainActor () -> Void
    ) {
        guard tableRowsTask == nil else {
            return
        }
        let snapshot = tableRowStore.snapshot
        guard !tableHasLoadedInitialPage
                || snapshot.totalRowCount != tableResultRowCount
                || tableRowsNeedReload
        else {
            return
        }
        reloadTableRows(
            settings: settings,
            normalizeFacetFilter: normalizeFacetFilter,
            onProjectionApplied: onProjectionApplied
        )
    }

    func reloadTableRows(
        settings: SettingsStore,
        normalizeFacetFilter: @escaping @MainActor (CueFacetFilter) -> CueFacetFilter,
        onProjectionApplied: @escaping @MainActor () -> Void
    ) {
        guard let listID = activeListID
                ?? (try? database?.firstExcerptListID())
        else {
            clearTableRowsForReload()
            markTableRowsLoaded(totalSavedRowCount: 0)
            return
        }

        tableRowsTask?.cancel()
        let wasActiveListIDNil = activeListID == nil
        setActiveListID(listID)
        if wasActiveListIDNil {
            updateTableFacetFilter(
                settings.excerptFacetFilter(forListID: listID)
            )
            updateTableSortOrder(
                settings.excerptSortOrder(forListID: listID)
            )
        }

        let resultSnapshotID = tableResultSnapshotID
        let searchText = tableSearchDraft
        let facetFilter = tableFacetFilter
        let sortOrder = tableSortOrder
        let dataRevision = tableDataRevision
        if residentDataRevision == dataRevision,
           residentListID == listID {
            applyResidentExcerptTableProjection(
                resultSnapshotID: resultSnapshotID,
                searchText: searchText,
                facetFilter: facetFilter,
                sortOrder: sortOrder,
                listID: listID,
                dataRevision: dataRevision,
                normalizeFacetFilter: normalizeFacetFilter,
                onProjectionApplied: onProjectionApplied
            )
            ExcerptOpenPerformanceTracker.recordDataReady(
                listID: listID,
                count: residentRelations.count,
                cacheHit: true
            )
            return
        }

        guard let databaseURL else {
            markTableRowsLoaded(totalSavedRowCount: 0)
            return
        }

        tableRowsTask = Task { @MainActor [weak self] in
            guard let self else {
                return
            }
            defer {
                if self.tableResultSnapshotID == resultSnapshotID {
                    self.tableRowsTask = nil
                }
            }

            do {
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
                self.cueContentStore.install(residentSnapshot.cueContents)
                self.installResidentSnapshot(
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
                    dataRevision: dataRevision,
                    normalizeFacetFilter: normalizeFacetFilter,
                    onProjectionApplied: onProjectionApplied
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
                    self.markTableRowsLoaded(totalSavedRowCount: 0)
                }
            }
        }
    }

    func prepareForIndexedContentMutation(under folders: [URL]) {
        needsReloadAfterIndexedContentMutation = true
        pendingContentRemovalFolders.append(contentsOf: folders)
        playbackNavigationScopeIDs = nil
        playbackNavigationSnapshot = nil
    }

    func markReloadNeededAfterIndexedContentMutation() {
        needsReloadAfterIndexedContentMutation = true
    }

    func refreshOnReappearanceIfNeeded(
        settings: SettingsStore,
        normalizeFacetFilter: @escaping @MainActor (CueFacetFilter) -> CueFacetFilter,
        onProjectionApplied: @escaping @MainActor () -> Void,
        onRefreshRecentWatching: () -> Void
    ) {
        guard needsReloadAfterIndexedContentMutation else {
            return
        }
        needsReloadAfterIndexedContentMutation = false
        let folders = pendingContentRemovalFolders
        pendingContentRemovalFolders.removeAll()
        if !folders.isEmpty {
            cueContentStore.remove { content in
                folders.contains { folder in
                    AppCoordinator.path(content.subtitlePath, isUnder: folder)
                }
            }
        }
        markTableRowsStale()
        reloadListOverview()
        reloadTableRows(
            settings: settings,
            normalizeFacetFilter: normalizeFacetFilter,
            onProjectionApplied: onProjectionApplied
        )
        onRefreshRecentWatching()
    }

    func refreshForLibraryWatchStateChange(
        settings: SettingsStore,
        normalizeFacetFilter: @escaping @MainActor (CueFacetFilter) -> CueFacetFilter,
        onProjectionApplied: @escaping @MainActor () -> Void
    ) {
        guard residentDataRevision != nil else { return }
        markTableRowsStale()
        reloadTableRows(
            settings: settings,
            normalizeFacetFilter: normalizeFacetFilter,
            onProjectionApplied: onProjectionApplied
        )
    }

    func applyCompletedRename(
        _ steps: [LibraryRenameStep],
        normalizeFacetFilter: (CueFacetFilter) -> CueFacetFilter
    ) {
        let rewrittenFilter = normalizeFacetFilter(
            tableFacetFilter.rewritingFolderPaths(steps)
        )
        _ = updateTableFacetFilter(rewrittenFilter)
        let cachedCueIDs = cueContentStore.cachedCueIDs
        if let databaseURL,
           !cachedCueIDs.isEmpty,
           let updatedContents = try? CueContentDatabase(path: databaseURL)
               .cueContents(forCueIDs: cachedCueIDs),
           !updatedContents.isEmpty {
            cueContentStore.install(updatedContents)
        }
        applyRename(steps, cueContentStore: cueContentStore)
        if hasLoadedListOverview, let database {
            if let overview = try? database.excerptListOverview() {
                installListOverview(overview)
            }
            if let summaries = try? database.recentExcerptListSummaries() {
                installRecentListSummaries(summaries)
            }
        }
        reloadListOverview()
    }

    func updateFacetFilter(
        _ filter: CueFacetFilter,
        settings: SettingsStore,
        normalizeFacetFilter: @escaping @MainActor (CueFacetFilter) -> CueFacetFilter,
        onProjectionApplied: @escaping @MainActor () -> Void,
        onRefreshRecentWatching: () -> Void
    ) {
        guard updateTableFacetFilter(filter),
              let listID = activeListID
        else {
            return
        }
        settings.setExcerptFacetFilter(filter, forListID: listID)
        if needsReloadAfterIndexedContentMutation {
            refreshOnReappearanceIfNeeded(
                settings: settings,
                normalizeFacetFilter: normalizeFacetFilter,
                onProjectionApplied: onProjectionApplied,
                onRefreshRecentWatching: onRefreshRecentWatching
            )
            return
        }
        let dataRevision = tableDataRevision
        guard residentDataRevision == dataRevision,
              residentListID == listID
        else {
            reloadTableRows(
                settings: settings,
                normalizeFacetFilter: normalizeFacetFilter,
                onProjectionApplied: onProjectionApplied
            )
            return
        }

        beginTableResultProjection()
        applyResidentExcerptTableProjection(
            resultSnapshotID: tableResultSnapshotID,
            searchText: tableSearchDraft,
            facetFilter: filter,
            sortOrder: tableSortOrder,
            listID: listID,
            dataRevision: dataRevision,
            normalizeFacetFilter: normalizeFacetFilter,
            onProjectionApplied: onProjectionApplied
        )
    }

    func updateSortOrder(
        _ sortOrder: ExcerptSortOrder,
        settings: SettingsStore,
        normalizeFacetFilter: @escaping @MainActor (CueFacetFilter) -> CueFacetFilter,
        onProjectionApplied: @escaping @MainActor () -> Void,
        onRefreshRecentWatching: () -> Void
    ) {
        guard updateTableSortOrder(sortOrder),
              let listID = activeListID
        else {
            return
        }
        settings.setExcerptSortOrder(sortOrder, forListID: listID)
        if needsReloadAfterIndexedContentMutation {
            refreshOnReappearanceIfNeeded(
                settings: settings,
                normalizeFacetFilter: normalizeFacetFilter,
                onProjectionApplied: onProjectionApplied,
                onRefreshRecentWatching: onRefreshRecentWatching
            )
            return
        }
        let dataRevision = tableDataRevision
        guard residentDataRevision == dataRevision,
              residentListID == listID
        else {
            reloadTableRows(
                settings: settings,
                normalizeFacetFilter: normalizeFacetFilter,
                onProjectionApplied: onProjectionApplied
            )
            return
        }

        beginTableResultProjection()
        applyResidentExcerptTableProjection(
            resultSnapshotID: tableResultSnapshotID,
            searchText: tableSearchDraft,
            facetFilter: tableFacetFilter,
            sortOrder: sortOrder,
            listID: listID,
            dataRevision: dataRevision,
            normalizeFacetFilter: normalizeFacetFilter,
            onProjectionApplied: onProjectionApplied
        )
    }

    func updateSearchQuery(
        _ searchText: String,
        settings: SettingsStore,
        normalizeFacetFilter: @escaping @MainActor (CueFacetFilter) -> CueFacetFilter,
        onProjectionApplied: @escaping @MainActor () -> Void,
        onRefreshRecentWatching: () -> Void
    ) {
        guard updateTableSearchDraft(searchText) else {
            return
        }
        let normalizedSearchText = tableSearchDraft
        UIInvalidationProbe.mark(
            "ACTION UI.ExcerptSearchQuery.changed",
            scope: uiProbeScope,
            details: "length=\(normalizedSearchText.count)"
        )
        if needsReloadAfterIndexedContentMutation {
            refreshOnReappearanceIfNeeded(
                settings: settings,
                normalizeFacetFilter: normalizeFacetFilter,
                onProjectionApplied: onProjectionApplied,
                onRefreshRecentWatching: onRefreshRecentWatching
            )
            return
        }
        guard let listID = activeListID else {
            reloadTableRows(
                settings: settings,
                normalizeFacetFilter: normalizeFacetFilter,
                onProjectionApplied: onProjectionApplied
            )
            return
        }
        let dataRevision = tableDataRevision
        guard residentDataRevision == dataRevision,
              residentListID == listID
        else {
            reloadTableRows(
                settings: settings,
                normalizeFacetFilter: normalizeFacetFilter,
                onProjectionApplied: onProjectionApplied
            )
            return
        }

        beginTableResultProjection()
        applyResidentExcerptTableProjection(
            resultSnapshotID: tableResultSnapshotID,
            searchText: normalizedSearchText,
            facetFilter: tableFacetFilter,
            sortOrder: tableSortOrder,
            listID: listID,
            dataRevision: dataRevision,
            normalizeFacetFilter: normalizeFacetFilter,
            onProjectionApplied: onProjectionApplied
        )
    }

    /// The Excerpt table's rows for a search text and a selection, with the
    /// counts by the usual rule. The table installs them; the Filter dialog
    /// reads them for a selection it has not handed to the table yet.
    func residentExcerptTableProjection(
        searchText: String,
        facetFilter: CueFacetFilter,
        sortOrder: ExcerptSortOrder? = nil,
        normalizeFacetFilter: (CueFacetFilter) -> CueFacetFilter = { $0 }
    ) -> (relations: [ExcerptRelation], distribution: CueFacetDistribution) {
        let trimmedSearchText = searchText.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        let normalizedFilter = normalizeFacetFilter(facetFilter)
        let facetProjection = residentFacetProjection(
            using: normalizedFilter
        )
        let matchingExcerptIDs = Set(facetProjection.excerptIDs)
        var validSearchMatchingCueIDs = Set<Int64>()
        let relations = residentRelations.filter { relation in
            let content = cueContentStore.content(for: relation.cueID)
            guard let resolved = residentExcerptsByID[relation.id] else {
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
        let resolvedSortOrder = sortOrder ?? tableSortOrder
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
                cueContentStore.content(for: relation.cueID)?.characterWidth
                    ?? residentExcerptsByID[relation.id]?.characterWidth
                    ?? 0
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
        let validFacetSnapshot = residentFacetSnapshot?.keeping(
            cueIDs: validSearchMatchingCueIDs
        ) ?? .empty
        let validDistribution = validFacetSnapshot.filteredCueIDs(
            using: normalizedFilter,
            limit: validFacetSnapshot.cueIDs.count
        ).distribution
        return (sortedRelations, validDistribution)
    }

    func applyResidentExcerptTableProjection(
        resultSnapshotID: UUID,
        searchText: String,
        facetFilter: CueFacetFilter,
        sortOrder: ExcerptSortOrder,
        listID: Int64,
        dataRevision: Int,
        normalizeFacetFilter: (CueFacetFilter) -> CueFacetFilter,
        onProjectionApplied: () -> Void
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
            sortOrder: sortOrder,
            normalizeFacetFilter: normalizeFacetFilter
        ).relations
        installTableResultExcerptIDs(relations.map(\.id))
        markTableRowsLoaded(
            totalSavedRowCount: residentRelations.count
        )
        tableRowStore.updateResidentExcerptRelations(
            relations,
            resolvedExcerptsByID: residentExcerptsByID,
            cueContentProvider: { [cueContentStore] cueID in
                cueContentStore.content(for: cueID)
            },
            cueContentRevision: cueContentStore.revision,
            tableName: "excerpt",
            probeSurface: .excerpt,
            probeScope: uiProbeScope
        )
        onProjectionApplied()
    }

    func excerptTableRequestMatches(
        resultSnapshotID: UUID,
        searchText: String,
        facetFilter: CueFacetFilter,
        sortOrder: ExcerptSortOrder,
        listID: Int64,
        dataRevision: Int
    ) -> Bool {
        !Task.isCancelled
            && tableResultSnapshotID == resultSnapshotID
            && tableSearchDraft == searchText
            && tableFacetFilter == facetFilter
            && tableSortOrder == sortOrder
            && activeListID == listID
            && tableDataRevision == dataRevision
    }

    // MARK: - Excerpt CRUD Mutations & Optimistic Recent Playback Updates

    @discardableResult
    func saveExcerpt(
        cueID: Int64,
        toListID destinationListID: Int64,
        listName: String,
        isCueInLibrary: (Int64) -> Bool,
        onCueNotInLibrary: () -> Void,
        onReportToast: @escaping @MainActor (ToastRequest) -> Void
    ) -> Bool {
        if !isCueInLibrary(cueID) {
            onCueNotInLibrary()
            return false
        }
        guard let database, let databaseURL else {
            onReportToast(ExcerptToastRequest.saveFailed(listName: listName))
            return false
        }
        let destination: ExcerptList
        do {
            guard let availableDestination = try database.excerptList(
                id: destinationListID
            ) else {
                onReportToast(
                    ExcerptToastRequest.destinationUnavailable(
                        listName: listName
                    )
                )
                return false
            }
            destination = availableDestination
        } catch {
            print("Failed to resolve Excerpt save destination: \(error)")
            onReportToast(ExcerptToastRequest.saveFailed(listName: listName))
            return false
        }

        do {
            guard try database.excerpt(
                cueID: cueID,
                listID: destinationListID
            ) == nil else {
                onReportToast(
                    ExcerptToastRequest.destinationAlreadyContainsCue(
                        listName: destination.name
                    )
                )
                return false
            }
            markTableRowsStale()
            if !adjustListCueCounts(
                [destinationListID: 1],
                addedCueIDsByListID: [destinationListID: [cueID]]
            ) {
                reloadListOverview()
            }
            setRecentSaveListID(destinationListID)
            onReportToast(
                ExcerptToastRequest.saveSucceeded(listName: destination.name)
            )

            mutationTask?.cancel()
            mutationTask = Task { @MainActor [weak self] in
                defer { self?.mutationTask = nil }
                do {
                    let (uniqueCueCount, recentSummaries) = try await Self.runCancellableDetached(priority: .userInitiated) {
                        let db = try ExcerptDatabase(path: databaseURL)
                        _ = try db.upsertExcerpt(cueID: cueID, listID: destinationListID)
                        return (try db.uniqueExcerptCueCount(), try db.recentExcerptListSummaries())
                    }
                    guard let self, !self.needsReloadAfterIndexedContentMutation else { return }
                    _ = self.adjustListCueCounts([destinationListID: 0], uniqueCueCount: uniqueCueCount)
                    self.installRecentListSummaries(recentSummaries)
                } catch {
                    print("Failed to save Excerpt in background: \(error)")
                    guard let self else { return }
                    onReportToast(
                        ExcerptToastRequest.saveFailed(listName: destination.name)
                    )
                    self.reloadListOverview()
                }
            }
            return true
        } catch {
            print("Failed to save Excerpt: \(error)")
            onReportToast(
                ExcerptToastRequest.saveFailed(listName: destination.name)
            )
        }
        return false
    }

    @discardableResult
    func moveExcerpt(
        _ item: Excerpt,
        toListID destinationListID: Int64,
        listName: String,
        isExcerptInLibrary: (Int64) -> Bool,
        onToast: @escaping @MainActor (ToastRequest) -> Void,
        onItemRemovedFromCurrentList: (Excerpt) -> Void,
        onReloadTableRows: @escaping @MainActor () -> Void
    ) -> Bool {
        guard item.isValid, isExcerptInLibrary(item.id) else {
            onToast(TableToastRequest.cueNotInLibrary)
            return false
        }
        guard let database, let databaseURL else {
            onToast(ExcerptToastRequest.moveFailed)
            return false
        }
        let destination: ExcerptList
        do {
            guard let availableDestination = try database.excerptList(
                id: destinationListID
            ) else {
                onToast(
                    ExcerptToastRequest.destinationUnavailable(
                        listName: listName
                    )
                )
                return false
            }
            destination = availableDestination
        } catch {
            print("Failed to resolve Excerpt move destination: \(error)")
            onToast(ExcerptToastRequest.moveFailed)
            return false
        }

        let relation = residentRelations.first(where: { $0.id == item.id })
            ?? (try? database.excerptRelation(id: item.id))
        if let relation,
           let exists = try? database.excerptRelationExists(cueID: relation.cueID, listID: destinationListID),
           exists {
            onToast(
                ExcerptToastRequest.destinationAlreadyContainsCue(
                    listName: destination.name
                )
            )
            return false
        }

        let sourceListID = activeListID
        onItemRemovedFromCurrentList(item)
        let didUpdateOverview = sourceListID.map { sourceID in
            let cueIDSet: Set<Int64> = relation.map { [$0.cueID] } ?? []
            return adjustListCueCounts(
                [
                    sourceID: -1,
                    destinationListID: 1,
                ],
                addedCueIDsByListID: cueIDSet.isEmpty ? [:] : [destinationListID: cueIDSet],
                removedCueIDsByListID: cueIDSet.isEmpty ? [:] : [sourceID: cueIDSet]
            )
        } ?? false
        if !didUpdateOverview {
            reloadListOverview()
        }
        onToast(ExcerptToastRequest.moveSucceeded(listName: destination.name))

        let itemID = item.id
        let destinationName = destination.name
        mutationTask?.cancel()
        mutationTask = Task { @MainActor [weak self] in
            defer { self?.mutationTask = nil }
            do {
                let recentSummaries = try await Self.runCancellableDetached(priority: .userInitiated) {
                    let db = try ExcerptDatabase(path: databaseURL)
                    _ = try db.moveExcerpt(id: itemID, toListID: destinationListID)
                    return try db.recentExcerptListSummaries()
                }
                guard let self, !self.needsReloadAfterIndexedContentMutation else { return }
                self.installRecentListSummaries(recentSummaries)
            } catch ExcerptTransferError.destinationUnavailable {
                onToast(ExcerptToastRequest.destinationUnavailable(listName: destinationName))
                self?.reloadListOverview()
                onReloadTableRows()
            } catch ExcerptTransferError.destinationAlreadyContainsCue {
                onToast(ExcerptToastRequest.destinationAlreadyContainsCue(listName: destinationName))
                self?.reloadListOverview()
                onReloadTableRows()
            } catch {
                print("Failed to move Excerpt in background: \(error)")
                onToast(ExcerptToastRequest.moveFailed)
                self?.reloadListOverview()
                onReloadTableRows()
            }
        }
        return true
    }

    @discardableResult
    func duplicateExcerpt(
        _ item: Excerpt,
        toListID destinationListID: Int64,
        listName: String,
        isExcerptInLibrary: (Int64) -> Bool,
        onToast: @escaping @MainActor (ToastRequest) -> Void
    ) -> Bool {
        guard item.isValid, isExcerptInLibrary(item.id) else {
            onToast(TableToastRequest.cueNotInLibrary)
            return false
        }
        guard let database, let databaseURL else {
            onToast(ExcerptToastRequest.duplicateFailed)
            return false
        }
        let destination: ExcerptList
        do {
            guard let availableDestination = try database.excerptList(
                id: destinationListID
            ) else {
                onToast(
                    ExcerptToastRequest.destinationUnavailable(
                        listName: listName
                    )
                )
                return false
            }
            destination = availableDestination
        } catch {
            print("Failed to resolve Excerpt duplicate destination: \(error)")
            onToast(ExcerptToastRequest.duplicateFailed)
            return false
        }

        let relation = residentRelations.first(where: { $0.id == item.id })
            ?? (try? database.excerptRelation(id: item.id))
        if let relation,
           let exists = try? database.excerptRelationExists(cueID: relation.cueID, listID: destinationListID),
           exists {
            onToast(
                ExcerptToastRequest.destinationAlreadyContainsCue(
                    listName: destination.name
                )
            )
            return false
        }

        let addedCueIDs: [Int64: Set<Int64>] = relation.map { [destinationListID: [$0.cueID]] } ?? [:]
        if !adjustListCueCounts(
            [destinationListID: 1],
            addedCueIDsByListID: addedCueIDs
        ) {
            reloadListOverview()
        }
        onToast(ExcerptToastRequest.duplicateSucceeded(listName: destination.name))

        let itemID = item.id
        let destinationName = destination.name
        mutationTask?.cancel()
        mutationTask = Task { @MainActor [weak self] in
            defer { self?.mutationTask = nil }
            do {
                let recentSummaries = try await Self.runCancellableDetached(priority: .userInitiated) {
                    let db = try ExcerptDatabase(path: databaseURL)
                    _ = try db.duplicateExcerpt(id: itemID, toListID: destinationListID)
                    return try db.recentExcerptListSummaries()
                }
                guard let self, !self.needsReloadAfterIndexedContentMutation else { return }
                self.installRecentListSummaries(recentSummaries)
            } catch ExcerptTransferError.destinationUnavailable {
                onToast(ExcerptToastRequest.destinationUnavailable(listName: destinationName))
                self?.reloadListOverview()
            } catch ExcerptTransferError.destinationAlreadyContainsCue {
                onToast(ExcerptToastRequest.destinationAlreadyContainsCue(listName: destinationName))
                self?.reloadListOverview()
            } catch {
                print("Failed to duplicate Excerpt in background: \(error)")
                onToast(ExcerptToastRequest.duplicateFailed)
                self?.reloadListOverview()
            }
        }
        return true
    }

    @discardableResult
    func removeExcerpt(
        _ item: Excerpt,
        reloadPresentation: Bool = true,
        onFeedback: @escaping @MainActor (ExcerptFeedbackState) -> Void,
        onItemRemovedFromCurrentList: (Excerpt) -> Void,
        onReloadTableRows: @escaping @MainActor () -> Void
    ) -> Bool {
        guard database != nil, let databaseURL else {
            onFeedback(.unavailable)
            return false
        }

        _ = reloadPresentation
        let sourceListID = activeListID
        let removedCueID = residentRelations.first(where: { $0.id == item.id })?.cueID
            ?? (try? database?.excerptRelation(id: item.id))?.cueID
        let cueCountDelta = item.isValid ? -1 : 0
        onItemRemovedFromCurrentList(item)
        if let sourceListID {
            let removedCueIDs: [Int64: Set<Int64>] = (item.isValid && removedCueID != nil)
                ? [sourceListID: [removedCueID!]]
                : [:]
            _ = adjustListCueCounts(
                [sourceListID: cueCountDelta],
                removedCueIDsByListID: removedCueIDs
            )
        } else if !needsReloadAfterIndexedContentMutation {
            reloadListOverview()
        }
        onFeedback(.removed)

        let itemID = item.id
        mutationTask?.cancel()
        mutationTask = Task { @MainActor [weak self] in
            defer { self?.mutationTask = nil }
            do {
                let (uniqueCueCount, recentSummaries) = try await Self.runCancellableDetached(priority: .userInitiated) {
                    let database = try ExcerptDatabase(path: databaseURL)
                    _ = try database.removeExcerpt(id: itemID)
                    return (try database.uniqueExcerptCueCount(), try database.recentExcerptListSummaries())
                }
                guard let self, !self.needsReloadAfterIndexedContentMutation else { return }
                if let sourceListID {
                    _ = self.adjustListCueCounts([sourceListID: 0], uniqueCueCount: uniqueCueCount)
                }
                self.installRecentListSummaries(recentSummaries)
            } catch {
                print("Failed to remove Excerpt in background: \(error)")
                guard let self else { return }
                onFeedback(.unavailable)
                self.reloadListOverview()
                onReloadTableRows()
            }
        }
        return true
    }

    func recordRecentExcerptPlayback(for item: Excerpt) {
        guard let database, let databaseURL else {
            return
        }
        if let relation = try? database.excerptRelation(id: item.id),
           let list = try? database.excerptList(id: relation.listID) {
            let existingSummary = recentListSummaries.first(where: { $0.id == list.id })
                ?? listOverview.lists.first(where: { $0.id == list.id })
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
                if residentListID == list.id {
                    let playableIDs = residentRelations.compactMap { rel -> Int64? in
                        residentExcerptsByID[rel.id]?.isValid == true ? rel.id : nil
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
            var updated = recentListSummaries.filter { $0.id != list.id }
            updated.insert(newSummary, at: 0)
            installRecentListSummaries(updated)
        }
        let itemID = item.id
        Task { @MainActor [weak self] in
            do {
                let summaries = try await Self.runCancellableDetached(priority: .utility) {
                    let database = try ExcerptDatabase(path: databaseURL)
                    try database.recordRecentExcerptPlayback(excerptID: itemID)
                    return try database.recentExcerptListSummaries()
                }
                guard let self else { return }
                self.listOverviewTask?.cancel()
                self.installRecentListSummaries(summaries)
            } catch {
                print("Failed to record recent Excerpt playback: \(error)")
            }
        }
    }

    func excerpt(withID id: Int64) -> Excerpt? {
        if let entryID = Int(exactly: id),
           let tableItem = tableRowStore.snapshot.excerpt(entryID: entryID) {
            return tableItem
        }
        if let relation = residentRelations.first(where: { $0.id == id }),
           let content = cueContentStore.content(for: relation.cueID) {
            return Excerpt(relation: relation, cueContent: content)
        }
        guard let database, let databaseURL else {
            return nil
        }

        do {
            guard let relation = try database.excerptRelation(id: id),
                  let content = try CueContentDatabase(path: databaseURL).cueContents(
                    forCueIDs: [relation.cueID]
                  ).first
            else {
                return nil
            }
            cueContentStore.install([content])
            return Excerpt(relation: relation, cueContent: content)
        } catch {
            print("Failed to load scoped Excerpt: \(error)")
            return nil
        }
    }

    // MARK: - Playback Navigation Scope & Snapshot

    func refreshPlaybackNavigationSnapshot(
        for selectedExcerpt: Excerpt,
        preferredOrdinal: Int? = nil,
        playlistSource: PlaybackPlaylistSource?
    ) -> Int? {
        let selectedID = selectedExcerpt.id
        let validatedPreferredOrdinal: Int?
        if let preferredOrdinal,
           playlistSource?.itemIdentity(at: preferredOrdinal)
            == .excerpt(selectedID) {
            validatedPreferredOrdinal = preferredOrdinal
        } else {
            validatedPreferredOrdinal = nil
        }

        if let source = playlistSource,
           case .excerpt(.table) = source.origin {
            let scopeIDs = playbackNavigationScopeIDs
                ?? playbackTableResultExcerptIDs
            guard let scopeIDs,
                  !scopeIDs.isEmpty,
                  let index = (validatedPreferredOrdinal.flatMap { $0 < scopeIDs.count ? $0 : nil })
                    ?? scopeIDs.firstIndex(of: selectedID)
            else {
                playbackNavigationSnapshot = (
                    currentID: selectedID,
                    previousID: nil,
                    nextID: nil
                )
                return nil
            }
            playbackNavigationSnapshot = (
                currentID: selectedID,
                previousID: index > 0 && index - 1 < scopeIDs.count ? scopeIDs[index - 1] : nil,
                nextID: index + 1 < scopeIDs.count
                    ? scopeIDs[index + 1]
                    : nil
            )
            return index
        }

        if let scopeIDs = playbackNavigationScopeIDs,
           !scopeIDs.isEmpty,
           let index = (validatedPreferredOrdinal.flatMap { $0 < scopeIDs.count ? $0 : nil })
                ?? scopeIDs.firstIndex(of: selectedID) {
            playbackNavigationSnapshot = (
                currentID: selectedID,
                previousID: index > 0 && index - 1 < scopeIDs.count ? scopeIDs[index - 1] : nil,
                nextID: index + 1 < scopeIDs.count ? scopeIDs[index + 1] : nil
            )
            return index
        }

        let residentRelations = self.residentRelations.filter {
            residentExcerptsByID[$0.id]?.isValid == true
        }
        let residentOrdinal = validatedPreferredOrdinal
            ?? residentRelations.firstIndex(where: { $0.id == selectedID })

        if let index = residentOrdinal {
            playbackNavigationSnapshot = (
                currentID: selectedID,
                previousID: index > 0 ? residentRelations[index - 1].id : nil,
                nextID: index + 1 < residentRelations.count
                    ? residentRelations[index + 1].id
                    : nil
            )
            return index
        }

        if let database {
            do {
                playbackNavigationSnapshot = (
                    currentID: selectedID,
                    previousID: try database.adjacentExcerpt(to: selectedExcerpt, direction: .previous)?.id,
                    nextID: try database.adjacentExcerpt(to: selectedExcerpt, direction: .next)?.id
                )
                return nil
            } catch {
                print("Failed to load adjacent Excerpt: \(error)")
            }
        }

        playbackNavigationSnapshot = (
            currentID: selectedID,
            previousID: nil,
            nextID: nil
        )
        return nil
    }

    func removeExcerptFromPlaybackNavigationScope(_ id: Int64) {
        guard var scopeIDs = playbackNavigationScopeIDs else {
            return
        }
        scopeIDs.removeAll { $0 == id }
        playbackNavigationScopeIDs = scopeIDs.isEmpty ? nil : scopeIDs
    }

    nonisolated private static func runCancellableDetached<T: Sendable>(
        priority: TaskPriority,
        operation: @Sendable @escaping () throws -> T
    ) async throws -> T {
        let task = Task.detached(priority: priority, operation: operation)
        return try await withTaskCancellationHandler {
            try await task.value
        } onCancel: {
            task.cancel()
        }
    }
}

