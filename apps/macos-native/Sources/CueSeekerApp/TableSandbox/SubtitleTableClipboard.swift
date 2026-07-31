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
        case "time":
            return SubtitleTableClipboardColumn(id: column.id, title: column.title) { $0.timeRange }
        case "cues":
            return SubtitleTableClipboardColumn(id: column.id, title: column.title) { $0.primaryCueText }
        case "language":
            return SubtitleTableClipboardColumn(id: column.id, title: column.title) { row in
                row.tags.map(\.label).joined(separator: ", ")
            }
        default:
            return nil
        }
    }
}

struct SubtitleTableTextCopyColumn: Equatable, Sendable {
    let id: String
    let title: String

    func text(for row: SubtitleTableRow, showsCueGroup: Bool) -> String {
        switch id {
        case "dateAdded":
            return row.dateAdded
        case "display":
            return row.displayTitle
        case "time":
            return row.timeRange
        case "cues":
            let cueTexts = [row.primaryCueText] + (showsCueGroup ? row.additionalCueTexts : [])
            return cueTexts.joined(separator: "\n")
        case "language":
            return row.tags.map(\.label).joined(separator: ", ")
        default:
            return ""
        }
    }
}

struct SubtitleTableTextCopyRequest: Equatable, Sendable {
    let selection: SubtitleTableTextSelectionState
    let columns: [SubtitleTableTextCopyColumn]
    let rowCount: Int
    let showsCueGroup: Bool

    var includesHeader: Bool {
        if selection.selectsAllResults {
            return true
        }
        guard let range = selection.orderedRange else { return false }
        return range.start.row == .header
    }

    var bodyRowRange: Range<Int> {
        let safeRowCount = max(0, rowCount)
        if selection.selectsAllResults {
            return 0..<safeRowCount
        }
        guard let range = selection.orderedRange,
              case .body(let endRow) = range.end.row
        else {
            return 0..<0
        }
        let startRow: Int
        switch range.start.row {
        case .header:
            startRow = 0
        case .body(let row):
            startRow = row
        }
        let lowerBound = min(max(0, startRow), safeRowCount)
        let endExclusive = endRow >= safeRowCount
            ? safeRowCount
            : max(0, endRow + 1)
        let upperBound = min(max(lowerBound, endExclusive), safeRowCount)
        return lowerBound..<upperBound
    }
}

struct SubtitleTableTextCopyBuilder {
    private let request: SubtitleTableTextCopyRequest
    private var representationBuilder = SubtitleTableClipboard.RepresentationBuilder()

    init(request: SubtitleTableTextCopyRequest) {
        self.request = request
        if request.includesHeader, !request.columns.isEmpty {
            representationBuilder.append(
                cells: request.columns.enumerated().map { columnIndex, column in
                    selectedText(
                        column.title,
                        selection: request.selection.cellSelection(
                            row: .header,
                            columnIndex: columnIndex,
                            utf16Length: (column.title as NSString).length
                        )
                    )
                },
                isHeader: true
            )
        }
    }

    mutating func append(rows: [SubtitleTableRow], startingAt startingRow: Int) {
        guard !request.columns.isEmpty else { return }
        for (offset, row) in rows.enumerated() {
            let rowIndex = startingRow + offset
            guard request.bodyRowRange.contains(rowIndex) else { continue }
            representationBuilder.append(cells: request.columns.enumerated().map { columnIndex, column in
                let text = column.text(for: row, showsCueGroup: request.showsCueGroup)
                return selectedText(
                    text,
                    selection: request.selection.cellSelection(
                        row: .body(rowIndex),
                        columnIndex: columnIndex,
                        utf16Length: (text as NSString).length
                    )
                )
            })
        }
    }

    var representations: SubtitleTableClipboard.Representations {
        representationBuilder.representations
    }

    private func selectedText(
        _ text: String,
        selection: SubtitleTableTextCellSelection
    ) -> String {
        switch selection {
        case .none:
            return ""
        case .full:
            return text
        case .range(let range):
            let source = text as NSString
            let safeRange = NSIntersectionRange(
                range,
                NSRange(location: 0, length: source.length)
            )
            guard safeRange.length > 0 else { return "" }
            return source.substring(
                with: source.rangeOfComposedCharacterSequences(for: safeRange)
            )
        }
    }
}

enum SubtitleTableClipboard {
    struct Representations: Equatable {
        let plainText: String
        let tabularText: String
        let html: String

        var isEmpty: Bool {
            tabularText.isEmpty
        }
    }

