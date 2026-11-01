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
                AppLogger.shared.error(
                    .database,
                    "Failed to load Excerpt list overview",
                    fields: [("error", error.localizedDescription)]
                )
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
            AppLogger.shared.error(
                .database,
                "Failed to open Excerpt list playback",
                fields: [("list_id", "\(summary.list.id)"), ("error", error.localizedDescription)]
            )
            return nil
        }
    }

    // MARK: - Excerpt List Editor Lifecycle, Validation, Cover Import & Saving

    func presentCreateExcerptListEditor(
        pendingTransfer: ExcerptListEditorPendingTransfer? = nil,
        isExcerptInLibrary: (Int64) -> Bool,
        validExcerptIDsInLibrary: ([Int64]) -> Set<Int64> = { _ in [] },
        validCueIDsInLibrary: ([Int64]) -> Set<Int64> = { _ in [] },
        onCueNotInLibrary: (Int) -> Void
    ) {
        if let pendingTransfer {
            switch pendingTransfer.target {
            case .excerpt(let item):
                guard item.isValid, isExcerptInLibrary(item.id) else {
                    onCueNotInLibrary(1)
                    return
                }
            case .excerpts(let items):
                let validIDs = validExcerptIDsInLibrary(items.map(\.id))
                guard items.contains(where: { $0.isValid && validIDs.contains($0.id) }) else {
                    onCueNotInLibrary(max(1, items.count))
                    return
                }
            case .cue:
                break
            case .cues(let cueIDs):
                let validIDs = validCueIDsInLibrary(cueIDs)
                guard !validIDs.isEmpty else {
                    onCueNotInLibrary(max(1, cueIDs.count))
                    return
                }
            }
        }
        guard listEditorSession == nil else {
            return
        }
        let startedAt = DebugInteractionLatencyProbe.now()
        listEditorSession = ExcerptListEditorSession(
            mode: .newList,
            pendingTransfer: pendingTransfer
        )
        DebugInteractionLatencyProbe.beginDialogOpen(
            dialogID: "excerpt_list_editor_new",
            trigger: "create_excerpt_list",
            startedAt: startedAt,
            syncPrepFinishedAt: DebugInteractionLatencyProbe.now()
        )
    }

    func presentEditExcerptListEditor(_ list: ExcerptList) {
        let startedAt = DebugInteractionLatencyProbe.now()
        guard listEditorSession == nil else {
            return
        }
        listEditorSession = ExcerptListEditorSession(mode: .edit(list))
        DebugInteractionLatencyProbe.beginDialogOpen(
            dialogID: "excerpt_list_editor_edit",
            trigger: "edit_excerpt_list",
            startedAt: startedAt,
            syncPrepFinishedAt: DebugInteractionLatencyProbe.now()
        )
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
            AppLogger.shared.warn(
                .database,
                "Failed to validate Excerpt list",
                fields: [("error", error.localizedDescription)]
            )
        }
    }

    func beginChoosingExcerptListCover(_ session: ExcerptListEditorSession) {
        let startedAt = DebugInteractionLatencyProbe.now()
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
        let panelPresentedAt = DebugInteractionLatencyProbe.now()

        let completion: (NSApplication.ModalResponse) -> Void = {
            [weak self, weak session, delegate] response in
            _ = delegate
            DebugInteractionLatencyProbe.recordSystemFilePanel(
                panelType: "NSOpenPanel",
                trigger: "excerpt_list_choose_cover",
                mode: "sheet_or_modal",
                startedAt: startedAt,
                panelPresentedAt: panelPresentedAt,
                didSelect: response == .OK
            )
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
        let startedAt = DebugInteractionLatencyProbe.now()
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
                let asyncLoadFinishedAt = DebugInteractionLatencyProbe.now()
                session.selectCoverSource(source)
                DebugInteractionLatencyProbe.recordDialogInternalTransition(
                    dialogID: "excerpt_list_editor",
                    transition: "enter_crop_editor",
                    trigger: "choose_image",
                    startedAt: startedAt,
                    syncPrepFinishedAt: startedAt,
                    asyncLoadFinishedAt: asyncLoadFinishedAt
                )
            } catch is CancellationError {
                return
            } catch {
                AppLogger.shared.error(
                    .database,
                    "Failed to load Excerpt list cover",
                    fields: [("file", sourceURL.lastPathComponent), ("error", error.localizedDescription)]
                )
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
                        AppLogger.shared.warn(
                            .database,
                            "Failed to remove replaced Excerpt list cover",
                            fields: [("error", error.localizedDescription)]
                        )
                    }
                }
                guard self.listEditorSession?.id == session.id else {
                    return
                }
                session.isSaving = false
                self.listEditorSession = nil
                switch mode {
                case .newList:
                    AppLogger.shared.info(
                        .excerpt,
                        "Excerpt list created",
                        fields: [
                            ("list_id", "\(savedList.id)"),
                            ("name", savedList.name),
                            ("has_cover", "\(savedList.coverPath != nil)")
                        ]
                    )
                case .edit:
                    AppLogger.shared.info(
                        .excerpt,
                        "Excerpt list updated",
                        fields: [
                            ("list_id", "\(savedList.id)"),
                            ("name", savedList.name),
                            ("has_cover", "\(savedList.coverPath != nil)")
                        ]
                    )
                }
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
                        AppLogger.shared.warn(
                            .database,
                            "Failed to revalidate Excerpt list",
                            fields: [("error", "\(validationError)")]
                        )
                    }
                } else {
                    AppLogger.shared.error(
                        .database,
                        "Failed to save Excerpt list",
                        fields: [("error", error.localizedDescription)]
                    )
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
        let deletedSummary = listOverview.lists.first(where: { $0.id == id })
        let removedCueCount = deletedSummary?.cueCount ?? 0
        let estimatedUniqueCount = max(0, currentUniqueCount - removedCueCount)
        removeListSummary(id: id, uniqueCueCount: estimatedUniqueCount)
        AppLogger.shared.info(
            .excerpt,
            "Excerpt list deleted",
            fields: [
                ("list_id", "\(id)"),
                ("name", deletedSummary?.list.name),
                ("cues", "\(removedCueCount)")
            ]
        )

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
                        AppLogger.shared.warn(
                            .database,
                            "Failed to remove deleted Excerpt list cover",
                            fields: [("error", error.localizedDescription)]
                        )
                    }
                }
            } catch {
                AppLogger.shared.error(
                    .database,
                    "Failed to delete Excerpt list in background",
                    fields: [("list_id", "\(id)"), ("error", error.localizedDescription)]
                )
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
                AppLogger.shared.error(
                    .database,
                    "Failed to load resident Excerpt data",
                    fields: [("list_id", "\(listID)"), ("error", error.localizedDescription)]
                )
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
        AppLogger.shared.info(
            .excerpt,
            "Excerpt filter updated",
            fields: [
                ("list_id", "\(listID)"),
                ("filtered", "\(!filter.isEmpty)")
            ]
        )
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
        AppLogger.shared.info(
            .excerpt,
            "Excerpt sort order updated",
            fields: [
                ("list_id", "\(listID)"),
                ("sort", sortOrder.rawValue)
            ]
        )
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
        let trimmedSearchText = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedSearchText.isEmpty {
            AppLogger.shared.info(
                .excerpt,
                "Excerpt search applied",
                fields: [
                    ("list_id", "\(listID)"),
                    ("query", trimmedSearchText),
                    ("results", "\(relations.count)"),
                    ("total", "\(residentRelations.count)")
                ]
            )
        }
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
            AppLogger.shared.error(
                .database,
                "Failed to resolve Excerpt save destination",
                fields: [("list_id", "\(destinationListID)"), ("error", error.localizedDescription)]
            )
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
            AppLogger.shared.info(
                .excerpt,
                "Excerpt saved to list",
                fields: [
                    ("cue_id", "\(cueID)"),
                    ("list_id", "\(destinationListID)"),
                    ("list", destination.name)
                ]
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
                    AppLogger.shared.error(
                        .database,
                        "Failed to save Excerpt in background",
                        fields: [("cue_id", "\(cueID)"), ("list_id", "\(destinationListID)"), ("error", error.localizedDescription)]
                    )
                    guard let self else { return }
                    onReportToast(
                        ExcerptToastRequest.saveFailed(listName: destination.name)
                    )
                    self.reloadListOverview()
                }
            }
            return true
        } catch {
            AppLogger.shared.error(
                .database,
                "Failed to save Excerpt",
                fields: [("cue_id", "\(cueID)"), ("list_id", "\(destinationListID)"), ("error", error.localizedDescription)]
            )
            onReportToast(
                ExcerptToastRequest.saveFailed(listName: destination.name)
            )
        }
        return false
    }

    @discardableResult
    func saveExcerpts(
        cueIDs: [Int64],
        toListID destinationListID: Int64,
        listName: String,
        validCueIDsInLibrary: ([Int64]) -> Set<Int64>,
        onCueNotInLibrary: (Int) -> Void,
        onReportToast: @escaping @MainActor (ToastRequest) -> Void
    ) -> Bool {
        let inLibrarySet = validCueIDsInLibrary(cueIDs)
        var seenCueIDs = Set<Int64>()
        let validCueIDs = cueIDs.filter {
            inLibrarySet.contains($0) && seenCueIDs.insert($0).inserted
        }
        guard !validCueIDs.isEmpty else {
            onCueNotInLibrary(max(1, cueIDs.count))
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
            AppLogger.shared.error(
                .database,
                "Failed to resolve Excerpt batch save destination",
                fields: [("list_id", "\(destinationListID)"), ("error", error.localizedDescription)]
            )
            onReportToast(ExcerptToastRequest.saveFailed(listName: listName))
            return false
        }

        do {
            let existingSet = try database.existingCueIDs(
                inListID: destinationListID,
                among: validCueIDs
            )
            let insertedCueIDs = validCueIDs.filter { !existingSet.contains($0) }
            guard !insertedCueIDs.isEmpty else {
                onReportToast(
                    ExcerptToastRequest.destinationAlreadyContainsCue(
                        listName: destination.name
                    )
                )
                return false
            }
            markTableRowsStale()
            if !adjustListCueCounts(
                [destinationListID: insertedCueIDs.count],
                addedCueIDsByListID: [destinationListID: Set(insertedCueIDs)]
            ) {
                reloadListOverview()
            }
            setRecentSaveListID(destinationListID)
            onReportToast(
                ExcerptToastRequest.saveSucceeded(listName: destination.name)
            )
            AppLogger.shared.info(
                .excerpt,
                "Excerpts saved to list",
                fields: [
                    ("count", "\(insertedCueIDs.count)"),
                    ("skipped", "\(validCueIDs.count - insertedCueIDs.count)"),
                    ("list_id", "\(destinationListID)"),
                    ("list", destination.name)
                ]
            )

            mutationTask?.cancel()
            mutationTask = Task { @MainActor [weak self] in
                defer { self?.mutationTask = nil }
                do {
                    let (uniqueCueCount, recentSummaries) = try await Self.runCancellableDetached(priority: .userInitiated) {
                        let db = try ExcerptDatabase(path: databaseURL)
                        _ = try db.upsertExcerpts(cueIDs: insertedCueIDs, listID: destinationListID)
                        return (try db.uniqueExcerptCueCount(), try db.recentExcerptListSummaries())
                    }
                    guard let self, !self.needsReloadAfterIndexedContentMutation else { return }
                    _ = self.adjustListCueCounts([destinationListID: 0], uniqueCueCount: uniqueCueCount)
                    self.installRecentListSummaries(recentSummaries)
                } catch {
                    AppLogger.shared.error(
                        .database,
                        "Failed to save Excerpts in background",
                        fields: [("count", "\(insertedCueIDs.count)"), ("list_id", "\(destinationListID)"), ("error", error.localizedDescription)]
                    )
                    guard let self else { return }
                    onReportToast(
                        ExcerptToastRequest.saveFailed(listName: destination.name)
                    )
                    self.reloadListOverview()
                }
            }
            return true
        } catch {
            AppLogger.shared.error(
                .database,
                "Failed to save Excerpts",
                fields: [("count", "\(validCueIDs.count)"), ("list_id", "\(destinationListID)"), ("error", error.localizedDescription)]
            )
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
            AppLogger.shared.error(
                .database,
                "Failed to resolve Excerpt move destination",
                fields: [("list_id", "\(destinationListID)"), ("error", error.localizedDescription)]
            )
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

        invalidateCachedResidentSnapshot(forListID: destinationListID)
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
        AppLogger.shared.info(
            .excerpt,
            "Excerpt moved to list",
            fields: [
                ("excerpt_id", "\(item.id)"),
                ("from_list_id", sourceListID.map { "\($0)" }),
                ("to_list_id", "\(destinationListID)"),
                ("to_list", destination.name)
            ]
        )

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
                AppLogger.shared.error(
                    .database,
                    "Failed to move Excerpt in background",
                    fields: [("excerpt_id", "\(itemID)"), ("list_id", "\(destinationListID)"), ("error", error.localizedDescription)]
                )
                onToast(ExcerptToastRequest.moveFailed)
                self?.reloadListOverview()
                onReloadTableRows()
            }
        }
        return true
    }

    @discardableResult
    func moveExcerpts(
        _ items: [Excerpt],
        toListID destinationListID: Int64,
        listName: String,
        validExcerptIDsInLibrary: ([Int64]) -> Set<Int64>,
        onToast: @escaping @MainActor (ToastRequest) -> Void,
        onItemsRemovedFromCurrentList: ([Excerpt]) -> Void,
        onReloadTableRows: @escaping @MainActor () -> Void
    ) -> Bool {
        let inLibrarySet = validExcerptIDsInLibrary(items.map(\.id))
        var seenIDs = Set<Int64>()
        let validItems = items.filter {
            $0.isValid && inLibrarySet.contains($0.id) && seenIDs.insert($0.id).inserted
        }
        guard !validItems.isEmpty else {
            onToast(TableToastRequest.cueNotInLibrary(count: max(1, items.count)))
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
            AppLogger.shared.error(
                .database,
                "Failed to resolve Excerpt batch move destination",
                fields: [("list_id", "\(destinationListID)"), ("error", error.localizedDescription)]
            )
            onToast(ExcerptToastRequest.moveFailed)
            return false
        }

        let relationByID = resolvedRelationsByID(for: validItems.map(\.id), database: database)
        let candidateCueIDs = validItems.compactMap { relationByID[$0.id]?.cueID }
        let existingDestinationCueIDs = (try? database.existingCueIDs(
            inListID: destinationListID,
            among: candidateCueIDs
        )) ?? []

        var plannedCueIDs = existingDestinationCueIDs
        var itemsToMove: [Excerpt] = []
        var movedCueIDs = Set<Int64>()
        for item in validItems {
            if let relation = relationByID[item.id] {
                guard plannedCueIDs.insert(relation.cueID).inserted else {
                    continue
                }
                itemsToMove.append(item)
                movedCueIDs.insert(relation.cueID)
            } else {
                itemsToMove.append(item)
            }
        }
        guard !itemsToMove.isEmpty else {
            onToast(
                ExcerptToastRequest.destinationAlreadyContainsCue(
                    listName: destination.name
                )
            )
            return false
        }

        invalidateCachedResidentSnapshot(forListID: destinationListID)
        let sourceListID = activeListID
        onItemsRemovedFromCurrentList(itemsToMove)
        let moveCount = itemsToMove.count
        let didUpdateOverview = sourceListID.map { sourceID in
            adjustListCueCounts(
                [
                    sourceID: -moveCount,
                    destinationListID: moveCount,
                ],
                addedCueIDsByListID: movedCueIDs.isEmpty ? [:] : [destinationListID: movedCueIDs],
                removedCueIDsByListID: movedCueIDs.isEmpty ? [:] : [sourceID: movedCueIDs]
            )
        } ?? false
        if !didUpdateOverview {
            reloadListOverview()
        }
        onToast(ExcerptToastRequest.moveSucceeded(listName: destination.name))
        AppLogger.shared.info(
            .excerpt,
            "Excerpts moved to list",
            fields: [
                ("count", "\(moveCount)"),
                ("skipped", "\(validItems.count - moveCount)"),
                ("from_list_id", sourceListID.map { "\($0)" }),
                ("to_list_id", "\(destinationListID)"),
                ("to_list", destination.name)
            ]
        )

        let moveIDs = itemsToMove.map(\.id)
        let destinationName = destination.name
        mutationTask?.cancel()
        mutationTask = Task { @MainActor [weak self] in
            defer { self?.mutationTask = nil }
            do {
                let recentSummaries = try await Self.runCancellableDetached(priority: .userInitiated) {
                    let db = try ExcerptDatabase(path: databaseURL)
                    _ = try db.moveExcerpts(ids: moveIDs, toListID: destinationListID)
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
                AppLogger.shared.error(
                    .database,
                    "Failed to move Excerpts in background",
                    fields: [("count", "\(moveIDs.count)"), ("list_id", "\(destinationListID)"), ("error", error.localizedDescription)]
                )
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
            AppLogger.shared.error(
                .database,
                "Failed to resolve Excerpt duplicate destination",
                fields: [("list_id", "\(destinationListID)"), ("error", error.localizedDescription)]
            )
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

        invalidateCachedResidentSnapshot(forListID: destinationListID)
        let addedCueIDs: [Int64: Set<Int64>] = relation.map { [destinationListID: [$0.cueID]] } ?? [:]
        if !adjustListCueCounts(
            [destinationListID: 1],
            addedCueIDsByListID: addedCueIDs
        ) {
            reloadListOverview()
        }
        onToast(ExcerptToastRequest.duplicateSucceeded(listName: destination.name))
        AppLogger.shared.info(
            .excerpt,
            "Excerpt duplicated to list",
            fields: [
                ("excerpt_id", "\(item.id)"),
                ("to_list_id", "\(destinationListID)"),
                ("to_list", destination.name)
            ]
        )

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
                AppLogger.shared.error(
                    .database,
                    "Failed to duplicate Excerpt in background",
                    fields: [("excerpt_id", "\(itemID)"), ("list_id", "\(destinationListID)"), ("error", error.localizedDescription)]
                )
                onToast(ExcerptToastRequest.duplicateFailed)
                self?.reloadListOverview()
            }
        }
        return true
    }

    @discardableResult
    func duplicateExcerpts(
        _ items: [Excerpt],
        toListID destinationListID: Int64,
        listName: String,
        validExcerptIDsInLibrary: ([Int64]) -> Set<Int64>,
        onToast: @escaping @MainActor (ToastRequest) -> Void
    ) -> Bool {
        let inLibrarySet = validExcerptIDsInLibrary(items.map(\.id))
        var seenIDs = Set<Int64>()
        let validItems = items.filter {
            $0.isValid && inLibrarySet.contains($0.id) && seenIDs.insert($0.id).inserted
        }
        guard !validItems.isEmpty else {
            onToast(TableToastRequest.cueNotInLibrary(count: max(1, items.count)))
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
            AppLogger.shared.error(
                .database,
                "Failed to resolve Excerpt batch duplicate destination",
                fields: [("list_id", "\(destinationListID)"), ("error", error.localizedDescription)]
            )
            onToast(ExcerptToastRequest.duplicateFailed)
            return false
        }

        let relationByID = resolvedRelationsByID(for: validItems.map(\.id), database: database)
        let candidateCueIDs = validItems.compactMap { relationByID[$0.id]?.cueID }
        let existingDestinationCueIDs = (try? database.existingCueIDs(
            inListID: destinationListID,
            among: candidateCueIDs
        )) ?? []

        var plannedCueIDs = existingDestinationCueIDs
        var itemsToDuplicate: [Excerpt] = []
        var duplicatedCueIDs = Set<Int64>()
        for item in validItems {
            if let relation = relationByID[item.id] {
                guard plannedCueIDs.insert(relation.cueID).inserted else {
                    continue
                }
                itemsToDuplicate.append(item)
                duplicatedCueIDs.insert(relation.cueID)
            } else {
                itemsToDuplicate.append(item)
            }
        }
        guard !itemsToDuplicate.isEmpty else {
            onToast(
                ExcerptToastRequest.destinationAlreadyContainsCue(
                    listName: destination.name
                )
            )
            return false
        }

        invalidateCachedResidentSnapshot(forListID: destinationListID)
        let duplicateCount = itemsToDuplicate.count
        let addedCueIDs: [Int64: Set<Int64>] = duplicatedCueIDs.isEmpty
            ? [:]
            : [destinationListID: duplicatedCueIDs]
        if !adjustListCueCounts(
            [destinationListID: duplicateCount],
            addedCueIDsByListID: addedCueIDs
        ) {
            reloadListOverview()
        }
        onToast(ExcerptToastRequest.duplicateSucceeded(listName: destination.name))
        AppLogger.shared.info(
            .excerpt,
            "Excerpts duplicated to list",
            fields: [
                ("count", "\(duplicateCount)"),
                ("skipped", "\(validItems.count - duplicateCount)"),
                ("to_list_id", "\(destinationListID)"),
                ("to_list", destination.name)
            ]
        )

        let duplicateIDs = itemsToDuplicate.map(\.id)
        let destinationName = destination.name
        mutationTask?.cancel()
        mutationTask = Task { @MainActor [weak self] in
            defer { self?.mutationTask = nil }
            do {
                let recentSummaries = try await Self.runCancellableDetached(priority: .userInitiated) {
                    let db = try ExcerptDatabase(path: databaseURL)
                    _ = try db.duplicateExcerpts(ids: duplicateIDs, toListID: destinationListID)
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
                AppLogger.shared.error(
                    .database,
                    "Failed to duplicate Excerpts in background",
                    fields: [("count", "\(duplicateIDs.count)"), ("list_id", "\(destinationListID)"), ("error", error.localizedDescription)]
                )
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
        removeExcerpts(
            [item],
            reloadPresentation: reloadPresentation,
            onFeedback: onFeedback,
            onItemsRemovedFromCurrentList: { items in
                for removed in items {
                    onItemRemovedFromCurrentList(removed)
                }
            },
            onReloadTableRows: onReloadTableRows
        )
    }

    @discardableResult
    func removeExcerpts(
        _ items: [Excerpt],
        reloadPresentation: Bool = true,
        onFeedback: @escaping @MainActor (ExcerptFeedbackState) -> Void,
        onItemsRemovedFromCurrentList: ([Excerpt]) -> Void,
        onReloadTableRows: @escaping @MainActor () -> Void
    ) -> Bool {
        var seenIDs = Set<Int64>()
        let uniqueItems = items.filter { seenIDs.insert($0.id).inserted }
        guard !uniqueItems.isEmpty else {
            return false
        }
        guard let database, let databaseURL else {
            onFeedback(.unavailable)
            return false
        }

        _ = reloadPresentation
        let sourceListID = activeListID
        let validItems = uniqueItems.filter(\.isValid)
        let relationByID = resolvedRelationsByID(for: validItems.map(\.id), database: database)
        let removedCueIDSet = Set(validItems.compactMap { relationByID[$0.id]?.cueID })
        let cueCountDelta = -validItems.count

        onItemsRemovedFromCurrentList(uniqueItems)
        if let sourceListID {
            let removedCueIDs: [Int64: Set<Int64>] = removedCueIDSet.isEmpty
                ? [:]
                : [sourceListID: removedCueIDSet]
            _ = adjustListCueCounts(
                [sourceListID: cueCountDelta],
                removedCueIDsByListID: removedCueIDs
            )
        } else if !needsReloadAfterIndexedContentMutation {
            reloadListOverview()
        }
        onFeedback(.removed)
        AppLogger.shared.info(
            .excerpt,
            uniqueItems.count == 1 ? "Excerpt removed from list" : "Excerpts removed from list",
            fields: [
                ("count", "\(uniqueItems.count)"),
                ("list_id", sourceListID.map { "\($0)" })
            ]
        )

        let itemIDs = uniqueItems.map(\.id)
        mutationTask?.cancel()
        mutationTask = Task { @MainActor [weak self] in
            defer { self?.mutationTask = nil }
            do {
                let (uniqueCueCount, recentSummaries) = try await Self.runCancellableDetached(priority: .userInitiated) {
                    let database = try ExcerptDatabase(path: databaseURL)
                    _ = try database.removeExcerpts(ids: itemIDs)
                    return (try database.uniqueExcerptCueCount(), try database.recentExcerptListSummaries())
                }
                guard let self, !self.needsReloadAfterIndexedContentMutation else { return }
                if let sourceListID {
                    _ = self.adjustListCueCounts([sourceListID: 0], uniqueCueCount: uniqueCueCount)
                }
                self.installRecentListSummaries(recentSummaries)
            } catch {
                AppLogger.shared.error(
                    .database,
                    "Failed to remove Excerpt in background",
                    fields: [("count", "\(itemIDs.count)"), ("error", error.localizedDescription)]
                )
                guard let self else { return }
                onFeedback(.unavailable)
                self.reloadListOverview()
                onReloadTableRows()
            }
        }
        return true
    }

    private func resolvedRelationsByID(
        for excerptIDs: [Int64],
        database: ExcerptDatabase
    ) -> [Int64: ExcerptRelation] {
        guard !excerptIDs.isEmpty else { return [:] }
        var map = Dictionary(
            uniqueKeysWithValues: residentRelations.map { ($0.id, $0) }
        )
        let missingIDs = excerptIDs.filter { map[$0] == nil }
        if !missingIDs.isEmpty,
           let fetched = try? database.excerptRelations(ids: missingIDs) {
            for relation in fetched {
                map[relation.id] = relation
            }
        }
        return map
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
                AppLogger.shared.warn(
                    .database,
                    "Failed to record recent Excerpt playback",
                    fields: [("excerpt_id", "\(itemID)"), ("error", error.localizedDescription)]
                )
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
            AppLogger.shared.error(
                .database,
                "Failed to load scoped Excerpt",
                fields: [("excerpt_id", "\(id)"), ("error", error.localizedDescription)]
            )
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
                AppLogger.shared.warn(
                    .database,
                    "Failed to load adjacent Excerpt",
                    fields: [("excerpt_id", "\(selectedID)"), ("error", error.localizedDescription)]
                )
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
        removeExcerptsFromPlaybackNavigationScope([id])
    }

    func removeExcerptsFromPlaybackNavigationScope(_ ids: Set<Int64>) {
        guard !ids.isEmpty, var scopeIDs = playbackNavigationScopeIDs else {
            return
        }
        scopeIDs.removeAll { ids.contains($0) }
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

