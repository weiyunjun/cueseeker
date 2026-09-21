import Combine
import Foundation
import CueSeekerCore

struct TableSandboxRowsSnapshot {
    fileprivate var materializedRows: [SubtitleTableRow] = []
    var searchResultsByEntryID: [Int: SubtitleSearchResult] = [:]
    fileprivate var searchCueIDs: [Int64] = []
    fileprivate var searchCueIndexByEntryID: [Int: Int] = [:]
    fileprivate var searchRankByCueID: [Int64: Int] = [:]
    fileprivate var searchCueContentProvider: ((Int64) -> CueContent?)?
    fileprivate var searchSourceRevision: UInt64?
    var excerptsByEntryID: [Int: Excerpt] = [:]
    var excerptCuePresentationsByEntryID: [Int: ExcerptCuePresentation] = [:]
    fileprivate var excerptRelations: [ExcerptRelation] = []
    fileprivate var excerptRelationIndexByEntryID: [Int: Int] = [:]
    fileprivate var cueContentProvider: ((Int64) -> CueContent?)?
    fileprivate var cueContentRevision: UInt64 = 0
    var version = 0
    var update = TableSandboxRowsUpdate.none
    var totalRowCount = 0
    /// Rows whose Cue is unavailable. They stay in the table but cannot be
    /// selected.
    let unavailableRows: Set<Int>

    init(
        rows: [SubtitleTableRow] = [],
        searchResultsByEntryID: [Int: SubtitleSearchResult] = [:],
        searchCueIDs: [Int64] = [],
        searchRankByCueID: [Int64: Int] = [:],
        searchCueContentProvider: ((Int64) -> CueContent?)? = nil,
        searchSourceRevision: UInt64? = nil,
        excerptsByEntryID: [Int: Excerpt] = [:],
        excerptCuePresentationsByEntryID: [Int: ExcerptCuePresentation] = [:],
        excerptRelations: [ExcerptRelation] = [],
        cueContentProvider: ((Int64) -> CueContent?)? = nil,
        cueContentRevision: UInt64 = 0,
        version: Int = 0,
        update: TableSandboxRowsUpdate = .none,
        totalRowCount: Int = 0
    ) {
        materializedRows = rows
        self.searchResultsByEntryID = searchResultsByEntryID
        self.searchCueIDs = searchCueIDs
        self.searchCueIndexByEntryID = Dictionary(
            uniqueKeysWithValues: searchCueIDs.enumerated().map { index, cueID in
                (Int(cueID), index)
            }
        )
        self.searchRankByCueID = searchRankByCueID
        self.searchCueContentProvider = searchCueContentProvider
        self.searchSourceRevision = searchSourceRevision
        self.excerptsByEntryID = excerptsByEntryID
        self.excerptCuePresentationsByEntryID = excerptCuePresentationsByEntryID
        self.excerptRelations = excerptRelations
        self.excerptRelationIndexByEntryID = Dictionary(
            uniqueKeysWithValues: excerptRelations.enumerated().map { index, relation in
                (Int(relation.id), index)
            }
        )
        self.cueContentProvider = cueContentProvider
        self.cueContentRevision = cueContentRevision
        self.version = version
        self.update = update
        self.totalRowCount = totalRowCount
        // The same test the rows themselves use for their unavailable state.
        unavailableRows = excerptRelations.isEmpty
            ? Set(rows.indices.filter { rows[$0].cueState.isUnavailable })
            : Set(excerptRelations.indices.filter {
                excerptsByEntryID[Int(excerptRelations[$0].id)]?.unavailableReason != nil
            })
    }

    var rows: [SubtitleTableRow] {
        if !excerptRelations.isEmpty {
            return excerptRelations.indices.compactMap { row(at: $0) }
        }
        if !searchCueIDs.isEmpty {
            return searchCueIDs.indices.compactMap { row(at: $0) }
        }
        return materializedRows
    }

    var loadedReferenceCount: Int {
        if !excerptRelations.isEmpty { return excerptRelations.count }
        if !searchCueIDs.isEmpty { return searchCueIDs.count }
        return materializedRows.count
    }

    var materializedRowCount: Int {
        materializedRows.count
    }

    var orderedEntryIDs: [Int] {
        if !excerptRelations.isEmpty {
            return excerptRelations.map { Int($0.id) }
        }
        if !searchCueIDs.isEmpty {
            return searchCueIDs.map(Int.init)
        }
        return materializedRows.map(\.id)
    }

