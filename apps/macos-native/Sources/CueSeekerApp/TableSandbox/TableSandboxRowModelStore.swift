import Combine
import Foundation
import CueSeekerCore

struct TableSandboxRowsSnapshot {
    var rows: [SubtitleTableRow] = []
    var searchResultsByEntryID: [Int: SubtitleSearchResult] = [:]
    var shiorisByEntryID: [Int: Shiori] = [:]
    var version = 0
    var update = TableSandboxRowsUpdate.none
    var totalRowCount = 0

    var loadedReferenceCount: Int {
        rows.count
    }

    func row(at index: Int) -> SubtitleTableRow? {
        guard index >= 0, index < rows.count else { return nil }
        return rows[index]
    }

    func searchResult(entryID: Int) -> SubtitleSearchResult? {
        searchResultsByEntryID[entryID]
    }

    func shiori(entryID: Int) -> Shiori? {
        shiorisByEntryID[entryID]
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
    private let displayTitleResolver: (String) -> String

    init(
        displayTitleResolver: @escaping (String) -> String = {
            SubtitleDisplayTitleResolver.displayTitle(forSubtitlePath: $0)
        }
    ) {
        self.displayTitleResolver = displayTitleResolver
    }

    func updateSearchRows(
        _ results: [SubtitleSearchResult],
        totalRowCount: Int? = nil,
        tableName: String,
        probeSurface: SubtitleTableProbeSurface? = nil,
        probeScope: String? = nil,
        isHydration: Bool = false
    ) {
        var prefixUnchanged = results.count >= snapshot.rows.count
        let rows = results.enumerated().map { index, result in
            let row = searchRow(for: result)
            if index < snapshot.rows.count, row != snapshot.rows[index] {
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
        guard startIndex <= snapshot.rows.count else { return }

        var nextRows = snapshot.rows
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
        let existingEntryIDs = Set(snapshot.rows.map(\.id))
        let prependedResults = results.filter { !existingEntryIDs.contains(Int($0.entryID)) }
        guard !prependedResults.isEmpty else { return 0 }

        var nextSearchResultsByEntryID = snapshot.searchResultsByEntryID
        prependedResults.forEach { result in
            nextSearchResultsByEntryID[Int(result.entryID)] = result
        }

        publishSnapshot(TableSandboxRowsSnapshot(
            rows: prependedResults.map { searchRow(for: $0) } + snapshot.rows,
            searchResultsByEntryID: nextSearchResultsByEntryID,
            shiorisByEntryID: snapshot.shiorisByEntryID,
            version: snapshot.version + 1,
            update: .reload,
            totalRowCount: snapshot.rows.count + prependedResults.count
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
        let existingEntryIDs = Set(snapshot.rows.map(\.id))
        let appendedResults = results.filter { !existingEntryIDs.contains(Int($0.entryID)) }
        guard !appendedResults.isEmpty else { return 0 }

        var nextSearchResultsByEntryID = snapshot.searchResultsByEntryID
        appendedResults.forEach { result in
            nextSearchResultsByEntryID[Int(result.entryID)] = result
        }

        let oldRowCount = snapshot.rows.count
        let nextRows = snapshot.rows + appendedResults.map { searchRow(for: $0) }
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
        var prefixUnchanged = shioris.count >= snapshot.rows.count
        let rows = shioris.enumerated().map { index, item in
            let row = shioriRow(for: item)
            if index < snapshot.rows.count, row != snapshot.rows[index] {
                prefixUnchanged = false
            }
            return row
        }
        let shiorisByEntryID = Dictionary(uniqueKeysWithValues: shioris.map { item in
            (Int(item.shiori.id), item.shiori)
        })

        apply(
            rows,
            searchResultsByEntryID: [:],
            shiorisByEntryID: shiorisByEntryID,
            totalRowCount: shioris.count,
            prefixUnchanged: prefixUnchanged,
            tableName: tableName,
            probeSurface: probeSurface ?? SubtitleTableProbeSurface(tableName: tableName),
            probeScope: probeScope,
            reason: "shiori_update"
        )
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
        guard startIndex <= snapshot.rows.count else { return }

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

        var nextRows = snapshot.rows
        var nextShiorisByEntryID = snapshot.shiorisByEntryID
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
        guard let rowIndex = snapshot.rows.firstIndex(where: { $0.id == Int(shioriID) }) else {
            return false
        }

        let nextRow = snapshot.rows[rowIndex].replacingShioriTags(
            tableSandboxShioriTags(for: tags)
        )
        guard nextRow != snapshot.rows[rowIndex] else {
            return false
        }

        var nextRows = snapshot.rows
        nextRows[rowIndex] = nextRow
        publishSnapshot(TableSandboxRowsSnapshot(
            rows: nextRows,
            searchResultsByEntryID: snapshot.searchResultsByEntryID,
            shiorisByEntryID: snapshot.shiorisByEntryID,
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
        var nextRows = snapshot.rows
        var invalidations: [TableSandboxCellInvalidation] = []
        var patchedIDs: [Int64] = []

        for (index, row) in snapshot.rows.enumerated()
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
        let update = rowsUpdate == .none && metadataChanged ? .reload : rowsUpdate
        let changed = update != .none || metadataChanged || actionCacheChanged

        guard changed else {
            return
        }

        publishSnapshot(TableSandboxRowsSnapshot(
            rows: rows,
            searchResultsByEntryID: searchResultsByEntryID,
            shiorisByEntryID: shiorisByEntryID,
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
        if rows.count == snapshot.rows.count, prefixUnchanged {
            return .none
        }

        if rows.count > snapshot.rows.count, prefixUnchanged {
            return .append(snapshot.rows.count..<rows.count)
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
            tags: SubtitleLanguageWorkbenchTags.tags(for: result.languages),
            speakerTags: tableSandboxSpeakerTags(for: result.speakers)
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
            speakerTags: tableSandboxSpeakerTags(for: cuePresentation?.speakers ?? []),
            shioriTags: tableSandboxShioriTags(for: item.shioriTags)
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
        tags: SubtitleLanguageWorkbenchTags.tags(for: result.languages),
        speakerTags: tableSandboxSpeakerTags(for: result.speakers)
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
        speakerTags: tableSandboxSpeakerTags(for: cuePresentation?.speakers ?? []),
        shioriTags: tableSandboxShioriTags(for: item.shioriTags)
    )
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

private func tableSandboxSpeakerTags(for speakers: Set<String>) -> [WorkbenchTag] {
    speakers
        .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        .sorted()
        .map { WorkbenchTag(key: $0, colorID: .purple) }
}

private func tableSandboxShioriTags(for tags: [ShioriTag]) -> [WorkbenchTag] {
    tags.map { tag in
        WorkbenchTag(key: String(tag.id), label: tag.name, colorID: .gray)
    }
}
