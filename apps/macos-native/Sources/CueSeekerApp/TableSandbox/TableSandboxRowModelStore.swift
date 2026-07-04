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
        tableName _: String
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
            prefixUnchanged: prefixUnchanged
        )
    }

    func hydrateSearchRows(
        _ results: [SubtitleSearchResult],
        startIndex: Int,
        totalRowCount: Int,
        tableName _: String
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

        snapshot = TableSandboxRowsSnapshot(
            rows: nextRows,
            searchResultsByEntryID: nextSearchResultsByEntryID,
            shiorisByEntryID: snapshot.shiorisByEntryID,
            version: snapshot.version + 1,
            update: update,
            totalRowCount: nextRows.count
        )
    }

    @discardableResult
    func prependSearchRows(_ results: [SubtitleSearchResult], tableName _: String) -> Int {
        let existingEntryIDs = Set(snapshot.rows.map(\.id))
        let prependedResults = results.filter { !existingEntryIDs.contains(Int($0.entryID)) }
        guard !prependedResults.isEmpty else { return 0 }

        var nextSearchResultsByEntryID = snapshot.searchResultsByEntryID
        prependedResults.forEach { result in
            nextSearchResultsByEntryID[Int(result.entryID)] = result
        }

        snapshot = TableSandboxRowsSnapshot(
            rows: prependedResults.map { searchRow(for: $0) } + snapshot.rows,
            searchResultsByEntryID: nextSearchResultsByEntryID,
            shiorisByEntryID: snapshot.shiorisByEntryID,
            version: snapshot.version + 1,
            update: .reload,
            totalRowCount: snapshot.rows.count + prependedResults.count
        )
        return prependedResults.count
    }

    @discardableResult
    func appendSearchRows(_ results: [SubtitleSearchResult], tableName _: String) -> Int {
        let existingEntryIDs = Set(snapshot.rows.map(\.id))
        let appendedResults = results.filter { !existingEntryIDs.contains(Int($0.entryID)) }
        guard !appendedResults.isEmpty else { return 0 }

        var nextSearchResultsByEntryID = snapshot.searchResultsByEntryID
        appendedResults.forEach { result in
            nextSearchResultsByEntryID[Int(result.entryID)] = result
        }

        let oldRowCount = snapshot.rows.count
        let nextRows = snapshot.rows + appendedResults.map { searchRow(for: $0) }
        snapshot = TableSandboxRowsSnapshot(
            rows: nextRows,
            searchResultsByEntryID: nextSearchResultsByEntryID,
            shiorisByEntryID: snapshot.shiorisByEntryID,
            version: snapshot.version + 1,
            update: .append(oldRowCount..<nextRows.count),
            totalRowCount: nextRows.count
        )
        return appendedResults.count
    }

    func updateShioriRows(_ shioris: [TableSandboxShioriRowSource], tableName _: String) {
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
            prefixUnchanged: prefixUnchanged
        )
    }

    func hydrateShioriRows(
        _ shioris: [TableSandboxShioriRowSource],
        startIndex: Int,
        totalRowCount: Int,
        tableName _: String
    ) {
        _ = totalRowCount
        guard startIndex >= 0 else { return }
        guard startIndex <= snapshot.rows.count else { return }

        if shioris.isEmpty {
            guard totalRowCount == 0 else { return }
            updateShioriRows([], tableName: "shiori")
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

        snapshot = TableSandboxRowsSnapshot(
            rows: nextRows,
            searchResultsByEntryID: [:],
            shiorisByEntryID: nextShiorisByEntryID,
            version: snapshot.version + 1,
            update: update,
            totalRowCount: nextRows.count
        )
    }

    private func apply(
        _ rows: [SubtitleTableRow],
        searchResultsByEntryID: [Int: SubtitleSearchResult],
        shiorisByEntryID: [Int: Shiori],
        totalRowCount: Int,
        prefixUnchanged: Bool
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

        snapshot = TableSandboxRowsSnapshot(
            rows: rows,
            searchResultsByEntryID: searchResultsByEntryID,
            shiorisByEntryID: shiorisByEntryID,
            version: snapshot.version + 1,
            update: update,
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
        return SubtitleTableRow(
            id: Int(result.entryID),
            subtitlePath: result.subtitlePath,
            displayTitle: displayTitle,
            startTime: tableSandboxCueTimeText(milliseconds: result.startMilliseconds),
            endTime: tableSandboxCueTimeText(milliseconds: result.endMilliseconds),
            timeRange: result.timeRange,
            cues: tableSandboxDisplayText(
                content: result.content,
                cueLines: result.cueLines
            ),
            tags: SubtitleLanguageWorkbenchTags.tags(for: result.languages),
            speakerTags: tableSandboxSpeakerTags(for: result.speakers)
        )
    }

    private func shioriRow(for item: TableSandboxShioriRowSource) -> SubtitleTableRow {
        SubtitleTableRow(
            id: Int(item.shiori.id),
            subtitlePath: item.shiori.subtitlePath,
            dateAdded: item.dateAddedText,
            displayTitle: item.displayTitle,
            startTime: tableSandboxCueTimeText(milliseconds: item.shiori.startMilliseconds),
            endTime: tableSandboxCueTimeText(milliseconds: item.shiori.endMilliseconds),
            timeRange: item.shiori.timeRange,
            cues: tableSandboxDisplayText(
                content: item.shiori.content,
                cueLines: item.shiori.cueLines
            ),
            tags: SubtitleLanguageWorkbenchTags.tags(for: item.languages)
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
        subtitlePath: result.subtitlePath,
        displayTitle: displayTitle,
        startTime: tableSandboxCueTimeText(milliseconds: result.startMilliseconds),
        endTime: tableSandboxCueTimeText(milliseconds: result.endMilliseconds),
        timeRange: result.timeRange,
        cues: tableSandboxDisplayText(
            content: result.content,
            cueLines: result.cueLines
        ),
        tags: SubtitleLanguageWorkbenchTags.tags(for: result.languages),
        speakerTags: tableSandboxSpeakerTags(for: result.speakers)
    )
}

func tableSandboxShioriRow(for item: TableSandboxShioriRowSource) -> SubtitleTableRow {
    SubtitleTableRow(
        id: Int(item.shiori.id),
        subtitlePath: item.shiori.subtitlePath,
        dateAdded: item.dateAddedText,
        displayTitle: item.displayTitle,
        startTime: tableSandboxCueTimeText(milliseconds: item.shiori.startMilliseconds),
        endTime: tableSandboxCueTimeText(milliseconds: item.shiori.endMilliseconds),
        timeRange: item.shiori.timeRange,
        cues: tableSandboxDisplayText(
            content: item.shiori.content,
            cueLines: item.shiori.cueLines
        ),
        tags: SubtitleLanguageWorkbenchTags.tags(for: item.languages)
    )
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
