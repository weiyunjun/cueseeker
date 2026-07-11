import AppKit

enum SubtitleTableCueStyle: Sendable {
    case primary
    case extra

    var fontSize: CGFloat {
        switch self {
        case .primary: 14
        case .extra: 12
        }
    }

    var fontWeight: NSFont.Weight {
        switch self {
        case .primary: .medium
        case .extra: .regular
        }
    }

    var lineHeight: CGFloat {
        switch self {
        case .primary: SubtitleTableCueGeometry.primaryLineHeight
        case .extra: SubtitleTableCueGeometry.extraLineHeight
        }
    }
}

enum SubtitleTableCueGeometry {
    static let styleRevision = 1
    static let minimumRowHeight: CGFloat = 40
    static let rowPaddingY: CGFloat = 8
    static let cellLeadingPadding: CGFloat = 12
    static let cellTrailingPadding: CGFloat = 14
    static let primaryLineHeight: CGFloat = 24
    static let extraLineHeight: CGFloat = 20
    static let measurementOverscan = 4

    static func rowHeight(primaryLineCount: Int, extraLineCount: Int) -> CGFloat {
        max(
            minimumRowHeight,
            2 * rowPaddingY
                + CGFloat(max(1, primaryLineCount)) * primaryLineHeight
                + CGFloat(max(0, extraLineCount)) * extraLineHeight
        )
    }

    static func primaryCueTop(rowMinY: CGFloat, extraLineCount: Int) -> CGFloat {
        rowMinY + rowPaddingY + CGFloat(max(0, extraLineCount)) * extraLineHeight
    }
}

struct SubtitleTableRowMeasurement: Equatable {
    let height: CGFloat
    let primaryLineCount: Int
    let extraLineCount: Int

    var primaryFirstLineOffset: CGFloat {
        SubtitleTableCueGeometry.rowPaddingY
            + CGFloat(extraLineCount) * SubtitleTableCueGeometry.extraLineHeight
    }
}

@MainActor
final class SubtitleTableCueTextMeasurer {
    private let textStorage = NSTextStorage()
    private let layoutManager = NSLayoutManager()
    private let textContainer = NSTextContainer()

    init() {
        textContainer.lineFragmentPadding = 0
        textContainer.maximumNumberOfLines = 0
        textContainer.lineBreakMode = .byWordWrapping
        layoutManager.usesFontLeading = false
        layoutManager.addTextContainer(textContainer)
        textStorage.addLayoutManager(layoutManager)
    }

    func visualLineCount(text: String, width: CGFloat, style: SubtitleTableCueStyle) -> Int {
        sourceLines(in: text).reduce(into: 0) { count, sourceLine in
            count += wrappedLineCount(sourceLine, width: width, style: style)
        }
    }

    func rowMeasurement(
        row: SubtitleTableRow,
        effectiveCuesWidth: CGFloat,
        showsCueGroup: Bool
    ) -> SubtitleTableRowMeasurement {
        let primaryLineCount = visualLineCount(
            text: row.primaryCueText,
            width: effectiveCuesWidth,
            style: .primary
        )
        let extraLineCount = showsCueGroup
            ? row.additionalCueTexts.reduce(into: 0) { count, text in
                count += visualLineCount(text: text, width: effectiveCuesWidth, style: .extra)
            }
            : 0
        return SubtitleTableRowMeasurement(
            height: SubtitleTableCueGeometry.rowHeight(
                primaryLineCount: primaryLineCount,
                extraLineCount: extraLineCount
            ),
            primaryLineCount: primaryLineCount,
            extraLineCount: extraLineCount
        )
    }

    static func attributedString(
        _ text: String,
        style: SubtitleTableCueStyle,
        foregroundColor: NSColor
    ) -> NSAttributedString {
        NSAttributedString(string: text, attributes: [
            .font: NSFont.systemFont(ofSize: style.fontSize, weight: style.fontWeight),
            .paragraphStyle: paragraphStyle(for: style),
            .foregroundColor: foregroundColor,
        ])
    }

    private func wrappedLineCount(
        _ sourceLine: String,
        width: CGFloat,
        style: SubtitleTableCueStyle
    ) -> Int {
        guard !sourceLine.isEmpty else { return 1 }
        textStorage.setAttributedString(Self.attributedString(
            sourceLine,
            style: style,
            foregroundColor: .labelColor
        ))
        textContainer.size = CGSize(
            width: max(1, width),
            height: .greatestFiniteMagnitude
        )
        layoutManager.ensureLayout(for: textContainer)

        let glyphRange = layoutManager.glyphRange(for: textContainer)
        guard glyphRange.length > 0 else { return 1 }
        var count = 0
        layoutManager.enumerateLineFragments(forGlyphRange: glyphRange) { _, _, _, _, _ in
            count += 1
        }
        return max(1, count)
    }

    private func sourceLines(in text: String) -> [String] {
        let normalized = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        var lines = [String]()
        var current = ""
        for character in normalized {
            if character.isNewline {
                lines.append(current)
                current.removeAll(keepingCapacity: true)
            } else {
                current.append(character)
            }
        }
        lines.append(current)
        return lines
    }

    private static func paragraphStyle(for style: SubtitleTableCueStyle) -> NSParagraphStyle {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byWordWrapping
        paragraph.minimumLineHeight = style.lineHeight
        paragraph.maximumLineHeight = style.lineHeight
        paragraph.lineSpacing = 0
        paragraph.paragraphSpacing = 0
        return paragraph
    }
}