    func row(at index: Int) -> SubtitleTableRow? {
        guard index >= 0 else { return nil }
        if excerptRelations.indices.contains(index) {
            let relation = excerptRelations[index]
            let resolvedExcerpt = excerptsByEntryID[Int(relation.id)]
            if let cueContent = cueContentProvider?(relation.cueID) {
                return tableSandboxExcerptRow(
                    relation: relation,
                    cueContent: cueContent,
                    resolvedExcerpt: resolvedExcerpt
                )
            }
            guard let resolvedExcerpt else {
                return nil
            }
            return tableSandboxUnavailableExcerptRow(
                relation: relation,
                excerpt: resolvedExcerpt
            )
        }
        if searchCueIDs.indices.contains(index) {
            let cueID = searchCueIDs[index]
            guard let content = searchCueContentProvider?(cueID) else {
                return nil
            }
            return tableSandboxSearchRow(
                for: SubtitleSearchResult(
                    cueContent: content,
                    searchRank: searchRankByCueID[cueID] ?? index
                )
            )
        }
        guard materializedRows.indices.contains(index) else { return nil }
        return materializedRows[index]
    }

    func rowIndex(entryID: Int) -> Int? {
        excerptRelationIndexByEntryID[entryID]
            ?? searchCueIndexByEntryID[entryID]
            ?? materializedRows.firstIndex(where: { $0.id == entryID })
    }

    func searchResult(entryID: Int) -> SubtitleSearchResult? {
        if let result = searchResultsByEntryID[entryID] {
            return result
        }
        guard searchCueIndexByEntryID[entryID] != nil,
              let content = searchCueContentProvider?(Int64(entryID))
        else {
            return nil
        }
        return SubtitleSearchResult(
            cueContent: content,
            searchRank: searchRankByCueID[Int64(entryID)] ?? 0
        )
    }

    func excerpt(entryID: Int) -> Excerpt? {
        if let excerpt = excerptsByEntryID[entryID] {
            return excerpt
        }
        guard let index = excerptRelationIndexByEntryID[entryID],
              let cueContentProvider
        else {
            return nil
        }
        let relation = excerptRelations[index]
        if let resolved = excerptsByEntryID[entryID] {
            return resolved
        }
        guard let cueContent = cueContentProvider(relation.cueID) else {
            return nil
        }
        return Excerpt(relation: relation, cueContent: cueContent)
    }

    func excerptCuePresentation(entryID: Int) -> ExcerptCuePresentation? {
        if let presentation = excerptCuePresentationsByEntryID[entryID] {
            return presentation
        }
        guard let index = excerptRelationIndexByEntryID[entryID] else {
            return nil
        }
        let relation = excerptRelations[index]
        if let cueContent = cueContentProvider?(relation.cueID) {
            return ExcerptCuePresentation(cueContent: cueContent)
        }
        guard let excerpt = excerptsByEntryID[entryID] else {
            return nil
        }
        let groupTexts = tableSandboxCueGroupSnapshotTexts(excerpt.cueGroupContent)
        return ExcerptCuePresentation(
            cueID: relation.cueID,
            cueGroupID: nil,
            primaryGroupIndex: groupTexts.firstIndex(of: excerpt.content),
            cueGroupTexts: groupTexts.isEmpty ? [excerpt.content] : groupTexts,
            languages: [.unknown]
        )
    }
}

struct TableSandboxExcerptRowSource: Equatable, Sendable {
    let excerpt: Excerpt
    let displayTitle: String
    let dateAddedText: String
    let languages: Set<SubtitleLanguageCode>
    let cuePresentation: ExcerptCuePresentation?

    init(
        excerpt: Excerpt,
        displayTitle: String,
        dateAddedText: String,
        languages: Set<SubtitleLanguageCode>,
        cuePresentation: ExcerptCuePresentation? = nil
    ) {
        self.excerpt = excerpt
        self.displayTitle = displayTitle
        self.dateAddedText = dateAddedText
        self.languages = languages
        self.cuePresentation = cuePresentation
    }
}

@MainActor
final class TableSandboxRowModelStore: ObservableObject {
    @Published private(set) var snapshot = TableSandboxRowsSnapshot()

    private var observedCueContentRevision: UInt64 = 0
    private var referencedCueContentRevision: UInt64 = 0

    func refreshReferencedCueContent(
        _ change: CueContentStoreChange,
        tableName: String,
        probeSurface: SubtitleTableProbeSurface? = nil,
        probeScope: String? = nil
    ) {
        guard change.revision > observedCueContentRevision else {
            return
        }
        observedCueContentRevision = change.revision
        let affectsSearch = snapshot.searchCueIDs.contains {
            change.cueIDs.contains($0)
        }
        let affectsExcerpt = snapshot.excerptRelations.contains {
            change.cueIDs.contains($0.cueID)
        }
        guard affectsSearch || affectsExcerpt else {
            return
        }

        referencedCueContentRevision &+= 1
        var nextSnapshot = snapshot
        nextSnapshot.cueContentRevision = referencedCueContentRevision
        nextSnapshot.version += 1
        nextSnapshot.update = .reload
        publishSnapshot(
            nextSnapshot,
            tableName: tableName,
            probeSurface: probeSurface ?? SubtitleTableProbeSurface(tableName: tableName),
            probeScope: probeScope,
            reason: "canonical_cue_content_changed"
        )
    }

