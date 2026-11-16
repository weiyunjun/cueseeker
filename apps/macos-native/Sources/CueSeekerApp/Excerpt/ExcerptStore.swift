import Combine
import Foundation
import CueSeekerCore

@MainActor
final class ExcerptStore: ObservableObject {
    let cueContentStore: CueContentStore
    let userDefaults: UserDefaults
    let databaseURL: URL?
    let database: ExcerptDatabase?
    let coverStorage: ExcerptListCoverStorage
    let uiProbeScope: String?
    private static let overviewSortOrderUserDefaultsKey = "excerpt_overview_sort_order"
    private var cueContentChangesCancellable: AnyCancellable?
    private var isTableProjectionResponseActive = true
    private var pendingCueContentChange: CueContentStoreChange?
    var needsReloadAfterIndexedContentMutation = false
    var pendingContentRemovalFolders: [URL] = []
    var listCoverImportTask: Task<Void, Never>?
    var listSaveTask: Task<Void, Never>?
    var listOverviewTask: Task<Void, Never>?
    var tableRowsTask: Task<Void, Never>?
    var mutationTask: Task<Void, Never>?
    var playbackNavigationScopeIDs: [Int64]?
    var playbackNavigationSnapshot: (currentID: Int64, previousID: Int64?, nextID: Int64?)?
    @Published private(set) var listOverview = ExcerptListOverview(
        lists: [],
        uniqueCueCount: 0
    )
    @Published var overviewSearchDraft = ""
    @Published var overviewSortOrder: ExcerptOverviewSortOrder = .oldestCreated {
        didSet {
            userDefaults.set(
                overviewSortOrder.rawValue,
                forKey: Self.overviewSortOrderUserDefaultsKey
            )
        }
    }
    @Published private(set) var recentListSummaries: [ExcerptListSummary] = []

    var displayedListSummaries: [ExcerptListSummary] {
        listOverview.filteredAndSortedLists(
            matching: overviewSearchDraft,
            by: overviewSortOrder
        )
    }

    var displayedUniqueCueCount: Int {
        listOverview.uniqueCueCount(for: displayedListSummaries)
    }
    @Published private(set) var hasLoadedListOverview = false
    @Published private(set) var activeListID: Int64?
    /// The list the last successful `Save to Excerpt` went to, loaded from
    /// settings at launch. Only the destination menu's opening highlight reads
    /// it; a list that is gone by then is cleared rather than tracked here.
    @Published private(set) var recentSaveListID: Int64?
    @Published var listEditorSession: ExcerptListEditorSession?
    var selectedExcerpt: Excerpt?
    @Published var tableSearchDraft = ""
    @Published var tableTotalSavedRowCount = 0
    @Published var tableResultRowCount = 0
    @Published var tableHasLoadedInitialPage = false
    @Published var tableDataRevision = 0
    @Published private(set) var residentFacetSnapshot: CueFacetSnapshot?
    private(set) var tableFacetFilter = CueFacetFilter()
    @Published private(set) var tableSortOrder: ExcerptSortOrder = .earliestDateAdded
    private var tableSearchDraftsByListID: [Int64: String] = [:]
    private(set) var tableResultSnapshotID = UUID()
    private(set) var tableResultExcerptIDs: [Int64]?
    private var cachedPlaybackTableResultExcerptIDs: [Int64]?
    private var cachedValidResultOrdinalByExcerptID: [Int64: Int] = [:]
    private(set) var residentRelations: [ExcerptRelation] = []
    private(set) var residentExcerptsByID: [Int64: Excerpt] = [:]
    private var residentCueIDByExcerptID: [Int64: Int64] = [:]
    private var residentExcerptIDByCueID: [Int64: Int64] = [:]
    private(set) var residentDataRevision: Int?
    private(set) var residentListID: Int64?
    private var residentSnapshotsByListID: [Int64: ExcerptResidentSnapshot] = [:]
    private var residentDataRevisionsByListID: [Int64: Int] = [:]
    private(set) var tableRowsNeedReload = false
    var tableViewportAnchor: TableViewportAnchor?
    var tableSelectionState = TableSandboxRowSelectionState()
    var tableSelectionEntryIDs: [Int] = []