    struct RepresentationBuilder {
        private var tabularText = ""
        private var htmlRows = ""
        private var hasRows = false

        mutating func append(cells: [String], isHeader: Bool = false) {
            guard !cells.isEmpty else { return }
            let normalizedCells = cells.map(SubtitleTableClipboard.normalizedCell)
            if hasRows {
                tabularText.append("\n")
            }
            tabularText.append(
                normalizedCells.map(SubtitleTableClipboard.tsvCell).joined(separator: "\t")
            )

            let tag = isHeader ? "th" : "td"
            let htmlCells = normalizedCells.map { value in
                "<\(tag) style=\"mso-number-format:'\\@';white-space:pre-wrap\">\(SubtitleTableClipboard.htmlCell(value))</\(tag)>"
            }
            htmlRows.append("<tr>\(htmlCells.joined())</tr>")
            hasRows = true
        }

        var representations: Representations {
            guard !tabularText.isEmpty else {
                return Representations(plainText: "", tabularText: "", html: "")
            }
            let html = "<html><head><meta charset=\"utf-8\"></head><body><table>\(htmlRows)</table></body></html>"
            return Representations(
                plainText: tabularText,
                tabularText: tabularText,
                html: html
            )
        }
    }

    struct TSVBuilder {
        private let columns: [SubtitleTableClipboardColumn]
        private var representationBuilder = RepresentationBuilder()

        init(columns: [SubtitleTableClipboardColumn]) {
            self.columns = columns
            representationBuilder.append(cells: columns.map(\.title), isHeader: true)
        }

        mutating func append(rows: [SubtitleTableRow]) {
            for row in rows {
                append(row: row)
            }
        }

        private mutating func append(row: SubtitleTableRow) {
            guard !columns.isEmpty else {
                return
            }
            representationBuilder.append(cells: columns.map { $0.value(row) })
        }

        var representations: Representations {
            representationBuilder.representations
        }

        var text: String {
            representations.tabularText
        }
    }

    static func columns(from visibleColumns: [WorkbenchTableColumn]) -> [SubtitleTableClipboardColumn] {
        visibleColumns.compactMap(SubtitleTableClipboardColumn.make)
    }

    static func tsv(
        rows: [SubtitleTableRow],
        columns: [SubtitleTableClipboardColumn]
    ) -> String {
        var builder = TSVBuilder(columns: columns)
        builder.append(rows: rows)
        return builder.text
    }

    static func representations(
        rows: [SubtitleTableRow],
        columns: [SubtitleTableClipboardColumn]
    ) -> Representations {
        var builder = TSVBuilder(columns: columns)
        builder.append(rows: rows)
        return builder.representations
    }

    @discardableResult
    static func copy(
        rows: [SubtitleTableRow],
        columns: [SubtitleTableClipboardColumn],
        to pasteboard: NSPasteboard = .general
    ) -> Bool {
        copy(representations: representations(rows: rows, columns: columns), to: pasteboard)
    }

    @discardableResult
    static func copy(
        representations: Representations,
        to pasteboard: NSPasteboard = .general
    ) -> Bool {
        guard !representations.isEmpty else {
            return false
        }

        let item = NSPasteboardItem()
        guard item.setString(representations.html, forType: .html),
              item.setString(representations.tabularText, forType: .tabularText),
              item.setString(representations.plainText, forType: .string)
        else {
            return false
        }
        pasteboard.clearContents()
        return pasteboard.writeObjects([item])
    }

    @discardableResult
    static func copy(text: String) -> Bool {
        guard !text.isEmpty else {
            return false
        }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        return pasteboard.setString(text, forType: .string)
    }

    @discardableResult
    static func copyDeepLinks(
        rows: [SubtitleTableRow],
        to pasteboard: NSPasteboard = .general
    ) -> Bool {
        let cues = rows.compactMap { row -> (cueText: String, cueID: Int64)? in
            guard let cueID = row.primaryCueID else { return nil }
            return (row.primaryCueText, cueID)
        }
        guard cues.count == rows.count else {
            return false
        }
        return CueClipboard.copyDeepLinks(cues, to: pasteboard)
    }

    private static func normalizedCell(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
    }

    private static func tsvCell(_ value: String) -> String {
        guard value.contains("\t") || value.contains("\n") || value.contains("\"") else {
            return value
        }
        return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
    }

    private static func htmlCell(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
            .replacingOccurrences(of: "\t", with: "&#9;")
            .replacingOccurrences(of: "\n", with: "<br>")
    }
}
