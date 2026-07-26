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
    var shiorisByEntryID: [Int: Shiori] = [:]
    var shioriCuePresentationsByEntryID: [Int: ShioriCuePresentation] = [:]
    fileprivate var shioriRelations: [ShioriRelation] = []
    fileprivate var shioriRelationIndexByEntryID: [Int: Int] = [:]
    fileprivate var shioriTagsByEntryID: [Int: [ShioriTag]] = [:]
    fileprivate var cueContentProvider: ((Int64) -> CueContent?)?
    fileprivate var cueContentRevision: UInt64 = 0
    var version = 0
    var update = TableSandboxRowsUpdate.none
    var totalRowCount = 0

    init(
        rows: [SubtitleTableRow] = [],
        searchResultsByEntryID: [Int: SubtitleSearchResult] = [:],
        searchCueIDs: [Int64] = [],
        searchRankByCueID: [Int64: Int] = [:],
        searchCueContentProvider: ((Int64) -> CueContent?)? = nil,
        searchSourceRevision: UInt64? = nil,
        shiorisByEntryID: [Int: Shiori] = [:],
        shioriCuePresentationsByEntryID: [Int: ShioriCuePresentation] = [:],
        shioriRelations: [ShioriRelation] = [],
        shioriTagsByEntryID: [Int: [ShioriTag]] = [:],
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
        self.shiorisByEntryID = shiorisByEntryID
        self.shioriCuePresentationsByEntryID = shioriCuePresentationsByEntryID
        self.shioriRelations = shioriRelations
        self.shioriRelationIndexByEntryID = Dictionary(
            uniqueKeysWithValues: shioriRelations.enumerated().map { index, relation in
                (Int(relation.id), index)
            }
        )
        self.shioriTagsByEntryID = shioriTagsByEntryID
        self.cueContentProvider = cueContentProvider
        self.cueContentRevision = cueContentRevision
        self.version = version
        self.update = update
        self.totalRowCount = totalRowCount
    }

    var rows: [SubtitleTableRow] {
        if !shioriRelations.isEmpty {
            return shioriRelations.indices.compactMap { row(at: $0) }
        }
        if !searchCueIDs.isEmpty {
            return searchCueIDs.indices.compactMap { row(at: $0) }
        }
        return materializedRows
    }

    var loadedReferenceCount: Int {
        if !shioriRelations.isEmpty { return shioriRelations.count }
        if !searchCueIDs.isEmpty { return searchCueIDs.count }
        return materializedRows.count
    }

    var materializedRowCount: Int {
        materializedRows.count
    }

    var orderedEntryIDs: [Int] {
        if !shioriRelations.isEmpty {
            return shioriRelations.map { Int($0.id) }
        }
        if !searchCueIDs.isEmpty {
            return searchCueIDs.map(Int.init)
        }
        return materializedRows.map(\.id)
    }

    func row(at index: Int) -> SubtitleTableRow? {
        guard index >= 0 else { return nil }
        if shioriRelations.indices.contains(index) {
            let relation = shioriRelations[index]
            let resolvedShiori = shiorisByEntryID[Int(relation.id)]
            if let cueContent = cueContentProvider?(relation.cueID) {
                return tableSandboxShioriRow(
                    relation: relation,
                    cueContent: cueContent,
                    resolvedShiori: resolvedShiori,
                    shioriTags: shioriTagsByEntryID[Int(relation.id)] ?? []
                )
            }
            guard let resolvedShiori else {
                return nil
            }
            return tableSandboxUnavailableShioriRow(
                relation: relation,
                shiori: resolvedShiori,
                shioriTags: shioriTagsByEntryID[Int(relation.id)] ?? []
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
        shioriRelationIndexByEntryID[entryID]
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

    func shiori(entryID: Int) -> Shiori? {
        if let shiori = shiorisByEntryID[entryID] {
            return shiori
        }
        guard let index = shioriRelationIndexByEntryID[entryID],
              let cueContentProvider
        else {
            return nil
        }
        let relation = shioriRelations[index]
        if let resolved = shiorisByEntryID[entryID] {
            return resolved
        }
        guard let cueContent = cueContentProvider(relation.cueID) else {
            return nil
        }
        return Shiori(relation: relation, cueContent: cueContent)
    }

    func shioriCuePresentation(entryID: Int) -> ShioriCuePresentation? {
        if let presentation = shioriCuePresentationsByEntryID[entryID] {
            return presentation
        }
        guard let index = shioriRelationIndexByEntryID[entryID] else {
            return nil
        }
        let relation = shioriRelations[index]
        if let cueContent = cueContentProvider?(relation.cueID) {
            return ShioriCuePresentation(cueContent: cueContent)
        }
        guard let shiori = shiorisByEntryID[entryID] else {
            return nil
        }
        let groupTexts = tableSandboxCueGroupSnapshotTexts(shiori.cueGroupContent)
        return ShioriCuePresentation(
            cueID: relation.cueID,
            cueGroupID: nil,
            primaryGroupIndex: groupTexts.firstIndex(of: shiori.content),
            cueGroupTexts: groupTexts.isEmpty ? [shiori.content] : groupTexts,
            languages: [.unknown]
        )
    }
}

struct TableSandboxShioriRowSource: Equatable, Sendable {
    let shiori: Shiori
    let displayTitle: String
    let dateAddedText: String
    let languages: Set<SubtitleLanguageCode>
    let shioriTags: [ShioriTag]
    let cuePresentation: ShioriCuePresentation?

    init(
        shiori: Shiori,
        displayTitle: String,
        dateAddedText: String,
        languages: Set<SubtitleLanguageCode>,
        shioriTags: [ShioriTag],
        cuePresentation: ShioriCuePresentation? = nil
    ) {
        self.shiori = shiori
        self.displayTitle = displayTitle
        self.dateAddedText = dateAddedText
        self.languages = languages
        self.shioriTags = shioriTags
        self.cuePresentation = cuePresentation
    }
}

@MainActor
final class TableSandboxRowModelStore: ObservableObject {
    @Published private(set) var snapshot = TableSandboxRowsSnapshot()

    private var displayTitlesBySubtitlePath: [String: String] = [:]
    private var observedCueContentRevision: UInt64 = 0
    private var referencedCueContentRevision: UInt64 = 0
    private let displayTitleResolver: (String) -> String

    init(
        displayTitleResolver: @escaping (String) -> String = {
            SubtitleDisplayTitleResolver.displayTitle(forSubtitlePath: $0)
        }
    ) {
        self.displayTitleResolver = displayTitleResolver
    }

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
        let affectsShiori = snapshot.shioriRelations.contains {
            change.cueIDs.contains($0.cueID)
        }
        guard affectsSearch || affectsShiori else {
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
           snapshot.shioriRelations.isEmpty {
            return
        }
        let update: TableSandboxRowsUpdate
        if snapshot.loadedReferenceCount == 0, !cueIDs.isEmpty {
            update = .append(0..<cueIDs.count)
        } else if snapshot.searchCueIDs == cueIDs,
                  snapshot.materializedRows.isEmpty,
                  snapshot.shioriRelations.isEmpty,
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
            shiorisByEntryID: [:],
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
            shiorisByEntryID: snapshot.shiorisByEntryID,
            version: snapshot.version + 1,
            update: update,
            totalRowCount: nextRows.count
        ), tableName: tableName,
           probeSurface: probeSurface ?? SubtitleTableProbeSurface(tableName: tableName),
           probeScope: probeScope,
           reason: "search_hydration",
           isHydration: true)
    }

    @discardableResult
    func prependSearchRows(
        _ results: [SubtitleSearchResult],
        tableName: String,
        probeSurface: SubtitleTableProbeSurface? = nil,
        probeScope: String? = nil
    ) -> Int {
        let existingEntryIDs = Set(snapshot.materializedRows.map(\.id))
        let prependedResults = results.filter { !existingEntryIDs.contains(Int($0.entryID)) }
        guard !prependedResults.isEmpty else { return 0 }

        var nextSearchResultsByEntryID = snapshot.searchResultsByEntryID
        prependedResults.forEach { result in
            nextSearchResultsByEntryID[Int(result.entryID)] = result
        }

        publishSnapshot(TableSandboxRowsSnapshot(
            rows: prependedResults.map { searchRow(for: $0) } + snapshot.materializedRows,
            searchResultsByEntryID: nextSearchResultsByEntryID,
            shiorisByEntryID: snapshot.shiorisByEntryID,
            version: snapshot.version + 1,
            update: .reload,
            totalRowCount: snapshot.materializedRows.count + prependedResults.count
        ), tableName: tableName,
           probeSurface: probeSurface ?? SubtitleTableProbeSurface(tableName: tableName),
           probeScope: probeScope,
           reason: "search_prepend",
           isHydration: true)
        return prependedResults.count
    }

    @discardableResult
    func appendSearchRows(
        _ results: [SubtitleSearchResult],
        tableName: String,
        probeSurface: SubtitleTableProbeSurface? = nil,
        probeScope: String? = nil
    ) -> Int {
        let existingEntryIDs = Set(snapshot.materializedRows.map(\.id))
        let appendedResults = results.filter { !existingEntryIDs.contains(Int($0.entryID)) }
        guard !appendedResults.isEmpty else { return 0 }

        var nextSearchResultsByEntryID = snapshot.searchResultsByEntryID
        appendedResults.forEach { result in
            nextSearchResultsByEntryID[Int(result.entryID)] = result
        }

        let oldRowCount = snapshot.materializedRows.count
        let nextRows = snapshot.materializedRows + appendedResults.map { searchRow(for: $0) }
        publishSnapshot(TableSandboxRowsSnapshot(
            rows: nextRows,
            searchResultsByEntryID: nextSearchResultsByEntryID,
            shiorisByEntryID: snapshot.shiorisByEntryID,
            version: snapshot.version + 1,
            update: .append(oldRowCount..<nextRows.count),
            totalRowCount: nextRows.count
        ), tableName: tableName,
           probeSurface: probeSurface ?? SubtitleTableProbeSurface(tableName: tableName),
           probeScope: probeScope,
           reason: "search_append",
           isHydration: true)
        return appendedResults.count
    }

    func updateShioriRows(
        _ shioris: [TableSandboxShioriRowSource],
        tableName: String,
        probeSurface: SubtitleTableProbeSurface? = nil,
        probeScope: String? = nil
    ) {
        var prefixUnchanged = shioris.count >= snapshot.materializedRows.count
        let rows = shioris.enumerated().map { index, item in
            let row = shioriRow(for: item)
            if index < snapshot.materializedRows.count,
               row != snapshot.materializedRows[index] {
                prefixUnchanged = false
            }
            return row
        }
        let shiorisByEntryID = Dictionary(uniqueKeysWithValues: shioris.map { item in
            (Int(item.shiori.id), item.shiori)
        })
        let cuePresentationsByEntryID = Dictionary(uniqueKeysWithValues: shioris.compactMap { item in
            item.cuePresentation.map { (Int(item.shiori.id), $0) }
        })

        apply(
            rows,
            searchResultsByEntryID: [:],
            shiorisByEntryID: shiorisByEntryID,
            shioriCuePresentationsByEntryID: cuePresentationsByEntryID,
            totalRowCount: shioris.count,
            prefixUnchanged: prefixUnchanged,
            tableName: tableName,
            probeSurface: probeSurface ?? SubtitleTableProbeSurface(tableName: tableName),
            probeScope: probeScope,
            reason: "shiori_update"
        )
    }

    func updateResidentShioriRelations(
        _ relations: [ShioriRelation],
        tagsByShioriID: [Int64: [ShioriTag]],
        resolvedShiorisByID: [Int64: Shiori] = [:],
        cueContentProvider: @escaping (Int64) -> CueContent?,
        cueContentRevision: UInt64 = 0,
        tableName: String,
        probeSurface: SubtitleTableProbeSurface? = nil,
        probeScope: String? = nil
    ) {
        acknowledgeCueContentRevision(cueContentRevision)
        let normalizedTags = Dictionary(uniqueKeysWithValues: tagsByShioriID.map { key, value in
            (Int(key), value)
        })
        let normalizedShioris = Dictionary(
            uniqueKeysWithValues: resolvedShiorisByID.map { key, value in
                (Int(key), value)
            }
        )
        let contentChanged = relations != snapshot.shioriRelations
            || normalizedTags != snapshot.shioriTagsByEntryID
            || normalizedShioris != snapshot.shiorisByEntryID
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
            shiorisByEntryID: normalizedShioris,
            shioriRelations: relations,
            shioriTagsByEntryID: normalizedTags,
            cueContentProvider: cueContentProvider,
            cueContentRevision: referencedCueContentRevision,
            version: snapshot.version + 1,
            update: update,
            totalRowCount: relations.count
        ), tableName: tableName,
           probeSurface: probeSurface ?? SubtitleTableProbeSurface(tableName: tableName),
           probeScope: probeScope,
           reason: "shiori_resident_projection")
    }

    func removeResidentShiori(
        id: Int64,
        tableName: String,
        probeSurface: SubtitleTableProbeSurface? = nil,
        probeScope: String? = nil
    ) {
        guard snapshot.shioriRelations.contains(where: { $0.id == id }) else {
            return
        }
        let relations = snapshot.shioriRelations.filter { $0.id != id }
        var tags = snapshot.shioriTagsByEntryID
        tags[Int(id)] = nil
        publishSnapshot(TableSandboxRowsSnapshot(
            shiorisByEntryID: snapshot.shiorisByEntryID.filter { $0.key != Int(id) },
            shioriRelations: relations,
            shioriTagsByEntryID: tags,
            cueContentProvider: snapshot.cueContentProvider,
            cueContentRevision: snapshot.cueContentRevision,
            version: snapshot.version + 1,
            update: .reload,
            totalRowCount: relations.count
        ), tableName: tableName,
           probeSurface: probeSurface ?? SubtitleTableProbeSurface(tableName: tableName),
           probeScope: probeScope,
           reason: "shiori_remove")
    }

    private func acknowledgeCueContentRevision(_ revision: UInt64) {
        guard revision > observedCueContentRevision else {
            return
        }
        observedCueContentRevision = revision
        referencedCueContentRevision &+= 1
    }

    func hydrateShioriRows(
        _ shioris: [TableSandboxShioriRowSource],
        startIndex: Int,
        totalRowCount: Int,
        tableName: String,
        probeSurface: SubtitleTableProbeSurface? = nil,
        probeScope: String? = nil
    ) {
        guard startIndex >= 0 else { return }
        guard startIndex <= snapshot.materializedRows.count else { return }

        if shioris.isEmpty {
            guard totalRowCount == 0 else { return }
            let previousVersion = snapshot.version
            let resolvedProbeSurface = probeSurface
                ?? SubtitleTableProbeSurface(tableName: tableName)
            updateShioriRows(
                [],
                tableName: tableName,
                probeSurface: resolvedProbeSurface,
                probeScope: probeScope
            )
            if snapshot.version != previousVersion {
                UIInvalidationProbe.count(
                    resolvedProbeSurface.counterName("row_hydration_applied"),
                    scope: probeScope,
                    details: "table=\(tableName) reason=shiori_empty"
                )
            }
            return
        }

        var nextRows = snapshot.materializedRows
        var nextShiorisByEntryID = snapshot.shiorisByEntryID
        var nextCuePresentationsByEntryID = snapshot.shioriCuePresentationsByEntryID
        let oldRowCount = nextRows.count
        var lowerChangedIndex: Int?
        var upperChangedIndex: Int?
        var actionCacheChanged = false

        for (offset, item) in shioris.enumerated() {
            let sourceIndex = startIndex + offset
            let row = shioriRow(for: item)
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
            if nextShiorisByEntryID[Int(item.shiori.id)] != item.shiori {
                actionCacheChanged = true
                nextShiorisByEntryID[Int(item.shiori.id)] = item.shiori
            }
            if nextCuePresentationsByEntryID[Int(item.shiori.id)] != item.cuePresentation {
                actionCacheChanged = true
                nextCuePresentationsByEntryID[Int(item.shiori.id)] = item.cuePresentation
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
            shiorisByEntryID: nextShiorisByEntryID,
            shioriCuePresentationsByEntryID: nextCuePresentationsByEntryID,
            version: snapshot.version + 1,
            update: update,
            totalRowCount: nextRows.count
        ), tableName: tableName,
           probeSurface: probeSurface ?? SubtitleTableProbeSurface(tableName: tableName),
           probeScope: probeScope,
           reason: "shiori_hydration",
           isHydration: true)
    }

    @discardableResult
    func updateShioriTags(
        _ tags: [ShioriTag],
        forShioriID shioriID: Int64,
        tableName: String,
        probeSurface: SubtitleTableProbeSurface? = nil,
        probeScope: String? = nil
    ) -> Bool {
        if let rowIndex = snapshot.shioriRelationIndexByEntryID[Int(shioriID)] {
            guard snapshot.shioriTagsByEntryID[Int(shioriID)] != tags else {
                return false
            }
            var nextTags = snapshot.shioriTagsByEntryID
            nextTags[Int(shioriID)] = tags
            publishSnapshot(TableSandboxRowsSnapshot(
                shioriRelations: snapshot.shioriRelations,
                shioriTagsByEntryID: nextTags,
                cueContentProvider: snapshot.cueContentProvider,
                cueContentRevision: snapshot.cueContentRevision,
                version: snapshot.version + 1,
                update: .cells([
                    TableSandboxCellInvalidation(row: rowIndex, columnID: "tags")
                ]),
                totalRowCount: snapshot.totalRowCount
            ), tableName: tableName,
               probeSurface: probeSurface ?? SubtitleTableProbeSurface(tableName: tableName),
               probeScope: probeScope,
               reason: "shiori_tag_update")
            return true
        }

        guard let rowIndex = snapshot.materializedRows.firstIndex(where: {
            $0.id == Int(shioriID)
        }) else {
            return false
        }

        let nextRow = snapshot.materializedRows[rowIndex].replacingShioriTags(
            tableSandboxShioriTags(for: tags)
        )
        guard nextRow != snapshot.materializedRows[rowIndex] else {
            return false
        }

        var nextRows = snapshot.materializedRows
        nextRows[rowIndex] = nextRow
        publishSnapshot(TableSandboxRowsSnapshot(
            rows: nextRows,
            searchResultsByEntryID: snapshot.searchResultsByEntryID,
            shiorisByEntryID: snapshot.shiorisByEntryID,
            shioriCuePresentationsByEntryID: snapshot.shioriCuePresentationsByEntryID,
            version: snapshot.version + 1,
            update: .cells([TableSandboxCellInvalidation(row: rowIndex, columnID: "tags")]),
            totalRowCount: snapshot.totalRowCount
        ), tableName: tableName,
           probeSurface: probeSurface ?? SubtitleTableProbeSurface(tableName: tableName),
           probeScope: probeScope,
           reason: "shiori_tag_update")
        return true
    }

    @discardableResult
    func removeShioriTagFromVisibleRows(
        tagID: Int64,
        affectedShioriIDs: [Int64],
        tableName: String,
        probeSurface: SubtitleTableProbeSurface? = nil,
        probeScope: String? = nil
    ) -> [Int64] {
        let tagKey = String(tagID)
        let affectedIDs = Set(affectedShioriIDs.map(Int.init))
        var invalidations: [TableSandboxCellInvalidation] = []
        var patchedIDs: [Int64] = []

        if !snapshot.shioriRelations.isEmpty {
            var nextTagsByEntryID = snapshot.shioriTagsByEntryID
            for shioriID in affectedIDs {
                guard let rowIndex = snapshot.shioriRelationIndexByEntryID[shioriID],
                      let tags = nextTagsByEntryID[shioriID],
                      tags.contains(where: { String($0.id) == tagKey })
                else {
                    continue
                }
                nextTagsByEntryID[shioriID] = tags.filter { String($0.id) != tagKey }
                invalidations.append(
                    TableSandboxCellInvalidation(row: rowIndex, columnID: "tags")
                )
                patchedIDs.append(Int64(shioriID))
            }

            guard !invalidations.isEmpty else { return [] }
            publishSnapshot(TableSandboxRowsSnapshot(
                shioriRelations: snapshot.shioriRelations,
                shioriTagsByEntryID: nextTagsByEntryID,
                cueContentProvider: snapshot.cueContentProvider,
                cueContentRevision: snapshot.cueContentRevision,
                version: snapshot.version + 1,
                update: .cells(invalidations),
                totalRowCount: snapshot.totalRowCount
            ), tableName: tableName,
               probeSurface: probeSurface ?? SubtitleTableProbeSurface(tableName: tableName),
               probeScope: probeScope,
               reason: "shiori_tag_delete")
            return patchedIDs
        }

        var nextRows = snapshot.materializedRows

        for (index, row) in snapshot.materializedRows.enumerated()
        where affectedIDs.contains(row.id) && row.shioriTags.contains(where: { $0.key == tagKey }) {
            let nextTags = row.shioriTags.filter { $0.key != tagKey }
            nextRows[index] = row.replacingShioriTags(nextTags)
            invalidations.append(TableSandboxCellInvalidation(row: index, columnID: "tags"))
            patchedIDs.append(Int64(row.id))
        }

        guard !invalidations.isEmpty else {
            return []
        }

        publishSnapshot(TableSandboxRowsSnapshot(
            rows: nextRows,
            searchResultsByEntryID: snapshot.searchResultsByEntryID,
            shiorisByEntryID: snapshot.shiorisByEntryID,
            shioriCuePresentationsByEntryID: snapshot.shioriCuePresentationsByEntryID,
            version: snapshot.version + 1,
            update: .cells(invalidations),
            totalRowCount: snapshot.totalRowCount
        ), tableName: tableName,
           probeSurface: probeSurface ?? SubtitleTableProbeSurface(tableName: tableName),
           probeScope: probeScope,
           reason: "shiori_tag_delete")
        return patchedIDs
    }

    private func apply(
        _ rows: [SubtitleTableRow],
        searchResultsByEntryID: [Int: SubtitleSearchResult],
        shiorisByEntryID: [Int: Shiori],
        shioriCuePresentationsByEntryID: [Int: ShioriCuePresentation] = [:],
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
            || shiorisByEntryID != snapshot.shiorisByEntryID
            || shioriCuePresentationsByEntryID
                != snapshot.shioriCuePresentationsByEntryID
        let update = rowsUpdate == .none && metadataChanged ? .reload : rowsUpdate
        let changed = update != .none || metadataChanged || actionCacheChanged

        guard changed else {
            return
        }

        publishSnapshot(TableSandboxRowsSnapshot(
            rows: rows,
            searchResultsByEntryID: searchResultsByEntryID,
            shiorisByEntryID: shiorisByEntryID,
            shioriCuePresentationsByEntryID: shioriCuePresentationsByEntryID,
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
        let displayTitle = searchDisplayTitle(for: result)
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

    private func shioriRow(for item: TableSandboxShioriRowSource) -> SubtitleTableRow {
        let cuePresentation = item.cuePresentation
        return SubtitleTableRow(
            id: Int(item.shiori.id),
            primaryCueID: cuePresentation?.cueID,
            subtitlePath: item.shiori.subtitlePath,
            dateAdded: item.dateAddedText,
            displayTitle: item.displayTitle,
            startTime: tableSandboxCueTimeText(milliseconds: item.shiori.startMilliseconds),
            endTime: tableSandboxCueTimeText(milliseconds: item.shiori.endMilliseconds),
            timeRange: item.shiori.timeRange,
            primaryCueText: item.shiori.content,
            cueGroupTexts: cuePresentation?.cueGroupTexts ?? [item.shiori.content],
            primaryGroupIndex: cuePresentation?.primaryGroupIndex,
            tags: SubtitleLanguageWorkbenchTags.tags(
                for: cuePresentation?.languages ?? item.languages
            ),
            shioriTags: tableSandboxShioriTags(for: item.shioriTags),
            cueState: tableSandboxCueState(for: item.shiori)
        )
    }

    private func searchDisplayTitle(for result: SubtitleSearchResult) -> String {
        guard !result.displayTitle.isEmpty else {
            return displayTitle(forSubtitlePath: result.subtitlePath)
        }

        return result.displayTitle
    }

    private func displayTitle(forSubtitlePath subtitlePath: String) -> String {
        if let cached = displayTitlesBySubtitlePath[subtitlePath] {
            return cached
        }

        let title = displayTitleResolver(subtitlePath)
        displayTitlesBySubtitlePath[subtitlePath] = title
        return title
    }
}

func tableSandboxSearchRow(for result: SubtitleSearchResult) -> SubtitleTableRow {
    let displayTitle = result.displayTitle.isEmpty
        ? SubtitleDisplayTitleResolver.displayTitle(forSubtitlePath: result.subtitlePath)
        : result.displayTitle
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

func tableSandboxShioriRow(for item: TableSandboxShioriRowSource) -> SubtitleTableRow {
    let cuePresentation = item.cuePresentation
    return SubtitleTableRow(
        id: Int(item.shiori.id),
        primaryCueID: cuePresentation?.cueID,
        subtitlePath: item.shiori.subtitlePath,
        dateAdded: item.dateAddedText,
        displayTitle: item.displayTitle,
        startTime: tableSandboxCueTimeText(milliseconds: item.shiori.startMilliseconds),
        endTime: tableSandboxCueTimeText(milliseconds: item.shiori.endMilliseconds),
        timeRange: item.shiori.timeRange,
        primaryCueText: item.shiori.content,
        cueGroupTexts: cuePresentation?.cueGroupTexts ?? [item.shiori.content],
        primaryGroupIndex: cuePresentation?.primaryGroupIndex,
        tags: SubtitleLanguageWorkbenchTags.tags(
            for: cuePresentation?.languages ?? item.languages
        ),
        shioriTags: tableSandboxShioriTags(for: item.shioriTags),
        cueState: tableSandboxCueState(for: item.shiori)
    )
}

private func tableSandboxShioriRow(
    relation: ShioriRelation,
    cueContent: CueContent,
    resolvedShiori: Shiori?,
    shioriTags: [ShioriTag]
) -> SubtitleTableRow {
    SubtitleTableRow(
        id: Int(relation.id),
        primaryCueID: cueContent.cueID,
        subtitlePath: cueContent.subtitlePath,
        dateAdded: tableSandboxShioriDateAddedDisplayText(for: relation.createdAt),
        displayTitle: cueContent.displayTitle,
        startTime: tableSandboxCueTimeText(milliseconds: cueContent.startMilliseconds),
        endTime: tableSandboxCueTimeText(milliseconds: cueContent.endMilliseconds),
        timeRange: cueContent.timeRange,
        primaryCueText: cueContent.content,
        cueGroupTexts: cueContent.cueGroupLines,
        primaryGroupIndex: cueContent.primaryGroupIndex,
        tags: SubtitleLanguageWorkbenchTags.tags(for: cueContent.languages),
        shioriTags: tableSandboxShioriTags(for: shioriTags),
        cueState: resolvedShiori.map(tableSandboxCueState(for:)) ?? .normal
    )
}

private func tableSandboxUnavailableShioriRow(
    relation: ShioriRelation,
    shiori: Shiori,
    shioriTags: [ShioriTag]
) -> SubtitleTableRow {
    let cueGroupTexts = tableSandboxCueGroupSnapshotTexts(shiori.cueGroupContent)
    return SubtitleTableRow(
        id: Int(relation.id),
        primaryCueID: relation.cueID,
        subtitlePath: shiori.subtitlePath,
        dateAdded: tableSandboxShioriDateAddedDisplayText(for: relation.createdAt),
        displayTitle: shiori.displayTitle,
        startTime: tableSandboxCueTimeText(milliseconds: shiori.startMilliseconds),
        endTime: tableSandboxCueTimeText(milliseconds: shiori.endMilliseconds),
        timeRange: shiori.timeRange,
        primaryCueText: shiori.content,
        cueGroupTexts: cueGroupTexts.isEmpty ? [shiori.content] : cueGroupTexts,
        primaryGroupIndex: cueGroupTexts.firstIndex(of: shiori.content) ?? 0,
        shioriTags: tableSandboxShioriTags(for: shioriTags),
        cueState: tableSandboxCueState(for: shiori)
    )
}

private func tableSandboxCueState(for shiori: Shiori) -> SubtitleTableCueState {
    if let unavailableReason = shiori.unavailableReason {
        return .unavailable(unavailableReason)
    }
    if let change = shiori.contentChange {
        return .contentChanged(
            previous: change.previousContent,
            current: change.currentContent
        )
    }
    return .normal
}

private func tableSandboxCueGroupSnapshotTexts(_ content: String) -> [String] {
    let separator = Shiori.cueGroupContentSeparator
    guard content.contains(separator) else {
        return content.isEmpty ? [] : [content]
    }
    return content
        .components(separatedBy: separator)
        .filter { !$0.isEmpty }
}

func tableSandboxShioriDateAddedDisplayText(
    for value: String,
    timeZone: TimeZone = .current
) -> String {
    let isoFormatter = ISO8601DateFormatter()
    guard let date = isoFormatter.date(from: value) else {
        return value
    }

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

private func tableSandboxShioriTags(for tags: [ShioriTag]) -> [WorkbenchTag] {
    tags.map { tag in
        WorkbenchTag(key: String(tag.id), label: tag.name, colorID: .gray)
    }
}
