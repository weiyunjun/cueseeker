import Combine
import Foundation
import CueSeekerCore

struct TableSandboxRowsSnapshot {
    var rows: [SubtitleTableRow] = []
    var version = 0
    var update = TableSandboxRowsUpdate.none
}

@MainActor
final class TableSandboxRowModelStore: ObservableObject {
    @Published private(set) var snapshot = TableSandboxRowsSnapshot()

    private var rowsByKey: [RowCacheKey: SubtitleTableRow] = [:]
    private var displayTitlesBySubtitlePath: [String: String] = [:]
    private let displayTitleResolver: (String) -> String

    init(displayTitleResolver: @escaping (String) -> String = {
        SubtitleDisplayTitleResolver.displayTitle(forSubtitlePath: $0)
    }) {
        self.displayTitleResolver = displayTitleResolver
    }

    func updateSearchRows(_ results: [SubtitleSearchResult], tableName: String) {
        let start = TableRenderingPerformanceLogger.now()
        var nextRowsByKey: [RowCacheKey: SubtitleTableRow] = [:]
        nextRowsByKey.reserveCapacity(results.count)
        var prefixUnchanged = results.count >= snapshot.rows.count

        let rows = results.enumerated().map { index, result in
            let key = RowCacheKey(
                id: Int(result.entryID),
                subtitlePath: result.subtitlePath,
                content: result.content,
                cueLines: result.cueLines
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
                name: displayTitle(forSubtitlePath: result.subtitlePath),
                cues: subtitleDisplayLines(
                    content: result.content,
                    cueLines: result.cueLines
                ).joined(separator: "\n")
            )
            nextRowsByKey[key] = row
            return row
        }

        apply(
            rows,
            nextRowsByKey: nextRowsByKey,
            tableName: tableName,
            sourceCount: results.count,
            prefixUnchanged: prefixUnchanged,
            start: start
        )
    }

    func updateShioriRows(_ shioris: [Shiori], tableName: String) {
        let start = TableRenderingPerformanceLogger.now()
        var nextRowsByKey: [RowCacheKey: SubtitleTableRow] = [:]
        nextRowsByKey.reserveCapacity(shioris.count)
        var prefixUnchanged = shioris.count >= snapshot.rows.count

        let rows = shioris.enumerated().map { index, item in
            let key = RowCacheKey(
                id: Int(item.id),
                subtitlePath: item.subtitlePath,
                content: item.content,
                cueLines: item.cueLines
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
                name: displayTitle(forSubtitlePath: item.subtitlePath),
                cues: subtitleDisplayLines(
                    content: item.content,
                    cueLines: item.cueLines
                ).joined(separator: "\n")
            )
            nextRowsByKey[key] = row
            return row
        }

        apply(
            rows,
            nextRowsByKey: nextRowsByKey,
            tableName: tableName,
            sourceCount: shioris.count,
            prefixUnchanged: prefixUnchanged,
            start: start
        )
    }

    private func apply(
        _ rows: [SubtitleTableRow],
        nextRowsByKey: [RowCacheKey: SubtitleTableRow],
        tableName: String,
        sourceCount: Int,
        prefixUnchanged: Bool,
        start: UInt64
    ) {
        let update = rowsUpdate(for: rows, prefixUnchanged: prefixUnchanged)
        let changed = update != .none
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
            version: snapshot.version + 1,
            update: update
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
    let content: String
    let cueLines: [String]
}
