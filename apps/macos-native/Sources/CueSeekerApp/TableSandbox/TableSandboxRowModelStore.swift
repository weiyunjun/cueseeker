import Combine
import Foundation
import CueSeekerCore

struct TableSandboxRowsSnapshot {
    var rows: [SubtitleTableRow] = []
    var rowsBySourceIndex: [Int: SubtitleTableRow] = [:]
    var searchResultsByEntryID: [Int: SubtitleSearchResult] = [:]
    var version = 0
    var update = TableSandboxRowsUpdate.none
    var references: [TableSandboxRowReference] = []
    var totalRowCount = 0

    var loadedReferenceCount: Int {
        references.count
    }

    func row(at index: Int) -> SubtitleTableRow? {
        rowsBySourceIndex[index]
    }

    func searchResult(entryID: Int) -> SubtitleSearchResult? {
        searchResultsByEntryID[entryID]
    }
}

struct TableSandboxRowReference: Equatable {
    enum Source: Equatable {
        case search
        case shiori
    }

    let source: Source
    let sourceIndex: Int
    let id: Int
}

@MainActor
final class TableSandboxRowModelStore: ObservableObject {
    static let defaultMaximumHydratedSearchRows = 2_000

    @Published private(set) var snapshot = TableSandboxRowsSnapshot()

    private var rowsByKey: [RowCacheKey: SubtitleTableRow] = [:]
    private var displayTitlesBySubtitlePath: [String: String] = [:]
    private let displayTitleResolver: (String) -> String
    private let maximumHydratedSearchRows: Int

    init(
        maximumHydratedSearchRows: Int = defaultMaximumHydratedSearchRows,
        displayTitleResolver: @escaping (String) -> String = {
            SubtitleDisplayTitleResolver.displayTitle(forSubtitlePath: $0)
        }
    ) {
        self.maximumHydratedSearchRows = max(1, maximumHydratedSearchRows)
        self.displayTitleResolver = displayTitleResolver
    }

    func updateSearchRows(
        _ results: [SubtitleSearchResult],
        totalRowCount: Int? = nil,
        tableName: String
    ) {
        let start = TableRenderingPerformanceLogger.now()
        var nextRowsByKey: [RowCacheKey: SubtitleTableRow] = [:]
        nextRowsByKey.reserveCapacity(results.count)
        var prefixUnchanged = results.count >= snapshot.rows.count
        let references = results.enumerated().map { index, result in
            TableSandboxRowReference(source: .search, sourceIndex: index, id: Int(result.entryID))
        }

        let rows = results.enumerated().map { index, result in
            let displayTitle = searchDisplayTitle(for: result)
            let key = RowCacheKey(
                id: Int(result.entryID),
                subtitlePath: result.subtitlePath,
                displayTitle: displayTitle,
                content: result.content,
                cueLines: result.cueLines,
                languages: result.languages,
                speakers: result.speakers
            )

            if let cached = rowsByKey[key] {
                nextRowsByKey[key] = cached
                if index < snapshot.rows.count, cached.id != snapshot.rows[index].id {
                    prefixUnchanged = false
                }
                return cached
            }

            if index < snapshot.rows.count {
                prefixUnchanged = false
            }
            let row = SubtitleTableRow(
                id: key.id,
                displayTitle: displayTitle,
                cues: tableSandboxDisplayText(
                    content: result.content,
                    cueLines: result.cueLines
                ),
                tags: SubtitleLanguageWorkbenchTags.tags(for: result.languages),
                speakerTags: tableSandboxSpeakerTags(for: result.speakers)
            )
            nextRowsByKey[key] = row
            return row
        }
        let rowsBySourceIndex = Dictionary(uniqueKeysWithValues: rows.enumerated().map { index, row in
            (index, row)
        })
        let searchResultsByEntryID = Dictionary(uniqueKeysWithValues: results.map { result in
            (Int(result.entryID), result)
        })

        apply(
            rows,
            rowsBySourceIndex: rowsBySourceIndex,
            searchResultsByEntryID: searchResultsByEntryID,
            references: references,
            totalRowCount: max(totalRowCount ?? results.count, results.count),
            nextRowsByKey: nextRowsByKey,
            tableName: tableName,
            sourceCount: results.count,
            prefixUnchanged: prefixUnchanged,
            start: start
        )
    }