    var residentCueIDs: Set<Int64> {
        guard !residentRelations.isEmpty || !residentSnapshotsByListID.isEmpty else {
            return []
        }
        var cueIDs = Set<Int64>()
        cueIDs.reserveCapacity(residentRelations.count)
        for relation in residentRelations {
            cueIDs.insert(relation.cueID)
        }
        for snapshot in residentSnapshotsByListID.values {
            for relation in snapshot.relations {
                cueIDs.insert(relation.cueID)
            }
        }
        return cueIDs
    }

    var playbackTableResultExcerptIDs: [Int64]? {
        if let cachedPlaybackTableResultExcerptIDs {
            return cachedPlaybackTableResultExcerptIDs
        }
        return tableResultExcerptIDs?.filter { excerptID in
            if let resident = residentExcerptsByID[excerptID] {
                return resident.isValid
            }
            guard let entryID = Int(exactly: excerptID) else {
                return false
            }
            return tableRowStore.snapshot.excerpt(entryID: entryID)?.isValid == true
        }
    }

    var activeListSummary: ExcerptListSummary? {
        guard let activeListID,
              let overview = listOverview.lists.first(where: {
                  $0.id == activeListID
              })
        else {
            return nil
        }
        guard let recent = recentListSummaries.first(where: {
            $0.id == activeListID
        }) else {
            return overview
        }
        return ExcerptListSummary(
            list: recent.list,
            cueCount: overview.cueCount,
            validCueIDs: overview.validCueIDs,
            resumeExcerpt: overview.cueCount > 0 ? recent.resumeExcerpt : nil,
            resumePosition: overview.cueCount > 0 ? recent.resumePosition : nil
        )
    }

    var activeListHasPlayableContent: Bool {
        guard let activeListID,
              residentListID == activeListID,
              tableHasLoadedInitialPage,
              let validExcerptIDs = playbackTableResultExcerptIDs
        else {
            return (activeListSummary?.cueCount ?? 0) > 0
        }
        return !validExcerptIDs.isEmpty
    }

    func tableSearchQuery(forListID listID: Int64) -> String {
        activeListID == listID
            ? tableSearchDraft
            : (tableSearchDraftsByListID[listID] ?? "")
    }

    func activeListCoverSummaryState(
        for summary: ExcerptListSummary
    ) -> (
        actionKind: CoverSummaryActionKind,
        isActionEnabled: Bool,
        targetExcerpt: Excerpt?,
        cueID: Int64?,
        position: Int?,
        totalCount: Int?
    ) {
        guard residentListID == summary.id,
              tableHasLoadedInitialPage,
              let validExcerptIDs = playbackTableResultExcerptIDs
        else {
            let isEnabled = summary.cueCount > 0
            let actionKind: CoverSummaryActionKind = (
                isEnabled && summary.list.recentCueID != nil && summary.resumeExcerpt != nil
            ) ? .resume : .play
            return (actionKind, isEnabled, nil, nil, nil, nil)
        }
        guard !validExcerptIDs.isEmpty else {
            return (.play, false, nil, nil, nil, 0)
        }
        let hitOrdinal = summary.list.recentCueID
            .flatMap { residentExcerptIDByCueID[$0] }
            .flatMap { targetExcerptID in
                cachedPlaybackTableResultExcerptIDs != nil
                    ? cachedValidResultOrdinalByExcerptID[targetExcerptID]
                    : validExcerptIDs.firstIndex(of: targetExcerptID)
            }
        let resolvedOrdinal = hitOrdinal ?? 0
        let actionKind: CoverSummaryActionKind = hitOrdinal != nil ? .resume : .play
        let targetExcerptID = validExcerptIDs[resolvedOrdinal]
        let cueID = residentCueIDByExcerptID[targetExcerptID]
        let targetExcerpt = residentExcerptsByID[targetExcerptID]
        return (
            actionKind,
            true,
            targetExcerpt,
            cueID,
            resolvedOrdinal + 1,
            validExcerptIDs.count
        )
    }

