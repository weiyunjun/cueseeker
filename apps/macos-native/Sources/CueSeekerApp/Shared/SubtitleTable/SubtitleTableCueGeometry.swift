import AppKit

enum SubtitleTableCueStyle: Sendable {
    case primary
    case extra

    var fontSize: CGFloat {
        switch self {
        case .primary: WorkbenchControlMetrics.redesignFontSizeTable
        case .extra: WorkbenchControlMetrics.redesignFontSizeCaption
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

    @MainActor
    var font: NSFont {
        NSFont.systemFont(ofSize: fontSize, weight: fontWeight)
    }
}

enum SubtitleTableCueGeometry {
    static let styleRevision = 4
    static let minimumRowHeight = WorkbenchControlMetrics.redesignTableRowMinHeight
    static let rowPaddingY = WorkbenchControlMetrics.redesignTableRowPaddingY
    static let cueGroupGap = WorkbenchControlMetrics.redesignTableCueGroupGap
    static let cellLeadingPadding: CGFloat = 12
    static let cellTrailingPadding: CGFloat = 14
    static let primaryLineHeight = WorkbenchControlMetrics.redesignLineHeightTableCuePrimary
    static let extraLineHeight = WorkbenchControlMetrics.redesignLineHeightTableCueSecondary
    static let measurementOverscan = 4
    static let cueUnavailableIconSize: CGFloat = 18
    static let cueUnavailableIconGap: CGFloat = 8
    static let unavailableLeadingIndent: CGFloat = cueUnavailableIconSize + cueUnavailableIconGap

    static func cueBlockHeight(
        primaryLineCount: Int,
        extraCueLineCounts: [Int]
    ) -> CGFloat {
        let primaryHeight = CGFloat(max(1, primaryLineCount)) * primaryLineHeight
        let extraHeight = extraCueLineCounts.reduce(CGFloat.zero) { height, lineCount in
            height + CGFloat(max(1, lineCount)) * extraLineHeight
        }
        let itemSpacing = CGFloat(extraCueLineCounts.count) * cueGroupGap
        return primaryHeight + extraHeight + itemSpacing
    }

    static func rowHeight(
        primaryLineCount: Int,
        extraCueLineCounts: [Int],
        otherContentHeights: [CGFloat] = []
    ) -> CGFloat {
        let tallestContent = otherContentHeights.reduce(
            cueBlockHeight(
                primaryLineCount: primaryLineCount,
                extraCueLineCounts: extraCueLineCounts
            ),
            max
        )
        return max(
            minimumRowHeight,
            tallestContent + 2 * rowPaddingY
        )
    }

}

struct SubtitleTableRowMeasurement: Equatable {
    let height: CGFloat
    let primaryLineCount: Int
    let extraCueLineCounts: [Int]

    init(height: CGFloat, primaryLineCount: Int, extraCueLineCounts: [Int]) {
        self.height = height
        self.primaryLineCount = max(1, primaryLineCount)
        self.extraCueLineCounts = extraCueLineCounts.map { max(1, $0) }
    }

    var extraLineCount: Int {
        extraCueLineCounts.reduce(0, +)
    }

    var cueBlockHeight: CGFloat {
        SubtitleTableCueGeometry.cueBlockHeight(
            primaryLineCount: primaryLineCount,
            extraCueLineCounts: extraCueLineCounts
        )
    }

    var cueBlockTopOffset: CGFloat {
        max(0, (height - cueBlockHeight) / 2)
    }

    var extraCueOffsets: [CGFloat] {
        var nextOffset = cueBlockTopOffset
            + CGFloat(primaryLineCount) * SubtitleTableCueGeometry.primaryLineHeight
            + (extraCueLineCounts.isEmpty ? 0 : SubtitleTableCueGeometry.cueGroupGap)
        return extraCueLineCounts.map { lineCount in
            defer {
                nextOffset += CGFloat(lineCount) * SubtitleTableCueGeometry.extraLineHeight
                    + SubtitleTableCueGeometry.cueGroupGap
            }
            return nextOffset
        }
    }

    var primaryFirstLineOffset: CGFloat {
        cueBlockTopOffset
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
        showsCueGroup: Bool,
        otherContentHeights: [CGFloat] = []
    ) -> SubtitleTableRowMeasurement {
        let textWidth = row.cueState.isUnavailable
            ? max(1, effectiveCuesWidth - SubtitleTableCueGeometry.unavailableLeadingIndent)
            : effectiveCuesWidth
        let primaryLineCount = visualLineCount(
            text: row.primaryCueText,
            width: textWidth,
            style: .primary
        )
        let extraCueLineCounts = showsCueGroup
            ? row.additionalCueTexts.map { text in
                visualLineCount(text: text, width: textWidth, style: .extra)
            }
            : []
        return SubtitleTableRowMeasurement(
            height: SubtitleTableCueGeometry.rowHeight(
                primaryLineCount: primaryLineCount,
                extraCueLineCounts: extraCueLineCounts,
                otherContentHeights: otherContentHeights
            ),
            primaryLineCount: primaryLineCount,
            extraCueLineCounts: extraCueLineCounts
        )
    }

    static func attributedString(
        _ text: String,
        style: SubtitleTableCueStyle,
        foregroundColor: NSColor
    ) -> NSAttributedString {
        NSAttributedString(string: text, attributes: [
            .font: style.font,
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
        SubtitleTableText.fixedLineParagraphStyle(lineHeight: style.lineHeight)
    }
}