    func updateResidentSearchResults(
        _ results: [SubtitleSearchResult],
        cueContentProvider: @escaping (Int64) -> CueContent?,
        cueContentRevision: UInt64 = 0,
        tableName: String,
        probeSurface: SubtitleTableProbeSurface? = nil,
        probeScope: String? = nil,
        isHydration: Bool = false
    ) {
        let cueIDs = results.map(\.entryID)
        let ranks = Dictionary(uniqueKeysWithValues: results.map {
            ($0.entryID, $0.searchRank)
        })
        updateResidentSearchReferences(
            cueIDs: cueIDs,
            ranksByCueID: ranks,
            cueContentProvider: cueContentProvider,
            cueContentRevision: cueContentRevision,
            tableName: tableName,
            probeSurface: probeSurface,
            probeScope: probeScope,
            isHydration: isHydration
        )
    }

    func updateResidentSearchReferences(
        cueIDs: [Int64],
        ranksByCueID ranks: [Int64: Int],
        cueContentProvider: @escaping (Int64) -> CueContent?,
        cueContentRevision: UInt64,
        sourceRevision: UInt64? = nil,
        tableName: String,
        probeSurface: SubtitleTableProbeSurface? = nil,
        probeScope: String? = nil,
        isHydration: Bool = false
    ) {
        acknowledgeCueContentRevision(cueContentRevision)
        if let sourceRevision,
           snapshot.searchSourceRevision == sourceRevision,
           snapshot.cueContentRevision == referencedCueContentRevision,
           snapshot.materializedRows.isEmpty,
           snapshot.excerptRelations.isEmpty {
            return
        }
        let update: TableSandboxRowsUpdate
        if snapshot.loadedReferenceCount == 0, !cueIDs.isEmpty {
            update = .append(0..<cueIDs.count)
        } else if snapshot.searchCueIDs == cueIDs,
                  snapshot.materializedRows.isEmpty,
                  snapshot.excerptRelations.isEmpty,
                  snapshot.searchRankByCueID == ranks,
                  snapshot.cueContentRevision == referencedCueContentRevision {
            return
        } else {
            update = .reload
        }
        publishSnapshot(TableSandboxRowsSnapshot(
            searchCueIDs: cueIDs,
            searchRankByCueID: ranks,
            searchCueContentProvider: cueContentProvider,
            searchSourceRevision: sourceRevision,
            cueContentRevision: referencedCueContentRevision,
            version: snapshot.version + 1,
            update: update,
            totalRowCount: cueIDs.count
        ), tableName: tableName,
           probeSurface: probeSurface ?? SubtitleTableProbeSurface(tableName: tableName),
           probeScope: probeScope,
           reason: "search_resident_projection",
           isHydration: isHydration)
    }

    func hydrateResidentSearchResults(
        _ results: [SubtitleSearchResult],
        startIndex: Int,
        cueContentProvider: @escaping (Int64) -> CueContent?,
        cueContentRevision: UInt64 = 0,
        tableName: String,
        probeSurface: SubtitleTableProbeSurface? = nil,
        probeScope: String? = nil
    ) {
        guard startIndex >= 0,
              startIndex <= snapshot.searchCueIDs.count,
              !results.isEmpty
        else {
            return
        }
        acknowledgeCueContentRevision(cueContentRevision)
        var cueIDs = snapshot.searchCueIDs
        var ranks = snapshot.searchRankByCueID
        for (offset, result) in results.enumerated() {
            let index = startIndex + offset
            if cueIDs.indices.contains(index) {
                cueIDs[index] = result.entryID
            } else {
                cueIDs.append(result.entryID)
            }
            ranks[result.entryID] = result.searchRank
        }
        let oldCount = snapshot.searchCueIDs.count
        let update: TableSandboxRowsUpdate = oldCount == startIndex
            ? .append(oldCount..<cueIDs.count)
            : .reload
        publishSnapshot(TableSandboxRowsSnapshot(
            searchCueIDs: cueIDs,
            searchRankByCueID: ranks,
            searchCueContentProvider: cueContentProvider,
            searchSourceRevision: snapshot.searchSourceRevision,
            cueContentRevision: referencedCueContentRevision,
            version: snapshot.version + 1,
            update: update,
            totalRowCount: cueIDs.count
        ), tableName: tableName,
           probeSurface: probeSurface ?? SubtitleTableProbeSurface(tableName: tableName),
           probeScope: probeScope,
           reason: "search_resident_hydration",
           isHydration: true)
    }