    let tableRowStore = TableSandboxRowModelStore()

    init(
        cueContentStore: CueContentStore? = nil,
        userDefaults: UserDefaults? = nil,
        databaseURL: URL? = nil,
        database: ExcerptDatabase? = nil,
        coverStorage: ExcerptListCoverStorage? = nil,
        uiProbeScope: String? = nil
    ) {
        let resolvedCueContentStore = cueContentStore ?? CueContentStore()
        let resolvedUserDefaults = userDefaults ?? ApplicationPersistence.sharedUserDefaults()
        let defaultCoverDir = (databaseURL ?? AppCoordinator.defaultDatabaseURL())
            .deletingLastPathComponent()
            .appendingPathComponent("Covers", isDirectory: true)
        self.cueContentStore = resolvedCueContentStore
        self.userDefaults = resolvedUserDefaults
        self.databaseURL = databaseURL
        self.database = database
        self.coverStorage = coverStorage ?? ExcerptListCoverStorage(coverDirectory: defaultCoverDir)
        self.uiProbeScope = uiProbeScope
        let savedOverviewSortOrder = resolvedUserDefaults.string(
            forKey: Self.overviewSortOrderUserDefaultsKey
        )
        self.overviewSortOrder = savedOverviewSortOrder
            .flatMap(ExcerptOverviewSortOrder.init(rawValue:)) ?? .oldestCreated
        cueContentChangesCancellable = resolvedCueContentStore.changes.sink {
            [weak self] change in
            self?.receiveCueContentChange(change)
        }
    }

    func setTableProjectionResponseActive(_ isActive: Bool) {
        guard isTableProjectionResponseActive != isActive else {
            return
        }
        isTableProjectionResponseActive = isActive
        guard isActive, let pendingCueContentChange else {
            return
        }
        self.pendingCueContentChange = nil
        refreshReferencedCueContent(pendingCueContentChange)
    }

    func installListOverview(_ overview: ExcerptListOverview) {
        if overview.lists.isEmpty, !overviewSearchDraft.isEmpty {
            overviewSearchDraft = ""
        }
        guard listOverview != overview || !hasLoadedListOverview else {
            return
        }
        listOverview = overview
        if !hasLoadedListOverview {
            hasLoadedListOverview = true
        }
        // A deleted list's id is handed to the next list created, so the
        // remembered save target is dropped the moment its list leaves the
        // overview rather than when a menu next asks for it.
        if let recentSaveListID,
           !overview.lists.contains(where: { $0.id == recentSaveListID }) {
            self.recentSaveListID = nil
        }
    }

    func clearListOverviewForReload() {
        hasLoadedListOverview = false
    }

    func installRecentListSummaries(_ summaries: [ExcerptListSummary]) {
        guard recentListSummaries != summaries else {
            return
        }
        recentListSummaries = summaries
    }

    @discardableResult
    func upsertListSummary(_ list: ExcerptList) -> Bool {
        guard hasLoadedListOverview else {
            return false
        }
        var lists = listOverview.lists
        if let index = lists.firstIndex(where: { $0.id == list.id }) {
            let current = lists[index]
            let replacement = ExcerptListSummary(
                list: list,
                cueCount: current.cueCount,
                validCueIDs: current.validCueIDs
            )
            guard current != replacement else {
                return true
            }
            lists[index] = replacement
            if let recentIndex = recentListSummaries.firstIndex(
                where: { $0.id == list.id }
            ) {
                let recent = recentListSummaries[recentIndex]
                var updatedRecent = recentListSummaries
                updatedRecent[recentIndex] = ExcerptListSummary(
                    list: list,
                    cueCount: recent.cueCount,
                    validCueIDs: recent.validCueIDs,
                    resumeExcerpt: recent.resumeExcerpt,
                    resumePosition: recent.resumePosition
                )
                installRecentListSummaries(updatedRecent)
            }
        } else {
            let newSummary = ExcerptListSummary(list: list, cueCount: 0)
            lists.append(newSummary)
            lists.sort {
                if $0.list.createdAt != $1.list.createdAt {
                    return $0.list.createdAt < $1.list.createdAt
                }
                return $0.id < $1.id
            }
            var updatedRecent = recentListSummaries.filter { $0.id != list.id }
            updatedRecent.append(newSummary)
            updatedRecent.sort(by: Self.ordersBeforeInRecentListSummaries)
            installRecentListSummaries(updatedRecent)
        }
        installListOverview(ExcerptListOverview(
            lists: lists,
            uniqueCueCount: listOverview.uniqueCueCount
        ))
        return true
    }

