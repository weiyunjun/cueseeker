import Combine
import Foundation
import CueSeekerCore

struct TableSandboxRowsSnapshot {
    var rows: [SubtitleTableRow] = []
    var version = 0
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

        let rows = results.map { result in
            let key = RowCacheKey(
                id: Int(result.entryID),
                subtitlePath: result.subtitlePath,
                content: result.content,
                cueLines: result.cueLines
            )

            if let cached = rowsByKey[key] {
                nextRowsByKey[key] = cached
                return cached
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
            start: start
        )
    }

    func updateShioriRows(_ shioris: [Shiori], tableName: String) {
        let start = TableRenderingPerformanceLogger.now()
        var nextRowsByKey: [RowCacheKey: SubtitleTableRow] = [:]
        nextRowsByKey.reserveCapacity(shioris.count)

        let rows = shioris.map { item in
            let key = RowCacheKey(
                id: Int(item.id),
                subtitlePath: item.subtitlePath,
                content: item.content,
                cueLines: item.cueLines
            )

            if let cached = rowsByKey[key] {
                nextRowsByKey[key] = cached
                return cached
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
            start: start
        )
    }

    private func apply(
        _ rows: [SubtitleTableRow],
        nextRowsByKey: [RowCacheKey: SubtitleTableRow],
        tableName: String,
        sourceCount: Int,
        start: UInt64
    ) {
        let changed = rows != snapshot.rows
        rowsByKey = nextRowsByKey
        TableRenderingPerformanceLogger.record(
            event: "rows_mapped",
            table: tableName,
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
            version: snapshot.version + 1
        )
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