    @discardableResult
    func prependResidentSearchResults(
        _ results: [SubtitleSearchResult],
        cueContentProvider: @escaping (Int64) -> CueContent?,
        cueContentRevision: UInt64 = 0,
        tableName: String,
        probeSurface: SubtitleTableProbeSurface? = nil,
        probeScope: String? = nil
    ) -> Int {
        let existingIDs = Set(snapshot.searchCueIDs)
        let inserted = results.filter { !existingIDs.contains($0.entryID) }
        guard !inserted.isEmpty else { return 0 }
        let nextResults = inserted + snapshot.searchCueIDs.compactMap { cueID in
            snapshot.searchCueContentProvider?(cueID).map {
                SubtitleSearchResult(
                    cueContent: $0,
                    searchRank: snapshot.searchRankByCueID[cueID] ?? 0
                )
            }
        }
        updateResidentSearchResults(
            nextResults,
            cueContentProvider: cueContentProvider,
            cueContentRevision: cueContentRevision,
            tableName: tableName,
            probeSurface: probeSurface,
            probeScope: probeScope,
            isHydration: true
        )
        return inserted.count
    }

    @discardableResult
    func appendResidentSearchResults(
        _ results: [SubtitleSearchResult],
        cueContentProvider: @escaping (Int64) -> CueContent?,
        cueContentRevision: UInt64 = 0,
        tableName: String,
        probeSurface: SubtitleTableProbeSurface? = nil,
        probeScope: String? = nil
    ) -> Int {
        let existingIDs = Set(snapshot.searchCueIDs)
        let inserted = results.filter { !existingIDs.contains($0.entryID) }
        guard !inserted.isEmpty else { return 0 }
        hydrateResidentSearchResults(
            inserted,
            startIndex: snapshot.searchCueIDs.count,
            cueContentProvider: cueContentProvider,
            cueContentRevision: cueContentRevision,
            tableName: tableName,
            probeSurface: probeSurface,
            probeScope: probeScope
        )
        return inserted.count
    }

    func updateSearchRows(
        _ results: [SubtitleSearchResult],
        totalRowCount: Int? = nil,
        tableName: String,
        probeSurface: SubtitleTableProbeSurface? = nil,
        probeScope: String? = nil,
        isHydration: Bool = false
    ) {
        var prefixUnchanged = results.count >= snapshot.materializedRows.count
        let rows = results.enumerated().map { index, result in
            let row = searchRow(for: result)
            if index < snapshot.materializedRows.count,
               row != snapshot.materializedRows[index] {
                prefixUnchanged = false
            }
            return row
        }

        apply(
            rows,
            searchResultsByEntryID: [:],
            excerptsByEntryID: [:],
            totalRowCount: rows.count,
            prefixUnchanged: prefixUnchanged,
            tableName: tableName,
            probeSurface: probeSurface ?? SubtitleTableProbeSurface(tableName: tableName),
            probeScope: probeScope,
            reason: "search_update",
            isHydration: isHydration
        )
    }

    func hydrateSearchRows(
        _ results: [SubtitleSearchResult],
        startIndex: Int,
        totalRowCount: Int,
        tableName: String,
        probeSurface: SubtitleTableProbeSurface? = nil,
        probeScope: String? = nil
    ) {
        _ = totalRowCount
        guard startIndex >= 0, !results.isEmpty else { return }
        guard startIndex <= snapshot.materializedRows.count else { return }

        var nextRows = snapshot.materializedRows
        var nextSearchResultsByEntryID = snapshot.searchResultsByEntryID
        let oldRowCount = nextRows.count
        var lowerChangedIndex: Int?
        var upperChangedIndex: Int?
        var actionCacheChanged = false

        for (offset, result) in results.enumerated() {
            let sourceIndex = startIndex + offset
            let row = searchRow(for: result)
            if sourceIndex < nextRows.count {
                if nextRows[sourceIndex] != row {
                    lowerChangedIndex = min(lowerChangedIndex ?? sourceIndex, sourceIndex)
                    upperChangedIndex = max(upperChangedIndex ?? sourceIndex + 1, sourceIndex + 1)
                }
                nextRows[sourceIndex] = row
            } else {
                lowerChangedIndex = min(lowerChangedIndex ?? sourceIndex, sourceIndex)
                upperChangedIndex = max(upperChangedIndex ?? sourceIndex + 1, sourceIndex + 1)
                nextRows.append(row)
            }
            if nextSearchResultsByEntryID[Int(result.entryID)] != result {
                actionCacheChanged = true
                nextSearchResultsByEntryID[Int(result.entryID)] = result
            }
        }

        guard lowerChangedIndex != nil || actionCacheChanged else { return }

        let update: TableSandboxRowsUpdate
        if oldRowCount == startIndex, nextRows.count > oldRowCount {
            update = .append(oldRowCount..<nextRows.count)
        } else if lowerChangedIndex != nil {
            update = .reload
        } else {
            update = .none
        }

        publishSnapshot(TableSandboxRowsSnapshot(
            rows: nextRows,
            searchResultsByEntryID: nextSearchResultsByEntryID,
            excerptsByEntryID: snapshot.excerptsByEntryID,
            version: snapshot.version + 1,
            update: update,
            totalRowCount: nextRows.count
        ), tableName: tableName,
           probeSurface: probeSurface ?? SubtitleTableProbeSurface(tableName: tableName),
           probeScope: probeScope,
           reason: "search_hydration",
           isHydration: true)
    }