    func hydrateSearchRows(
        _ results: [SubtitleSearchResult],
        startIndex: Int,
        totalRowCount: Int,
        tableName: String
    ) {
        guard startIndex >= 0, !results.isEmpty else { return }

        let start = TableRenderingPerformanceLogger.now()
        var nextRowsBySourceIndex = snapshot.rowsBySourceIndex
        var nextSearchResultsByEntryID = snapshot.searchResultsByEntryID
        var referencesBySourceIndex = Dictionary(uniqueKeysWithValues: snapshot.references.map { reference in
            (reference.sourceIndex, reference)
        })
        var lowerChangedIndex: Int?
        var upperChangedIndex: Int?

        for (offset, result) in results.enumerated() {
            let sourceIndex = startIndex + offset
            let row = searchRow(for: result)
            if nextRowsBySourceIndex[sourceIndex] != row {
                lowerChangedIndex = min(lowerChangedIndex ?? sourceIndex, sourceIndex)
                upperChangedIndex = max(upperChangedIndex ?? sourceIndex + 1, sourceIndex + 1)
            }
            nextRowsBySourceIndex[sourceIndex] = row
            nextSearchResultsByEntryID[Int(result.entryID)] = result
            referencesBySourceIndex[sourceIndex] = TableSandboxRowReference(
                source: .search,
                sourceIndex: sourceIndex,
                id: Int(result.entryID)
            )
        }

        guard let lowerChangedIndex, let upperChangedIndex else { return }

        let hydratedRange = startIndex..<(startIndex + results.count)
        pruneHydratedSearchRowsIfNeeded(
            keepingPriorityRange: hydratedRange,
            rowsBySourceIndex: &nextRowsBySourceIndex,
            searchResultsByEntryID: &nextSearchResultsByEntryID,
            referencesBySourceIndex: &referencesBySourceIndex
        )

        let references = referencesBySourceIndex.values.sorted { lhs, rhs in
            lhs.sourceIndex < rhs.sourceIndex
        }
        let resolvedTotalRowCount = max(snapshot.totalRowCount, totalRowCount, (references.last?.sourceIndex ?? -1) + 1)
        let update: TableSandboxRowsUpdate = .append(lowerChangedIndex..<upperChangedIndex)
        TableRenderingPerformanceLogger.record(
            event: "rows_hydrated",
            table: tableName,
            reason: update.reason,
            elapsedMilliseconds: TableRenderingPerformanceLogger.elapsedMilliseconds(since: start),
            rowCount: resolvedTotalRowCount,
            sourceCount: results.count,
            changed: true
        )

        snapshot = TableSandboxRowsSnapshot(
            rows: contiguousPrefixRows(from: nextRowsBySourceIndex),
            rowsBySourceIndex: nextRowsBySourceIndex,
            searchResultsByEntryID: nextSearchResultsByEntryID,
            version: snapshot.version + 1,
            update: update,
            references: references,
            totalRowCount: resolvedTotalRowCount
        )
    }

    func updateShioriRows(_ shioris: [Shiori], tableName: String) {
        let start = TableRenderingPerformanceLogger.now()
        var nextRowsByKey: [RowCacheKey: SubtitleTableRow] = [:]
        nextRowsByKey.reserveCapacity(shioris.count)
        var prefixUnchanged = shioris.count >= snapshot.rows.count
        let references = shioris.enumerated().map { index, item in
            TableSandboxRowReference(source: .shiori, sourceIndex: index, id: Int(item.id))
        }

        let rows = shioris.enumerated().map { index, item in
            let displayTitle = displayTitle(forSubtitlePath: item.subtitlePath)
            let key = RowCacheKey(
                id: Int(item.id),
                subtitlePath: item.subtitlePath,
                displayTitle: displayTitle,
                content: item.content,
                cueLines: item.cueLines,
                languages: [],
                speakers: []
            )

            if let cached = rowsByKey[key] {
                nextRowsByKey[key] = cached
                if index < snapshot.rows.count, cached.id != snapshot.rows[index].id {
                    prefixUnchanged = false
                }
                return cached
            }

            if index < snapshot.rows.count {
                prefixUnchanged = false
            }
            let row = SubtitleTableRow(
                id: key.id,
                displayTitle: displayTitle,
                cues: tableSandboxDisplayText(
                    content: item.content,
                    cueLines: item.cueLines
                )
            )
            nextRowsByKey[key] = row
            return row
        }
        let rowsBySourceIndex = Dictionary(uniqueKeysWithValues: rows.enumerated().map { index, row in
            (index, row)
        })

        apply(
            rows,
            rowsBySourceIndex: rowsBySourceIndex,
            searchResultsByEntryID: [:],
            references: references,
            totalRowCount: shioris.count,
            nextRowsByKey: nextRowsByKey,
            tableName: tableName,
            sourceCount: shioris.count,
            prefixUnchanged: prefixUnchanged,
            start: start
        )
    }