    private static func ordersBeforeInRecentListSummaries(
        _ lhs: ExcerptListSummary,
        _ rhs: ExcerptListSummary
    ) -> Bool {
        switch (lhs.list.recentPlayedAt, rhs.list.recentPlayedAt) {
        case (.some(let lhsPlayedAt), .some(let rhsPlayedAt)):
            if lhsPlayedAt != rhsPlayedAt {
                return lhsPlayedAt > rhsPlayedAt
            }
            return lhs.id > rhs.id
        case (.some, .none):
            return true
        case (.none, .some):
            return false
        case (.none, .none):
            if lhs.list.createdAt != rhs.list.createdAt {
                return lhs.list.createdAt < rhs.list.createdAt
            }
            return lhs.id < rhs.id
        }
    }

    @discardableResult
    func removeListSummary(id: Int64, uniqueCueCount: Int? = nil) -> Bool {
        tableSearchDraftsByListID[id] = nil
        residentSnapshotsByListID[id] = nil
        residentDataRevisionsByListID[id] = nil
        guard hasLoadedListOverview,
              listOverview.lists.contains(where: { $0.id == id })
        else {
            return false
        }
        let remainingLists = listOverview.lists.filter { $0.id != id }
        let resolvedUniqueCueCount: Int
        if remainingLists.contains(where: { !$0.validCueIDs.isEmpty })
            || remainingLists.allSatisfy({ $0.cueCount == 0 }) {
            resolvedUniqueCueCount = listOverview.uniqueCueCount(for: remainingLists)
        } else {
            resolvedUniqueCueCount = uniqueCueCount ?? listOverview.uniqueCueCount(for: remainingLists)
        }
        installListOverview(ExcerptListOverview(
            lists: remainingLists,
            uniqueCueCount: resolvedUniqueCueCount
        ))
        installRecentListSummaries(
            recentListSummaries.filter { $0.id != id }
        )
        return true
    }