    func updateExcerptRows(
        _ excerpts: [TableSandboxExcerptRowSource],
        tableName: String,
        probeSurface: SubtitleTableProbeSurface? = nil,
        probeScope: String? = nil
    ) {
        var prefixUnchanged = excerpts.count >= snapshot.materializedRows.count
        let rows = excerpts.enumerated().map { index, item in
            let row = excerptRow(for: item)
            if index < snapshot.materializedRows.count,
               row != snapshot.materializedRows[index] {
                prefixUnchanged = false
            }
            return row
        }
        let excerptsByEntryID = Dictionary(uniqueKeysWithValues: excerpts.map { item in
            (Int(item.excerpt.id), item.excerpt)
        })
        let cuePresentationsByEntryID = Dictionary(uniqueKeysWithValues: excerpts.compactMap { item in
            item.cuePresentation.map { (Int(item.excerpt.id), $0) }
        })

        apply(
            rows,
            searchResultsByEntryID: [:],
            excerptsByEntryID: excerptsByEntryID,
            excerptCuePresentationsByEntryID: cuePresentationsByEntryID,
            totalRowCount: excerpts.count,
            prefixUnchanged: prefixUnchanged,
            tableName: tableName,
            probeSurface: probeSurface ?? SubtitleTableProbeSurface(tableName: tableName),
            probeScope: probeScope,
            reason: "excerpt_update"
        )
    }

    func updateResidentExcerptRelations(
        _ relations: [ExcerptRelation],
        resolvedExcerptsByID: [Int64: Excerpt] = [:],
        cueContentProvider: @escaping (Int64) -> CueContent?,
        cueContentRevision: UInt64 = 0,
        tableName: String,
        probeSurface: SubtitleTableProbeSurface? = nil,
        probeScope: String? = nil
    ) {
        acknowledgeCueContentRevision(cueContentRevision)
        let normalizedExcerpts = Dictionary(
            uniqueKeysWithValues: resolvedExcerptsByID.map { key, value in
                (Int(key), value)
            }
        )
        let contentChanged = relations != snapshot.excerptRelations
            || normalizedExcerpts != snapshot.excerptsByEntryID
            || !snapshot.materializedRows.isEmpty
            || snapshot.cueContentRevision != referencedCueContentRevision
        guard contentChanged || snapshot.totalRowCount != relations.count else {
            return
        }

        let update: TableSandboxRowsUpdate = if snapshot.totalRowCount == 0,
                                                !relations.isEmpty {
            .append(0..<relations.count)
        } else {
            .reload
        }
        publishSnapshot(TableSandboxRowsSnapshot(
            excerptsByEntryID: normalizedExcerpts,
            excerptRelations: relations,
            cueContentProvider: cueContentProvider,
            cueContentRevision: referencedCueContentRevision,
            version: snapshot.version + 1,
            update: update,
            totalRowCount: relations.count
        ), tableName: tableName,
           probeSurface: probeSurface ?? SubtitleTableProbeSurface(tableName: tableName),
           probeScope: probeScope,
           reason: "excerpt_resident_projection")
    }

    func removeResidentExcerpt(
        id: Int64,
        tableName: String,
        probeSurface: SubtitleTableProbeSurface? = nil,
        probeScope: String? = nil
    ) {
        guard snapshot.excerptRelations.contains(where: { $0.id == id }) else {
            return
        }
        let relations = snapshot.excerptRelations.filter { $0.id != id }
        publishSnapshot(TableSandboxRowsSnapshot(
            excerptsByEntryID: snapshot.excerptsByEntryID.filter { $0.key != Int(id) },
            excerptRelations: relations,
            cueContentProvider: snapshot.cueContentProvider,
            cueContentRevision: snapshot.cueContentRevision,
            version: snapshot.version + 1,
            update: .reload,
            totalRowCount: relations.count
        ), tableName: tableName,
           probeSurface: probeSurface ?? SubtitleTableProbeSurface(tableName: tableName),
           probeScope: probeScope,
           reason: "excerpt_remove")
    }

    private func acknowledgeCueContentRevision(_ revision: UInt64) {
        guard revision > observedCueContentRevision else {
            return
        }
        observedCueContentRevision = revision
        referencedCueContentRevision &+= 1
    }

