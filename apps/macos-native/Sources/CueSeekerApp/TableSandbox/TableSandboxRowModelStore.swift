import Combine
import Foundation
import CueSeekerCore

struct TableSandboxRowsSnapshot {
    var rows: [SubtitleTableRow] = []
    var rowsBySourceIndex: [Int: SubtitleTableRow] = [:]
    var searchResultsByEntryID: [Int: SubtitleSearchResult] = [:]
    var shiorisByEntryID: [Int: Shiori] = [:]
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

    func shiori(entryID: Int) -> Shiori? {
        shiorisByEntryID[entryID]
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

struct TableSandboxShioriRowSource: Equatable, Sendable {
    let shiori: Shiori
    let displayTitle: String
    let dateAddedText: String
    let languages: Set<SubtitleLanguageCode>
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
        tableName _: String
    ) {
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
                dateAdded: "",
                displayTitle: displayTitle,
                startTime: tableSandboxCueTimeText(milliseconds: result.startMilliseconds),
                endTime: tableSandboxCueTimeText(milliseconds: result.endMilliseconds),
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
                startTime: key.startTime,
                endTime: key.endTime,
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
            shiorisByEntryID: [:],
            references: references,
            totalRowCount: max(totalRowCount ?? results.count, results.count),
            nextRowsByKey: nextRowsByKey,
            prefixUnchanged: prefixUnchanged
        )
    }

    func hydrateSearchRows(
        _ results: [SubtitleSearchResult],
        startIndex: Int,
        totalRowCount: Int,
        tableName _: String
    ) {
        guard startIndex >= 0, !results.isEmpty else { return }

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

        snapshot = TableSandboxRowsSnapshot(
            rows: contiguousPrefixRows(from: nextRowsBySourceIndex),
            rowsBySourceIndex: nextRowsBySourceIndex,
            searchResultsByEntryID: nextSearchResultsByEntryID,
            shiorisByEntryID: snapshot.shiorisByEntryID,
            version: snapshot.version + 1,
            update: update,
            references: references,
            totalRowCount: resolvedTotalRowCount
        )
    }

    func updateShioriRows(_ shioris: [TableSandboxShioriRowSource], tableName _: String) {
        var nextRowsByKey: [RowCacheKey: SubtitleTableRow] = [:]
        nextRowsByKey.reserveCapacity(shioris.count)
        var prefixUnchanged = shioris.count >= snapshot.rows.count
        let references = shioris.enumerated().map { index, item in
            TableSandboxRowReference(source: .shiori, sourceIndex: index, id: Int(item.shiori.id))
        }

        let rows = shioris.enumerated().map { index, item in
            let key = RowCacheKey(
                id: Int(item.shiori.id),
                subtitlePath: item.shiori.subtitlePath,
                dateAdded: item.dateAddedText,
                displayTitle: item.displayTitle,
                startTime: tableSandboxCueTimeText(milliseconds: item.shiori.startMilliseconds),
                endTime: tableSandboxCueTimeText(milliseconds: item.shiori.endMilliseconds),
                content: item.shiori.content,
                cueLines: item.shiori.cueLines,
                languages: item.languages,
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
                dateAdded: item.dateAddedText,
                displayTitle: item.displayTitle,
                startTime: key.startTime,
                endTime: key.endTime,
                cues: tableSandboxDisplayText(
                    content: item.shiori.content,
                    cueLines: item.shiori.cueLines
                ),
                tags: SubtitleLanguageWorkbenchTags.tags(for: item.languages)
            )
            nextRowsByKey[key] = row
            return row
        }
        let rowsBySourceIndex = Dictionary(uniqueKeysWithValues: rows.enumerated().map { index, row in
            (index, row)
        })
        let shiorisByEntryID = Dictionary(uniqueKeysWithValues: shioris.map { item in
            (Int(item.shiori.id), item.shiori)
        })

        apply(
            rows,
            rowsBySourceIndex: rowsBySourceIndex,
            searchResultsByEntryID: [:],
            shiorisByEntryID: shiorisByEntryID,
            references: references,
            totalRowCount: shioris.count,
            nextRowsByKey: nextRowsByKey,
            prefixUnchanged: prefixUnchanged
        )
    }

