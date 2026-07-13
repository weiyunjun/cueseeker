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
        case "speaker":
            return SubtitleTableClipboardColumn(id: column.id, title: column.title) { row in
                row.speakerTags.map(\.label).joined(separator: ", ")
            }
        case "language":
            return SubtitleTableClipboardColumn(id: column.id, title: column.title) { row in
                row.tags.map(\.label).joined(separator: ", ")
            }
        case "tags":
            return SubtitleTableClipboardColumn(id: column.id, title: column.title) { row in
                row.shioriTags.map(\.label).joined(separator: ", ")
            }
        default:
            return nil
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