    func hydrateExcerptRows(
        _ excerpts: [TableSandboxExcerptRowSource],
        startIndex: Int,
        totalRowCount: Int,
        tableName: String,
        probeSurface: SubtitleTableProbeSurface? = nil,
        probeScope: String? = nil
    ) {
        guard startIndex >= 0 else { return }
        guard startIndex <= snapshot.materializedRows.count else { return }

        if excerpts.isEmpty {
            guard totalRowCount == 0 else { return }
            let previousVersion = snapshot.version
            let resolvedProbeSurface = probeSurface
                ?? SubtitleTableProbeSurface(tableName: tableName)
            updateExcerptRows(
                [],
                tableName: tableName,
                probeSurface: resolvedProbeSurface,
                probeScope: probeScope
            )
            if snapshot.version != previousVersion {
                UIInvalidationProbe.count(
                    resolvedProbeSurface.counterName("row_hydration_applied"),
                    scope: probeScope,
                    details: "table=\(tableName) reason=excerpt_empty"
                )
            }
            return
        }

        var nextRows = snapshot.materializedRows
        var nextExcerptsByEntryID = snapshot.excerptsByEntryID
        var nextCuePresentationsByEntryID = snapshot.excerptCuePresentationsByEntryID
        let oldRowCount = nextRows.count
        var lowerChangedIndex: Int?
        var upperChangedIndex: Int?
        var actionCacheChanged = false

        for (offset, item) in excerpts.enumerated() {
            let sourceIndex = startIndex + offset
            let row = excerptRow(for: item)
            if sourceIndex < nextRows.count {
                if nextRows[sourceIndex] != row {
                    lowerChangedIndex = min(lowerChangedIndex ?? sourceIndex, sourceIndex)
                    upperChangedIndex = max(upperChangedIndex ?? sourceIndex + 1, sourceIndex + 1)
                }
                nextRows[sourceIndex] = row
            } else {
                lowerChangedIndex = min(lowerChangedIndex ?? sourceIndex, sourceIndex)
                upperChangedIndex = max(upperChangedIndex ?? sourceIndex + 1, sourceIndex + 1)
                nextRows.append(row)
            }
            if nextExcerptsByEntryID[Int(item.excerpt.id)] != item.excerpt {
                actionCacheChanged = true
                nextExcerptsByEntryID[Int(item.excerpt.id)] = item.excerpt
            }
            if nextCuePresentationsByEntryID[Int(item.excerpt.id)] != item.cuePresentation {
                actionCacheChanged = true
                nextCuePresentationsByEntryID[Int(item.excerpt.id)] = item.cuePresentation
            }
        }

        guard lowerChangedIndex != nil || actionCacheChanged else { return }

        let update: TableSandboxRowsUpdate
        if oldRowCount == startIndex, nextRows.count > oldRowCount {
            update = .append(oldRowCount..<nextRows.count)
        } else if lowerChangedIndex != nil {
            update = .reload
        } else {
            update = .none
        }

        publishSnapshot(TableSandboxRowsSnapshot(
            rows: nextRows,
            searchResultsByEntryID: [:],
            excerptsByEntryID: nextExcerptsByEntryID,
            excerptCuePresentationsByEntryID: nextCuePresentationsByEntryID,
            version: snapshot.version + 1,
            update: update,
            totalRowCount: nextRows.count
        ), tableName: tableName,
           probeSurface: probeSurface ?? SubtitleTableProbeSurface(tableName: tableName),
           probeScope: probeScope,
           reason: "excerpt_hydration",
           isHydration: true)
    }

    private func apply(
        _ rows: [SubtitleTableRow],
        searchResultsByEntryID: [Int: SubtitleSearchResult],
        excerptsByEntryID: [Int: Excerpt],
        excerptCuePresentationsByEntryID: [Int: ExcerptCuePresentation] = [:],
        totalRowCount: Int,
        prefixUnchanged: Bool,
        tableName: String,
        probeSurface: SubtitleTableProbeSurface,
        probeScope: String?,
        reason: String,
        isHydration: Bool = false
    ) {
        let rowsUpdate = rowsUpdate(for: rows, prefixUnchanged: prefixUnchanged)
        let metadataChanged = totalRowCount != snapshot.totalRowCount
        let actionCacheChanged = searchResultsByEntryID != snapshot.searchResultsByEntryID
            || excerptsByEntryID != snapshot.excerptsByEntryID
            || excerptCuePresentationsByEntryID
                != snapshot.excerptCuePresentationsByEntryID
        let update = rowsUpdate == .none && metadataChanged ? .reload : rowsUpdate
        let changed = update != .none || metadataChanged || actionCacheChanged

        guard changed else {
            return
        }

        publishSnapshot(TableSandboxRowsSnapshot(
            rows: rows,
            searchResultsByEntryID: searchResultsByEntryID,
            excerptsByEntryID: excerptsByEntryID,
            excerptCuePresentationsByEntryID: excerptCuePresentationsByEntryID,
            version: snapshot.version + 1,
            update: update,
            totalRowCount: totalRowCount
        ), tableName: tableName,
           probeSurface: probeSurface,
           probeScope: probeScope,
           reason: reason,
           isHydration: isHydration)
    }