    func hydrateShioriRows(
        _ shioris: [TableSandboxShioriRowSource],
        startIndex: Int,
        totalRowCount: Int,
        tableName _: String
    ) {
        guard startIndex >= 0 else { return }

        if shioris.isEmpty {
            guard totalRowCount == 0 || snapshot.totalRowCount != totalRowCount || !snapshot.rowsBySourceIndex.isEmpty else {
                return
            }
            snapshot = TableSandboxRowsSnapshot(
                rows: [],
                rowsBySourceIndex: [:],
                searchResultsByEntryID: [:],
                shiorisByEntryID: [:],
                version: snapshot.version + 1,
                update: .reload,
                references: [],
                totalRowCount: max(0, totalRowCount)
            )
            return
        }

        var nextRowsBySourceIndex = snapshot.rowsBySourceIndex
        var nextShiorisByEntryID = snapshot.shiorisByEntryID
        var referencesBySourceIndex = Dictionary(uniqueKeysWithValues: snapshot.references.map { reference in
            (reference.sourceIndex, reference)
        })
        var lowerChangedIndex: Int?
        var upperChangedIndex: Int?

        for (offset, item) in shioris.enumerated() {
            let sourceIndex = startIndex + offset
            let row = shioriRow(for: item)
            if nextRowsBySourceIndex[sourceIndex] != row {
                lowerChangedIndex = min(lowerChangedIndex ?? sourceIndex, sourceIndex)
                upperChangedIndex = max(upperChangedIndex ?? sourceIndex + 1, sourceIndex + 1)
            }
            nextRowsBySourceIndex[sourceIndex] = row
            nextShiorisByEntryID[Int(item.shiori.id)] = item.shiori
            referencesBySourceIndex[sourceIndex] = TableSandboxRowReference(
                source: .shiori,
                sourceIndex: sourceIndex,
                id: Int(item.shiori.id)
            )
        }

        guard let lowerChangedIndex, let upperChangedIndex else { return }

        let hydratedRange = startIndex..<(startIndex + shioris.count)
        pruneHydratedShioriRowsIfNeeded(
            keepingPriorityRange: hydratedRange,
            rowsBySourceIndex: &nextRowsBySourceIndex,
            shiorisByEntryID: &nextShiorisByEntryID,
            referencesBySourceIndex: &referencesBySourceIndex
        )

        let references = referencesBySourceIndex.values.sorted { lhs, rhs in
            lhs.sourceIndex < rhs.sourceIndex
        }
        let resolvedTotalRowCount = max(totalRowCount, (references.last?.sourceIndex ?? -1) + 1)
        let update: TableSandboxRowsUpdate = .append(lowerChangedIndex..<upperChangedIndex)

        snapshot = TableSandboxRowsSnapshot(
            rows: contiguousPrefixRows(from: nextRowsBySourceIndex),
            rowsBySourceIndex: nextRowsBySourceIndex,
            searchResultsByEntryID: [:],
            shiorisByEntryID: nextShiorisByEntryID,
            version: snapshot.version + 1,
            update: update,
            references: references,
            totalRowCount: resolvedTotalRowCount
        )
    }

    private func apply(
        _ rows: [SubtitleTableRow],
        rowsBySourceIndex: [Int: SubtitleTableRow],
        searchResultsByEntryID: [Int: SubtitleSearchResult],
        shiorisByEntryID: [Int: Shiori],
        references: [TableSandboxRowReference],
        totalRowCount: Int,
        nextRowsByKey: [RowCacheKey: SubtitleTableRow],
        prefixUnchanged: Bool
    ) {
        let rowsUpdate = rowsUpdate(for: rows, prefixUnchanged: prefixUnchanged)
        let metadataChanged = references != snapshot.references
            || totalRowCount != snapshot.totalRowCount
        let update = rowsUpdate == .none && metadataChanged ? .reload : rowsUpdate
        let changed = update != .none || metadataChanged
        rowsByKey = nextRowsByKey

        guard changed else {
            return
        }

        snapshot = TableSandboxRowsSnapshot(
            rows: rows,
            rowsBySourceIndex: rowsBySourceIndex,
            searchResultsByEntryID: searchResultsByEntryID,
            shiorisByEntryID: shiorisByEntryID,
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
            dateAdded: "",
            displayTitle: displayTitle,
            startTime: tableSandboxCueTimeText(milliseconds: result.startMilliseconds),
            endTime: tableSandboxCueTimeText(milliseconds: result.endMilliseconds),
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
            startTime: key.startTime,
            endTime: key.endTime,
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

    private func shioriRow(for item: TableSandboxShioriRowSource) -> SubtitleTableRow {
        let key = RowCacheKey(
            id: Int(item.shiori.id),
            subtitlePath: item.shiori.subtitlePath,
            dateAdded: item.dateAddedText,
            displayTitle: item.displayTitle,
            startTime: tableSandboxCueTimeText(milliseconds: item.shiori.startMilliseconds),
            endTime: tableSandboxCueTimeText(milliseconds: item.shiori.endMilliseconds),
            content: item.shiori.content,
            cueLines: item.shiori.cueLines,
            languages: item.languages,
            speakers: []
        )

        if let cached = rowsByKey[key] {
            return cached
        }

        let row = SubtitleTableRow(
            id: key.id,
            dateAdded: item.dateAddedText,
            displayTitle: item.displayTitle,
            startTime: key.startTime,
            endTime: key.endTime,
            cues: tableSandboxDisplayText(
                content: item.shiori.content,
                cueLines: item.shiori.cueLines
            ),
            tags: SubtitleLanguageWorkbenchTags.tags(for: item.languages)
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

    private func pruneHydratedShioriRowsIfNeeded(
        keepingPriorityRange priorityRange: Range<Int>,
        rowsBySourceIndex: inout [Int: SubtitleTableRow],
        shiorisByEntryID: inout [Int: Shiori],
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
        shiorisByEntryID = shiorisByEntryID.filter { keptEntryIDs.contains($0.key) }
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
    let dateAdded: String
    let displayTitle: String
    let startTime: String
    let endTime: String
    let content: String
    let cueLines: [String]
    let languages: Set<SubtitleLanguageCode>
    let speakers: Set<String>
}

enum TableSandboxDisplayTextBudget {
    static let maximumLines = 6
    static let maximumCharactersPerLine = 500
}

func tableSandboxDisplayText(content: String, cueLines: [String]) -> String {
    subtitleDisplayLines(content: content, cueLines: cueLines)
        .prefix(TableSandboxDisplayTextBudget.maximumLines)
        .map(truncateTableSandboxDisplayLine)
        .joined(separator: "\n")
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