    @discardableResult
    func adjustListCueCounts(
        _ deltas: [Int64: Int],
        addedCueIDsByListID: [Int64: Set<Int64>] = [:],
        removedCueIDsByListID: [Int64: Set<Int64>] = [:],
        uniqueCueCount: Int? = nil
    ) -> Bool {
        guard hasLoadedListOverview,
              deltas.keys.allSatisfy({ listID in
                  listOverview.lists.contains(where: { $0.id == listID })
              })
        else {
            return false
        }
        let lists = listOverview.lists.map { summary in
            let delta = deltas[summary.id] ?? 0
            let added = addedCueIDsByListID[summary.id] ?? []
            let removed = removedCueIDsByListID[summary.id] ?? []
            guard delta != 0 || !added.isEmpty || !removed.isEmpty else {
                return summary
            }
            var updatedValidCueIDs = summary.validCueIDs
            updatedValidCueIDs.subtract(removed)
            updatedValidCueIDs.formUnion(added)
            let clearsRecentCue = summary.list.recentCueID.map { removed.contains($0) } == true
            let updatedList = clearsRecentCue ? summary.list.clearingRecentCue() : summary.list
            return ExcerptListSummary(
                list: updatedList,
                cueCount: max(0, summary.cueCount + delta),
                validCueIDs: updatedValidCueIDs
            )
        }
        let resolvedUniqueCueCount: Int
        if let uniqueCueCount {
            resolvedUniqueCueCount = uniqueCueCount
        } else if lists.contains(where: { !$0.validCueIDs.isEmpty })
                    || lists.allSatisfy({ $0.cueCount == 0 }) {
            resolvedUniqueCueCount = ExcerptListOverview(
                lists: lists,
                uniqueCueCount: listOverview.uniqueCueCount
            ).uniqueCueCount(for: lists)
        } else {
            resolvedUniqueCueCount = listOverview.uniqueCueCount
        }
        installListOverview(ExcerptListOverview(
            lists: lists,
            uniqueCueCount: resolvedUniqueCueCount
        ))
        let updatedRecent = recentListSummaries.map { summary -> ExcerptListSummary in
            let delta = deltas[summary.id] ?? 0
            let added = addedCueIDsByListID[summary.id] ?? []
            let removed = removedCueIDsByListID[summary.id] ?? []
            guard delta != 0 || !added.isEmpty || !removed.isEmpty else {
                return summary
            }
            let nextCueCount = max(0, summary.cueCount + delta)
            var updatedValidCueIDs = summary.validCueIDs
            updatedValidCueIDs.subtract(removed)
            updatedValidCueIDs.formUnion(added)
            let clearsRecentCue = summary.list.recentCueID.map { removed.contains($0) } == true
            let updatedList = clearsRecentCue ? summary.list.clearingRecentCue() : summary.list
            let keepsResume = nextCueCount > 0 && !clearsRecentCue
            return ExcerptListSummary(
                list: updatedList,
                cueCount: nextCueCount,
                validCueIDs: updatedValidCueIDs,
                resumeExcerpt: keepsResume ? summary.resumeExcerpt : nil,
                resumePosition: keepsResume ? summary.resumePosition : nil
            )
        }
        installRecentListSummaries(updatedRecent)
        return true
    }

    func syncOverviewListMetadata(from summaries: [ExcerptListSummary]) {
        guard hasLoadedListOverview else { return }
        let byID = Dictionary(uniqueKeysWithValues: summaries.map { ($0.id, $0.list) })
        let updated = listOverview.lists.map { summary -> ExcerptListSummary in
            guard let updatedList = byID[summary.id], updatedList != summary.list else {
                return summary
            }
            return ExcerptListSummary(
                list: updatedList,
                cueCount: summary.cueCount,
                validCueIDs: summary.validCueIDs,
                resumeExcerpt: summary.resumeExcerpt,
                resumePosition: summary.resumePosition
            )
        }
        installListOverview(ExcerptListOverview(
            lists: updated,
            uniqueCueCount: listOverview.uniqueCueCount
        ))
    }

    func setRecentSaveListID(_ listID: Int64?) {
        guard recentSaveListID != listID else {
            return
        }
        recentSaveListID = listID
    }

    func setActiveListID(_ listID: Int64?) {
        if let previousListID = activeListID {
            tableSearchDraftsByListID[previousListID] = tableSearchDraft
        }
        let restoredSearchDraft = listID.flatMap { tableSearchDraftsByListID[$0] } ?? ""
        if tableSearchDraft != restoredSearchDraft {
            tableSearchDraft = restoredSearchDraft
        }
        guard activeListID != listID else {
            return
        }
        activeListID = listID
        guard let listID else {
            clearResidentSnapshot()
            clearTableRowsForReload()
            return
        }
        if let cached = residentSnapshotsByListID[listID],
           residentDataRevisionsByListID[listID] == tableDataRevision {
            residentRelations = cached.relations
            residentExcerptsByID = Dictionary(
                uniqueKeysWithValues: cached.resolvedExcerpts.map { ($0.id, $0) }
            )
            residentFacetSnapshot = cached.facetSnapshot
            residentListID = listID
            residentDataRevision = tableDataRevision
            syncResidentRelationLookups()
            rebuildPlaybackTableResultCache()
        } else {
            clearResidentSnapshot()
            clearTableRowsForReload()
        }
    }