    private func publishSnapshot(
        _ nextSnapshot: TableSandboxRowsSnapshot,
        tableName: String,
        probeSurface: SubtitleTableProbeSurface,
        probeScope: String?,
        reason: String,
        isHydration: Bool = false
    ) {
        snapshot = nextSnapshot
        UIInvalidationProbe.count(
            probeSurface.counterName("snapshot_rebuild"),
            scope: probeScope,
            details: "table=\(tableName) reason=\(reason) version=\(nextSnapshot.version)"
        )
        if isHydration {
            UIInvalidationProbe.count(
                probeSurface.counterName("row_hydration_applied"),
                scope: probeScope,
                details: "table=\(tableName) reason=\(reason)"
            )
        }
    }

    private func rowsUpdate(for rows: [SubtitleTableRow], prefixUnchanged: Bool) -> TableSandboxRowsUpdate {
        if rows.count == snapshot.materializedRows.count, prefixUnchanged {
            return .none
        }

        if rows.count > snapshot.materializedRows.count, prefixUnchanged {
            return .append(snapshot.materializedRows.count..<rows.count)
        }

        return .reload
    }

    private func searchRow(for result: SubtitleSearchResult) -> SubtitleTableRow {
        let displayTitle = result.displayTitle
        return SubtitleTableRow(
            id: Int(result.entryID),
            primaryCueID: result.entryID,
            subtitlePath: result.subtitlePath,
            displayTitle: displayTitle,
            startTime: tableSandboxCueTimeText(milliseconds: result.startMilliseconds),
            endTime: tableSandboxCueTimeText(milliseconds: result.endMilliseconds),
            timeRange: result.timeRange,
            primaryCueText: result.content,
            cueGroupTexts: result.cueGroupLines,
            primaryGroupIndex: result.primaryGroupIndex,
            tags: SubtitleLanguageWorkbenchTags.tags(for: result.languages)
        )
    }

    private func excerptRow(for item: TableSandboxExcerptRowSource) -> SubtitleTableRow {
        let cuePresentation = item.cuePresentation
        return SubtitleTableRow(
            id: Int(item.excerpt.id),
            primaryCueID: cuePresentation?.cueID,
            subtitlePath: item.excerpt.subtitlePath,
            dateAdded: item.dateAddedText,
            displayTitle: item.displayTitle,
            startTime: tableSandboxCueTimeText(milliseconds: item.excerpt.startMilliseconds),
            endTime: tableSandboxCueTimeText(milliseconds: item.excerpt.endMilliseconds),
            timeRange: item.excerpt.timeRange,
            primaryCueText: item.excerpt.content,
            cueGroupTexts: cuePresentation?.cueGroupTexts ?? [item.excerpt.content],
            primaryGroupIndex: cuePresentation?.primaryGroupIndex,
            tags: SubtitleLanguageWorkbenchTags.tags(
                for: cuePresentation?.languages ?? item.languages
            ),
            cueState: tableSandboxCueState(for: item.excerpt)
        )
    }

}

func tableSandboxSearchRow(for result: SubtitleSearchResult) -> SubtitleTableRow {
    let displayTitle = result.displayTitle
    return SubtitleTableRow(
        id: Int(result.entryID),
        primaryCueID: result.entryID,
        subtitlePath: result.subtitlePath,
        displayTitle: displayTitle,
        startTime: tableSandboxCueTimeText(milliseconds: result.startMilliseconds),
        endTime: tableSandboxCueTimeText(milliseconds: result.endMilliseconds),
        timeRange: result.timeRange,
        primaryCueText: result.content,
        cueGroupTexts: result.cueGroupLines,
        primaryGroupIndex: result.primaryGroupIndex,
        tags: SubtitleLanguageWorkbenchTags.tags(for: result.languages)
    )
}