    private func apply(
        _ rows: [SubtitleTableRow],
        rowsBySourceIndex: [Int: SubtitleTableRow],
        searchResultsByEntryID: [Int: SubtitleSearchResult],
        references: [TableSandboxRowReference],
        totalRowCount: Int,
        nextRowsByKey: [RowCacheKey: SubtitleTableRow],
        tableName: String,
        sourceCount: Int,
        prefixUnchanged: Bool,
        start: UInt64
    ) {
        let rowsUpdate = rowsUpdate(for: rows, prefixUnchanged: prefixUnchanged)
        let metadataChanged = references != snapshot.references
            || totalRowCount != snapshot.totalRowCount
        let update = rowsUpdate == .none && metadataChanged ? .reload : rowsUpdate
        let changed = update != .none || metadataChanged
        rowsByKey = nextRowsByKey
        TableRenderingPerformanceLogger.record(
            event: "rows_mapped",
            table: tableName,
            reason: update.reason,
            elapsedMilliseconds: TableRenderingPerformanceLogger.elapsedMilliseconds(since: start),
            rowCount: rows.count,
            sourceCount: sourceCount,
            changed: changed
        )

        guard changed else {
            return
        }

        snapshot = TableSandboxRowsSnapshot(
            rows: rows,
            rowsBySourceIndex: rowsBySourceIndex,
            searchResultsByEntryID: searchResultsByEntryID,
            version: snapshot.version + 1,
            update: update,
            references: references,
            totalRowCount: totalRowCount
        )
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
        let key = RowCacheKey(
            id: Int(result.entryID),
            subtitlePath: result.subtitlePath,
            displayTitle: displayTitle,
            content: result.content,
            cueLines: result.cueLines,
            languages: result.languages,
            speakers: result.speakers
        )

        if let cached = rowsByKey[key] {
            return cached
        }

        let row = SubtitleTableRow(
            id: key.id,
            displayTitle: displayTitle,
            cues: tableSandboxDisplayText(
                content: result.content,
                cueLines: result.cueLines
            ),
            tags: SubtitleLanguageWorkbenchTags.tags(for: result.languages),
            speakerTags: tableSandboxSpeakerTags(for: result.speakers)
        )
        rowsByKey[key] = row
        return row
    }

    private func searchDisplayTitle(for result: SubtitleSearchResult) -> String {
        guard !result.displayTitle.isEmpty else {
            return displayTitle(forSubtitlePath: result.subtitlePath)
        }

        return result.displayTitle
    }

    private func pruneHydratedSearchRowsIfNeeded(
        keepingPriorityRange priorityRange: Range<Int>,
        rowsBySourceIndex: inout [Int: SubtitleTableRow],
        searchResultsByEntryID: inout [Int: SubtitleSearchResult],
        referencesBySourceIndex: inout [Int: TableSandboxRowReference]
    ) {
        guard rowsBySourceIndex.count > maximumHydratedSearchRows else {
            return
        }

        let center = priorityRange.lowerBound + max(0, priorityRange.count / 2)
        let keptIndexes = Set(rowsBySourceIndex.keys.sorted { lhs, rhs in
            let lhsPriority = priorityRange.contains(lhs)
            let rhsPriority = priorityRange.contains(rhs)
            if lhsPriority != rhsPriority {
                return lhsPriority
            }

            let lhsDistance = abs(lhs - center)
            let rhsDistance = abs(rhs - center)
            if lhsDistance != rhsDistance {
                return lhsDistance < rhsDistance
            }

            return lhs < rhs
        }.prefix(maximumHydratedSearchRows))

        rowsBySourceIndex = rowsBySourceIndex.filter { keptIndexes.contains($0.key) }
        referencesBySourceIndex = referencesBySourceIndex.filter { keptIndexes.contains($0.key) }
        let keptEntryIDs = Set(referencesBySourceIndex.values.map(\.id))
        searchResultsByEntryID = searchResultsByEntryID.filter { keptEntryIDs.contains($0.key) }
    }

    private func contiguousPrefixRows(from rowsBySourceIndex: [Int: SubtitleTableRow]) -> [SubtitleTableRow] {
        var rows: [SubtitleTableRow] = []
        var index = 0
        while let row = rowsBySourceIndex[index] {
            rows.append(row)
            index += 1
        }
        return rows
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

private struct RowCacheKey: Hashable {
    let id: Int
    let subtitlePath: String
    let displayTitle: String
    let content: String
    let cueLines: [String]
    let languages: Set<SubtitleLanguageCode>
    let speakers: Set<String>
}

enum TableSandboxDisplayTextBudget {
    static let maximumLines = 6
    static let maximumCharactersPerLine = 500
}

private func tableSandboxDisplayText(content: String, cueLines: [String]) -> String {
    subtitleDisplayLines(content: content, cueLines: cueLines)
        .prefix(TableSandboxDisplayTextBudget.maximumLines)
        .map(truncateTableSandboxDisplayLine)
        .joined(separator: "\n")
}

private func tableSandboxSpeakerTags(for speakers: Set<String>) -> [WorkbenchTag] {
    speakers
        .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        .sorted()
        .map { WorkbenchTag(key: $0, colorID: .purple) }
}

private func truncateTableSandboxDisplayLine(_ line: String) -> String {
    guard line.count > TableSandboxDisplayTextBudget.maximumCharactersPerLine else {
        return line
    }

    let end = line.index(
        line.startIndex,
        offsetBy: TableSandboxDisplayTextBudget.maximumCharactersPerLine,
        limitedBy: line.endIndex
    ) ?? line.endIndex
    return String(line[..<end]) + "..."
}
