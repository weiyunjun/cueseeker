import AppKit
import Foundation

struct SubtitleTableClipboardColumn {
    let id: String
    let title: String
    let value: (SubtitleTableRow) -> String

    static func make(from column: WorkbenchTableColumn) -> SubtitleTableClipboardColumn? {
        switch column.id {
        case "dateAdded":
            return SubtitleTableClipboardColumn(id: column.id, title: column.title) { $0.dateAdded }
        case "display":
            return SubtitleTableClipboardColumn(id: column.id, title: column.title) { $0.displayTitle }
        case "startTime":
            return SubtitleTableClipboardColumn(id: column.id, title: column.title) { $0.startTime }
        case "endTime":
            return SubtitleTableClipboardColumn(id: column.id, title: column.title) { $0.endTime }
        case "cues":
            return SubtitleTableClipboardColumn(id: column.id, title: column.title) { $0.cues }
        case "speaker":
            return SubtitleTableClipboardColumn(id: column.id, title: column.title) { row in
                row.speakerTags.map(\.label).joined(separator: ", ")
            }
        case "language":
            return SubtitleTableClipboardColumn(id: column.id, title: column.title) { row in
                row.tags.map(\.label).joined(separator: ", ")
            }
        default:
            return nil
        }
    }
}

enum SubtitleTableClipboard {
    static func columns(from visibleColumns: [WorkbenchTableColumn]) -> [SubtitleTableClipboardColumn] {
        visibleColumns.compactMap(SubtitleTableClipboardColumn.make)
    }

    static func tsv(
        rows: [SubtitleTableRow],
        columns: [SubtitleTableClipboardColumn]
    ) -> String {
        guard !columns.isEmpty else {
            return ""
        }

        var outputRows: [String] = [
            columns.map { tsvCell($0.title) }.joined(separator: "\t"),
        ]
        outputRows.reserveCapacity(rows.count + 1)

        for row in rows {
            let columnLines = columns.map { normalizedLines($0.value(row)) }
            let expandedRowCount = max(1, columnLines.map(\.count).max() ?? 1)
            for lineIndex in 0..<expandedRowCount {
                let outputCells = columnLines.map { lines in
                    lineIndex < lines.count ? lines[lineIndex] : ""
                }
                outputRows.append(outputCells.joined(separator: "\t"))
            }
        }

        return outputRows.joined(separator: "\n")
    }

    @discardableResult
    static func copy(
        rows: [SubtitleTableRow],
        columns: [SubtitleTableClipboardColumn]
    ) -> Bool {
        let text = tsv(rows: rows, columns: columns)
        guard !text.isEmpty else {
            return false
        }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        return pasteboard.setString(text, forType: .string)
    }

    private static func normalizedLines(_ value: String) -> [String] {
        value
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .components(separatedBy: "\n")
            .map(tsvCell)
    }

    private static func tsvCell(_ value: String) -> String {
        value.replacingOccurrences(of: "\t", with: " ")
    }
}