func tableSandboxExcerptRow(for item: TableSandboxExcerptRowSource) -> SubtitleTableRow {
    let cuePresentation = item.cuePresentation
    return SubtitleTableRow(
        id: Int(item.excerpt.id),
        primaryCueID: cuePresentation?.cueID,
        subtitlePath: item.excerpt.subtitlePath,
        dateAdded: item.dateAddedText,
        displayTitle: item.displayTitle,
        startTime: tableSandboxCueTimeText(milliseconds: item.excerpt.startMilliseconds),
        endTime: tableSandboxCueTimeText(milliseconds: item.excerpt.endMilliseconds),
        timeRange: item.excerpt.timeRange,
        primaryCueText: item.excerpt.content,
        cueGroupTexts: cuePresentation?.cueGroupTexts ?? [item.excerpt.content],
        primaryGroupIndex: cuePresentation?.primaryGroupIndex,
        tags: SubtitleLanguageWorkbenchTags.tags(
            for: cuePresentation?.languages ?? item.languages
        ),
        cueState: tableSandboxCueState(for: item.excerpt)
    )
}

private func tableSandboxExcerptRow(
    relation: ExcerptRelation,
    cueContent: CueContent,
    resolvedExcerpt: Excerpt?
) -> SubtitleTableRow {
    SubtitleTableRow(
        id: Int(relation.id),
        primaryCueID: cueContent.cueID,
        subtitlePath: cueContent.subtitlePath,
        dateAdded: tableSandboxExcerptDateAddedDisplayText(for: relation.createdAt),
        displayTitle: cueContent.displayTitle,
        startTime: tableSandboxCueTimeText(milliseconds: cueContent.startMilliseconds),
        endTime: tableSandboxCueTimeText(milliseconds: cueContent.endMilliseconds),
        timeRange: cueContent.timeRange,
        primaryCueText: cueContent.content,
        cueGroupTexts: cueContent.cueGroupLines,
        primaryGroupIndex: cueContent.primaryGroupIndex,
        tags: SubtitleLanguageWorkbenchTags.tags(for: cueContent.languages),
        cueState: resolvedExcerpt.map(tableSandboxCueState(for:)) ?? .normal
    )
}

private func tableSandboxUnavailableExcerptRow(
    relation: ExcerptRelation,
    excerpt: Excerpt
) -> SubtitleTableRow {
    let cueGroupTexts = tableSandboxCueGroupSnapshotTexts(excerpt.cueGroupContent)
    return SubtitleTableRow(
        id: Int(relation.id),
        primaryCueID: relation.cueID,
        subtitlePath: excerpt.subtitlePath,
        dateAdded: tableSandboxExcerptDateAddedDisplayText(for: relation.createdAt),
        displayTitle: excerpt.displayTitle,
        startTime: tableSandboxCueTimeText(milliseconds: excerpt.startMilliseconds),
        endTime: tableSandboxCueTimeText(milliseconds: excerpt.endMilliseconds),
        timeRange: excerpt.timeRange,
        primaryCueText: excerpt.content,
        cueGroupTexts: cueGroupTexts.isEmpty ? [excerpt.content] : cueGroupTexts,
        primaryGroupIndex: cueGroupTexts.firstIndex(of: excerpt.content) ?? 0,
        cueState: tableSandboxCueState(for: excerpt)
    )
}

private func tableSandboxCueState(for excerpt: Excerpt) -> SubtitleTableCueState {
    if let unavailableReason = excerpt.unavailableReason {
        return .unavailable(unavailableReason)
    }
    if let change = excerpt.contentChange {
        return .contentChanged(
            previous: change.previousContent,
            current: change.currentContent
        )
    }
    return .normal
}

private func tableSandboxCueGroupSnapshotTexts(_ content: String) -> [String] {
    let separator = Excerpt.cueGroupContentSeparator
    guard content.contains(separator) else {
        return content.isEmpty ? [] : [content]
    }
    return content
        .components(separatedBy: separator)
        .filter { !$0.isEmpty }
}

func tableSandboxExcerptDateAddedDisplayText(
    for value: String,
    timeZone: TimeZone = .current
) -> String {
    let isoFormatter = ISO8601DateFormatter()
    guard let date = isoFormatter.date(from: value) else {
        return value
    }

    return tableSandboxExcerptDateAddedDisplayText(for: date, timeZone: timeZone)
}

/// The one date shape the App shows a reader. The Excerpt table's Date Added
/// column and the Task panel's history both read it, so they cannot drift.
func tableSandboxExcerptDateAddedDisplayText(
    for date: Date,
    timeZone: TimeZone = .current
) -> String {
    let displayFormatter = DateFormatter()
    displayFormatter.locale = Locale(identifier: "en_US_POSIX")
    displayFormatter.timeZone = timeZone
    displayFormatter.dateFormat = "yy-MM-dd HH:mm"
    return displayFormatter.string(from: date)
}

func tableSandboxCueTimeText(milliseconds: Int) -> String {
    let totalSeconds = max(0, milliseconds) / 1_000
    let hours = totalSeconds / 3_600
    let minutes = (totalSeconds % 3_600) / 60
    let seconds = totalSeconds % 60

    if hours > 0 {
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
    return String(format: "%02d:%02d", minutes, seconds)
}