    private func syncResidentRelationLookups() {
        var cueIDByExcerptID: [Int64: Int64] = [:]
        var excerptIDByCueID: [Int64: Int64] = [:]
        cueIDByExcerptID.reserveCapacity(residentRelations.count)
        excerptIDByCueID.reserveCapacity(residentRelations.count)
        for relation in residentRelations {
            cueIDByExcerptID[relation.id] = relation.cueID
            excerptIDByCueID[relation.cueID] = relation.id
        }
        residentCueIDByExcerptID = cueIDByExcerptID
        residentExcerptIDByCueID = excerptIDByCueID
    }

    private func rebuildPlaybackTableResultCache() {
        guard let tableResultExcerptIDs,
              !residentExcerptsByID.isEmpty || residentDataRevision != nil
        else {
            cachedPlaybackTableResultExcerptIDs = nil
            cachedValidResultOrdinalByExcerptID = [:]
            return
        }
        var validIDs: [Int64] = []
        validIDs.reserveCapacity(tableResultExcerptIDs.count)
        var ordinals: [Int64: Int] = [:]
        ordinals.reserveCapacity(tableResultExcerptIDs.count)
        for excerptID in tableResultExcerptIDs {
            let isValid: Bool
            if let resident = residentExcerptsByID[excerptID] {
                isValid = resident.isValid
            } else if let entryID = Int(exactly: excerptID) {
                isValid = tableRowStore.snapshot.excerpt(entryID: entryID)?.isValid == true
            } else {
                isValid = false
            }
            if isValid {
                ordinals[excerptID] = validIDs.count
                validIDs.append(excerptID)
            }
        }
        cachedPlaybackTableResultExcerptIDs = validIDs
        cachedValidResultOrdinalByExcerptID = ordinals
    }

    private func receiveCueContentChange(_ change: CueContentStoreChange) {
        guard isTableProjectionResponseActive else {
            pendingCueContentChange = pendingCueContentChange?.merging(change)
                ?? change
            return
        }
        refreshReferencedCueContent(change)
    }

    private func refreshReferencedCueContent(_ change: CueContentStoreChange) {
        tableRowStore.refreshReferencedCueContent(
            change,
            tableName: "excerpt",
            probeSurface: .excerpt,
            probeScope: uiProbeScope
        )
    }

    func clearTableRowsForReload(tableName: String = "excerpt") {
        tableRowsNeedReload = false
        if tableHasLoadedInitialPage {
            tableHasLoadedInitialPage = false
        }
        if tableTotalSavedRowCount != 0 {
            tableTotalSavedRowCount = 0
        }
        if tableResultRowCount != 0 {
            tableResultRowCount = 0
        }
        tableResultSnapshotID = UUID()
        tableResultExcerptIDs = nil
        cachedPlaybackTableResultExcerptIDs = nil
        cachedValidResultOrdinalByExcerptID = [:]
        tableRowStore.updateResidentExcerptRelations(
            [],
            cueContentProvider: { _ in nil },
            tableName: tableName,
            probeSurface: .excerpt,
            probeScope: uiProbeScope
        )
    }

    func markTableRowsLoaded(totalSavedRowCount: Int) {
        tableRowsNeedReload = false
        if tableTotalSavedRowCount != totalSavedRowCount {
            tableTotalSavedRowCount = totalSavedRowCount
        }
        if !tableHasLoadedInitialPage {
            tableHasLoadedInitialPage = true
        }
    }

    func installTableResultExcerptIDs(_ excerptIDs: [Int64]) {
        tableResultExcerptIDs = excerptIDs
        rebuildPlaybackTableResultCache()
        if tableResultRowCount != excerptIDs.count {
            tableResultRowCount = excerptIDs.count
        }
    }

    @discardableResult
    func updateTableSearchDraft(_ searchText: String) -> Bool {
        let normalizedSearchText = SearchInputNormalizer.singleLine(searchText)
        if let activeListID {
            tableSearchDraftsByListID[activeListID] = normalizedSearchText
        }
        guard tableSearchDraft != normalizedSearchText else { return false }
        tableSearchDraft = normalizedSearchText
        return true
    }

    @discardableResult
    func updateTableFacetFilter(_ filter: CueFacetFilter) -> Bool {
        guard tableFacetFilter != filter else { return false }
        tableFacetFilter = filter
        return true
    }

    @discardableResult
    func updateTableSortOrder(_ sortOrder: ExcerptSortOrder) -> Bool {
        guard tableSortOrder != sortOrder else { return false }
        tableSortOrder = sortOrder
        return true
    }

    func beginTableResultProjection() {
        tableResultSnapshotID = UUID()
        tableResultExcerptIDs = nil
        cachedPlaybackTableResultExcerptIDs = nil
        cachedValidResultOrdinalByExcerptID = [:]
    }

    func installResidentSnapshot(
        _ snapshot: ExcerptResidentSnapshot,
        listID: Int64 = ExcerptListIdentity.defaultListID,
        dataRevision: Int
    ) {
        residentSnapshotsByListID[listID] = snapshot
        residentDataRevisionsByListID[listID] = dataRevision
        residentRelations = snapshot.relations
        residentExcerptsByID = Dictionary(
            uniqueKeysWithValues: snapshot.resolvedExcerpts.map { ($0.id, $0) }
        )
        residentFacetSnapshot = snapshot.facetSnapshot
        residentListID = listID
        residentDataRevision = dataRevision
        syncResidentRelationLookups()
        rebuildPlaybackTableResultCache()
    }

    func residentFacetProjection(
        using filter: CueFacetFilter
    ) -> (excerptIDs: [Int64], distribution: CueFacetDistribution) {
        Self.facetProjection(
            relations: residentRelations,
            facetSnapshot: residentFacetSnapshot,
            using: filter
        )
    }

    static func facetProjection(
        relations: [ExcerptRelation],
        facetSnapshot: CueFacetSnapshot?,
        using filter: CueFacetFilter
    ) -> (excerptIDs: [Int64], distribution: CueFacetDistribution) {
        guard let facetSnapshot else { return ([], .zero) }
        let projection = facetSnapshot.filteredCueIDs(
            using: filter,
            limit: facetSnapshot.cueIDs.count
        )
        let excerptIDByCueID = Dictionary(
            uniqueKeysWithValues: relations.map { ($0.cueID, $0.id) }
        )
        return (
            projection.cueIDs.compactMap { excerptIDByCueID[$0] },
            projection.distribution
        )
    }

    func clearResidentSnapshot() {
        residentRelations = []
        residentExcerptsByID = [:]
        residentCueIDByExcerptID = [:]
        residentExcerptIDByCueID = [:]
        residentFacetSnapshot = nil
        residentListID = nil
        residentDataRevision = nil
        rebuildPlaybackTableResultCache()
    }

    func removeExcerptFromCurrentProjection(id: Int64) {
        removeExcerptsFromCurrentProjection(ids: [id])
    }

    func removeExcerptsFromCurrentProjection(ids: Set<Int64>) {
        guard !ids.isEmpty,
              residentDataRevision != nil,
              residentListID == activeListID,
              residentRelations.contains(where: { ids.contains($0.id) })
        else {
            return
        }
        let removedCueIDs = Set(
            residentRelations.lazy.filter { ids.contains($0.id) }.map(\.cueID)
        )
        residentRelations.removeAll { ids.contains($0.id) }
        for id in ids {
            residentExcerptsByID[id] = nil
        }
        syncResidentRelationLookups()
        residentFacetSnapshot = residentFacetSnapshot?.removingCueIDs(
            removedCueIDs
        )
        if let listID = activeListID, let cached = residentSnapshotsByListID[listID] {
            let updatedRelations = cached.relations.filter { !ids.contains($0.id) }
            let updatedResolved = cached.resolvedExcerpts.filter { !ids.contains($0.id) }
            let updatedFacet = cached.facetSnapshot.removingCueIDs(removedCueIDs)
            residentSnapshotsByListID[listID] = ExcerptResidentSnapshot(
                relations: updatedRelations,
                resolvedExcerpts: updatedResolved,
                cueContents: cached.cueContents,
                facetSnapshot: updatedFacet
            )
        }
        if tableTotalSavedRowCount != residentRelations.count {
            tableTotalSavedRowCount = residentRelations.count
        }
        if let tableResultExcerptIDs {
            let previousEntryIDs = tableSelectionEntryIDs.isEmpty
                ? tableResultExcerptIDs.map(Int.init)
                : tableSelectionEntryIDs
            let remainingIDs = tableResultExcerptIDs.filter { !ids.contains($0) }
            let remainingEntryIDs = remainingIDs.map(Int.init)
            self.tableResultExcerptIDs = remainingIDs
            rebuildPlaybackTableResultCache()
            if tableResultRowCount != remainingIDs.count {
                tableResultRowCount = remainingIDs.count
            }
            tableResultSnapshotID = UUID()
            tableSelectionState.remap(
                from: previousEntryIDs,
                to: remainingEntryIDs
            )
            tableSelectionEntryIDs = remainingEntryIDs
        }
        tableRowStore.removeResidentExcerpts(
            ids: ids,
            tableName: "excerpt",
            probeSurface: .excerpt,
            probeScope: uiProbeScope
        )
    }

    func invalidateCachedResidentSnapshot(forListID listID: Int64) {
        residentSnapshotsByListID[listID] = nil
        residentDataRevisionsByListID[listID] = nil
        if activeListID == listID {
            tableRowsNeedReload = true
            residentFacetSnapshot = nil
            tableDataRevision += 1
        }
    }

    func invalidateTableRows(tableName: String = "excerpt") {
        residentSnapshotsByListID.removeAll()
        residentDataRevisionsByListID.removeAll()
        clearResidentSnapshot()
        clearTableRowsForReload(tableName: tableName)
        tableDataRevision += 1
    }

    func markTableRowsStale() {
        tableRowsNeedReload = true
        residentFacetSnapshot = nil
        residentSnapshotsByListID.removeAll()
        residentDataRevisionsByListID.removeAll()
        tableDataRevision += 1
    }

    func applyRename(
        _ steps: [LibraryRenameStep],
        cueContentStore: CueContentStore? = nil
    ) {
        let cueContentStore = cueContentStore ?? self.cueContentStore
        residentFacetSnapshot = residentFacetSnapshot?.rewritingFolderPaths(steps)
        for relation in residentRelations {
            if let content = cueContentStore.content(for: relation.cueID) {
                residentExcerptsByID[relation.id] = Excerpt(
                    relation: relation,
                    cueContent: content
                )
            }
        }
        rebuildPlaybackTableResultCache()
        for (listID, cached) in residentSnapshotsByListID {
            let existingByID = Dictionary(
                uniqueKeysWithValues: cached.resolvedExcerpts.map { ($0.id, $0) }
            )
            let updatedResolved = cached.relations.compactMap { relation -> Excerpt? in
                if let content = cueContentStore.content(for: relation.cueID) {
                    return Excerpt(relation: relation, cueContent: content)
                }
                return existingByID[relation.id]
            }
            let updatedContents = cached.cueContents.map {
                cueContentStore.content(for: $0.cueID) ?? $0
            }
            residentSnapshotsByListID[listID] = ExcerptResidentSnapshot(
                relations: cached.relations,
                resolvedExcerpts: updatedResolved,
                cueContents: updatedContents,
                facetSnapshot: cached.facetSnapshot.rewritingFolderPaths(steps)
            )
        }
        if let selected = selectedExcerpt,
           let updated = residentExcerptsByID[selected.id] {
            selectedExcerpt = updated
        }
    }
}

extension ExcerptOverviewSortOrder {
    var title: String {
        switch self {
        case .oldestCreated:
            L("excerpt.overview.sort.oldest_created")
        case .latestCreated:
            L("excerpt.overview.sort.latest_created")
        }
    }

    static var workbenchSortOptions: [SchemaWorkbenchSortOption] {
        allCases.map {
            SchemaWorkbenchSortOption(id: $0.rawValue, title: $0.title)
        }
    }
}

